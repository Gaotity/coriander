import Foundation
import Rime

/// The Swift adapter over the librime C API — the project's single deep
/// module. One live Engine per process; after `shutdown()` another may
/// start, because librime 1.17 tolerates the finalize → re-initialize cycle
/// (verified by CorianderLifecycleTests). The interface covers the input
/// path — Session lifecycle, key events, reading Composition/Candidates,
/// paging the Candidate list (ticket 13), Commit — plus in-Session Schema
/// switching (ticket 12) and Deploy, which is Container App only
/// (ADR-0001). Learning into the User Dictionary happens inside librime on
/// Commit; on a read-only Rime Directory (keyboard without Full Access,
/// ADR-0003) librime degrades on its own — learning silently off, typing
/// intact, no crash (probed) — so the Engine exposes no learning switch.
/// No librime type crosses this interface.
final class Engine {
    /// A key event delivered to the Session. `code` follows X11 keysym
    /// values (printable ASCII maps 1:1); `modifiers` is librime's mask.
    struct Key: Equatable {
        let code: Int32
        let modifiers: Int32

        init(code: Int32, modifiers: Int32 = 0) {
            self.code = code
            self.modifiers = modifiers
        }

        init?(character: Character) {
            guard let ascii = character.asciiValue else { return nil }
            self.init(code: Int32(ascii))
        }

        /// Common named keys (X11 keysym values).
        static let space = Key(code: 0x20)
        static let backspace = Key(code: 0xff08)
        static let `return` = Key(code: 0xff0d)
    }

    /// One selectable conversion result (text and comment).
    struct Candidate: Equatable {
        let text: String
        let comment: String?
    }

    /// One deployed Schema the user may switch to: its id and display name.
    struct Schema: Equatable {
        let id: String
        let name: String
    }

    /// Snapshot of the in-progress input: the Composition plus the current
    /// page of Candidates.
    struct InputState: Equatable {
        var composition = ""
        var candidates: [Candidate] = []
        /// The page the Candidates are on (0-based).
        var pageNo = 0
        /// Whether a further page of Candidates exists.
        var hasNextPage = false
    }

    enum StartError: Error {
        /// `rime_get_api()` returned nil.
        case apiUnavailable
        /// A second live Engine in one process.
        case alreadyStarted
    }

    /// A Deploy failure (ticket 09).
    enum DeployError: Error {
        /// The Engine was already shut down.
        case notRunning
        /// librime refused to start the maintenance thread.
        case failedToStart
        /// These schema sources produced no fresh compiled artifacts.
        case schemasFailed([String])
    }

    /// A User Dictionary management failure (ticket 15). Container App only.
    enum ManagementError: Error {
        /// The Engine was already shut down.
        case notRunning
        /// A Session is open: it holds the User Dictionary's LevelDB lock
        /// (probed), so management ops run before `startSession()`.
        case sessionOpen
        /// librime could not open the named User Dictionary for export —
        /// it is missing, or another Engine (e.g. the keyboard's, mid-Session)
        /// holds its lock. Nothing was written.
        case exportFailed(String)
        /// librime could not open the named User Dictionary for import —
        /// same contention story as `exportFailed`.
        case importFailed(String)
    }

    /// The levers API (user-dict management), reached through librime's
    /// module registry: the levers entry points have internal linkage in
    /// this static build, so `find_module("levers").get_api()` is the only
    /// way in (probed).
    private var levers: UnsafeMutablePointer<RimeLeversApi>? {
        guard let module = api.find_module("levers"),
              let custom = module.pointee.get_api() else { return nil }
        return UnsafeMutableRawPointer(custom).assumingMemoryBound(to: RimeLeversApi.self)
    }

    private static let startLock = NSLock()
    private static var didStart = false

    private let api: RimeApi
    private let directory: RimeDirectory
    private var sessionID: RimeSessionId = 0
    private var running = true

    /// Sets up and initializes librime against `directory`, starting against
    /// existing Deployed artifacts. Use `deploy()` to (re)build them.
    init(directory: RimeDirectory) throws {
        Self.startLock.lock()
        guard !Self.didStart else {
            Self.startLock.unlock()
            throw StartError.alreadyStarted
        }
        Self.didStart = true
        Self.startLock.unlock()

        guard let api = rime_get_api()?.pointee else {
            throw StartError.apiUnavailable
        }
        self.api = api
        self.directory = directory

        // strdup keeps the C strings alive until initialize returns; librime
        // copies them during setup.
        let shared = strdup(directory.shared.path)!
        let user = strdup(directory.user.path)!
        let codeName = strdup("coriander")!
        let distName = strdup("Coriander")!
        let distVersion = strdup("0.1")!
        let appName = strdup(Bundle.main.bundleIdentifier ?? "coriander")!
        defer {
            free(shared); free(user)
            free(codeName); free(distName); free(distVersion); free(appName)
        }

        var traits = RimeTraits()
        // librime ABI convention: data_size = sizeof(RimeTraits) - sizeof(int)
        traits.data_size = Int32(MemoryLayout<RimeTraits>.size - MemoryLayout<Int32>.size)
        traits.shared_data_dir = UnsafePointer(shared)
        traits.user_data_dir = UnsafePointer(user)
        traits.distribution_code_name = UnsafePointer(codeName)
        traits.distribution_name = UnsafePointer(distName)
        traits.distribution_version = UnsafePointer(distVersion)
        traits.app_name = UnsafePointer(appName)

        api.setup(&traits)
        api.initialize(&traits)
    }

