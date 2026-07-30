import Foundation
import Rime

/// The Swift adapter over the librime C API — the project's single deep
/// module. One Engine per process: librime cannot finalize and re-initialize
/// within a process, so the first `init` is also the last. This slice exposes
/// the input path only — Session lifecycle, key events, reading
/// Composition/Candidates, Commit. Deploy and schema management join in the
/// tickets that first need them. No librime type crosses this interface.
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

    /// Snapshot of the in-progress input: the Composition plus the current
    /// page of Candidates.
    struct InputState: Equatable {
        var composition = ""
        var candidates: [Candidate] = []
    }

    enum StartError: Error {
        /// `rime_get_api()` returned nil.
        case apiUnavailable
        /// A second Engine in one process — librime cannot re-initialize.
        case alreadyStarted
        /// The Deploy requested at start failed to launch.
        case deployFailed
    }

    private static let startLock = NSLock()
    private static var didStart = false

    private let api: RimeApi
    private var sessionID: RimeSessionId = 0
    private var running = true

    /// Sets up and initializes librime against `directory`. With `deploy`,
    /// runs one full Deploy synchronously before returning (Container App
    /// first launch); otherwise the Engine starts against existing Deployed
    /// artifacts (Keyboard Extension).
    init(directory: RimeDirectory, deploy: Bool) throws {
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

        if deploy {
            // Deploy is async: start_maintenance only kicks it off, the
            // maintenance thread does the work — and join reports no status,
            // so a failed Deploy is detected by its missing artifacts.
            guard api.start_maintenance(1) != 0 else {
                api.finalize()
                throw StartError.deployFailed
            }
            api.join_maintenance_thread()
            let buildDir = directory.user.appendingPathComponent("build", isDirectory: true)
            let artifacts = (try? FileManager.default.contentsOfDirectory(atPath: buildDir.path)) ?? []
            guard !artifacts.isEmpty else {
                api.finalize()
                throw StartError.deployFailed
            }
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

    /// Feeds one key. True means the Session consumed it.
    @discardableResult
    func processKey(_ key: Key) -> Bool {
        guard sessionID != 0 else { return false }
        return api.process_key(sessionID, key.code, key.modifiers) != 0
    }

    /// The current Composition and first page of Candidates.
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

    /// Destroys the Session and finalizes librime, releasing the Rime
    /// Directory (including the User Dictionary) for the other process's
    /// Engine. The process cannot host an Engine again afterwards.
    func shutdown() {
        guard running else { return }
        endSession()
        api.finalize()
        running = false
    }

    deinit { shutdown() }
}