    /// Runs one full Deploy synchronously and verifies that every schema
    /// source was successfully rebuilt. Container App only — the Keyboard
    /// Extension never Deploys (ADR-0001). The Deploy invalidates any
    /// in-progress Session; the next Session loads the new artifacts.
    func deploy() throws {
        guard running else { throw DeployError.notRunning }
        // Deploy is async: start_maintenance only kicks it off, the
        // maintenance thread does the work — and join reports no status,
        // so a failure is detected afterwards by its stale artifacts.
        guard api.start_maintenance(1) != 0 else { throw DeployError.failedToStart }
        api.join_maintenance_thread()
        let failed = failedSchemas()
        guard failed.isEmpty else { throw DeployError.schemasFailed(failed) }
    }

    /// Schema sources in `shared` that the Deploy did not successfully
    /// rebuild: no compiled counterpart under `user/build`, or a counterpart
    /// older than the source. librime preserves the previous artifact when
    /// compilation fails (natural last-good), so a stale artifact is the
    /// failure signal. Only schema files are covered — broken custom
    /// patches are silently ignored by librime (probed) and cannot be
    /// detected here, and dictionary-table failures are not detected. (The baseline keeps shared == schema_list; ticket 17
    /// owns refining this once schemas can be disabled.)
    private func failedSchemas() -> [String] {
        let fm = FileManager.default
        let sources = (try? fm.contentsOfDirectory(atPath: directory.shared.path)) ?? []
        let buildDir = directory.user.appendingPathComponent("build", isDirectory: true)
        return sources
            .filter { $0.hasSuffix(".schema.yaml") }
            .filter { name in
                guard let artifactDate = mtime(buildDir.appendingPathComponent(name)) else { return true }
                guard let sourceDate = mtime(directory.shared.appendingPathComponent(name)) else { return false }
                return sourceDate > artifactDate
            }
            .sorted()
    }

    private func mtime(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// The Schemas the deployed configuration enables, in schema_list order.
    /// librime resolves the list from the deployed default config (probed):
    /// a narrowed schema_list + Deploy narrows it — no Session needed.
    var schemas: [Schema] {
        guard running else { return [] }
        var list = RimeSchemaList()
        guard api.get_schema_list(&list) != 0 else { return [] }
        defer { api.free_schema_list(&list) }
        guard let items = list.list else { return [] }
        return (0..<Int(list.size)).map { index in
            let item = items[index]
            return Schema(id: item.schema_id.map { String(cString: $0) } ?? "",
                          name: item.name.map { String(cString: $0) } ?? "")
        }
    }

    /// Opens the input Session. False means librime rejected the Session (or
    /// one is already open — a process holds exactly one).
    @discardableResult
    func startSession() -> Bool {
        guard running, sessionID == 0 else { return false }
        let id = api.create_session()
        guard id != 0 else { return false }
        sessionID = id
        return true
    }

    /// Closes the input Session.
    func endSession() {
        guard sessionID != 0 else { return }
        api.destroy_session(sessionID)
        sessionID = 0
    }

    /// The id of the Schema the Session is currently running; nil without a
    /// Session.
    var currentSchemaID: String? {
        guard sessionID != 0 else { return nil }
        // Schema ids are file stems — 256 bytes is generous.
        var buffer = [CChar](repeating: 0, count: 256)
        guard api.get_current_schema(sessionID, &buffer, buffer.count) != 0 else { return nil }
        return String(cString: buffer)
    }

    /// Switches the Session to another enabled Schema, taking effect within
    /// the current Session — no Session restart. librime drops the
    /// in-progress Composition on switch and remembers the choice for the
    /// next Session (both probed). False when `id` is not enabled:
    /// librime's select_schema accepts ANY id unchecked (probed), so the
    /// "only enabled Schemas" invariant is enforced here.
    @discardableResult
    func selectSchema(_ id: String) -> Bool {
        guard sessionID != 0, schemas.contains(where: { $0.id == id }) else { return false }
        return api.select_schema(sessionID, id) != 0
    }

    /// Feeds one key. True means the Session consumed it.
    @discardableResult
    func processKey(_ key: Key) -> Bool {
        guard sessionID != 0 else { return false }
        return api.process_key(sessionID, key.code, key.modifiers) != 0
    }

    /// The current Composition and current page of Candidates.
    var input: InputState {
        guard sessionID != 0 else { return InputState() }
        var context = RimeContext()
        context.data_size = Int32(MemoryLayout<RimeContext>.size - MemoryLayout<Int32>.size)
        guard api.get_context(sessionID, &context) != 0 else { return InputState() }
        defer { _ = api.free_context(&context) }

        var state = InputState()
        if let preedit = context.composition.preedit {
            state.composition = String(cString: preedit)
        }
        state.pageNo = Int(context.menu.page_no)
        // The menu fields stay zeroed unless the Session has a Candidate
        // menu at all, so is_last_page is meaningful only with Candidates.
        state.hasNextPage = context.menu.num_candidates > 0 && context.menu.is_last_page == 0
        if let candidates = context.menu.candidates {
            for index in 0..<Int(context.menu.num_candidates) {
                let candidate = candidates[index]
                state.candidates.append(Candidate(
                    text: candidate.text.map { String(cString: $0) } ?? "",
                    comment: candidate.comment.map { String(cString: $0) }
                ))
            }
        }
        return state
    }

    /// Selects the Candidate at `index` on the current page.
    @discardableResult
    func selectCandidate(at index: Int) -> Bool {
        guard sessionID != 0 else { return false }
        return api.select_candidate_on_current_page(sessionID, index) != 0
    }

    /// Turns to the next page of Candidates. False when there is none (no
    /// menu, or already on the last page) — the page then stays put (probed).
    @discardableResult
    func nextPage() -> Bool {
        guard sessionID != 0 else { return false }
        return api.change_page(sessionID, 0) != 0
    }

    /// Turns back to the previous page of Candidates. False on the first
    /// page — the page then stays put (probed).
    @discardableResult
    func previousPage() -> Bool {
        guard sessionID != 0 else { return false }
        return api.change_page(sessionID, 1) != 0
    }

    /// Takes the pending Commit, if any. A Commit is produced when a
    /// selection covers the whole Composition.
    func takeCommit() -> String? {
        guard sessionID != 0 else { return nil }
        var commit = RimeCommit()
        commit.data_size = Int32(MemoryLayout<RimeCommit>.size - MemoryLayout<Int32>.size)
        guard api.get_commit(sessionID, &commit) != 0 else { return nil }
        defer { _ = api.free_commit(&commit) }
        return commit.text.map { String(cString: $0) }
    }

    /// Discards the in-progress Composition without Committing — e.g. the
    /// keyboard is presented for a new text field.
    func clearComposition() {
        guard sessionID != 0 else { return }
        _ = api.clear_composition(sessionID)
    }

    /// Exports the named User Dictionary to `destination` as librime's TSV
    /// dump (the levers `export_user_dict`) — the archive payload for Export
    /// (ticket 15). Probed alternatives and why they lost:
    /// `backup_user_dict` writes to a CWD-relative sync dir and rewrites
    /// userdb metadata; `sync_user_data` fails outside a maintenance
    /// context. Opens the dictionary read-only; fails cleanly (`exportFailed`)
    /// when another Engine holds its lock. Runs with no Session open.
    func exportUserDictionary(_ name: String, to destination: URL) throws {
        guard running else { throw ManagementError.notRunning }
        guard sessionID == 0 else { throw ManagementError.sessionOpen }
        guard let levers else { throw ManagementError.exportFailed(name) }
        let count = destination.path.withCString { levers.pointee.export_user_dict?(name, $0) } ?? -1
        guard count >= 0 else { throw ManagementError.exportFailed(name) }
    }

    /// Imports a TSV dump into the named User Dictionary (the levers
    /// `import_user_dict`), MERGING entries — librime's only restore
    /// primitive that takes an explicit path (`restore_user_dict` needs the
    /// sync-snapshot format `backup_user_dict` cannot place usefully).
    /// Returns the number of entries imported. Runs with no Session open.
    @discardableResult
    func importUserDictionary(_ name: String, from source: URL) throws -> Int {
        guard running else { throw ManagementError.notRunning }
        guard sessionID == 0 else { throw ManagementError.sessionOpen }
        guard let levers else { throw ManagementError.importFailed(name) }
        let count = source.path.withCString { levers.pointee.import_user_dict?(name, $0) } ?? -1
        guard count >= 0 else { throw ManagementError.importFailed(name) }
        return Int(count)
    }

    /// Destroys the Session and finalizes librime, releasing the Rime
    /// Directory (including the User Dictionary) for other Engines. A new
    /// Engine may start in this process afterwards.
    func shutdown() {
        guard running else { return }
        endSession()
        api.finalize()
        running = false
        Self.startLock.lock()
        Self.didStart = false
        Self.startLock.unlock()
    }

    deinit { shutdown() }
}

extension Engine.DeployError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "the Engine is shut down"
        case .failedToStart:
            return "librime refused to start the Deploy"
        case .schemasFailed(let schemas):
            return "no fresh artifacts for: \(schemas.joined(separator: ", "))"
        }
    }
}

extension Engine.ManagementError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "the Engine is shut down"
        case .sessionOpen:
            return "a Session is holding the User Dictionary"
        case .exportFailed(let name), .importFailed(let name):
            // The likeliest holder is the keyboard's long-lived Session.
            return "\(name) is unavailable — the keyboard may be using it"
        }
    }
}
