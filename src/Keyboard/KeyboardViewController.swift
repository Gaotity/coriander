import UIKit
import Rime

/// Ticket 05 measurement harness inside the real extension: reports cold
/// start and resident memory at rest, after engine init, and after the
/// baseline dictionary is loaded (keys typed, candidates read). Reads the
/// App Group Rime Directory read-only — Deployed artifacts must already
/// exist (run "Prepare Rime data" in the Container App first, ADR-0001).
final class KeyboardViewController: UIInputViewController {
    private var statusLabel: UILabel!
    private var balloons: [Data] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        let coldStartMs = Date().timeIntervalSince(RimeMeter.processStartTime()) * 1000

        view.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8),
        ])

        statusLabel = UILabel()
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.numberOfLines = 0
        stack.addArrangedSubview(statusLabel)

        let jetsamButton = UIButton(type: .system)
        jetsamButton.setTitle("Jetsam probe (+10 MB steps)", for: .normal)
        jetsamButton.addTarget(self, action: #selector(jetsamProbe), for: .touchUpInside)
        stack.addArrangedSubview(jetsamButton)

        report(String(format: "cold start: %.0f ms", coldStartMs))
        runMeasurement()
    }

    private func runMeasurement() {
        report(String(format: "at rest: %.1f MB", RimeMeter.residentMemoryMB()))

        guard let group = RimeMeter.groupURL else {
            report("FAIL: App Group container unavailable")
            return
        }
        let shared = group.appendingPathComponent(RimeMeter.sharedDirName)
        let user = group.appendingPathComponent(RimeMeter.userDirName)
        guard FileManager.default.fileExists(atPath: shared.path) else {
            report("no seeded data — run Prepare in the app first")
            return
        }

        guard let api = rime_get_api()?.pointee else {
            report("FAIL: rime_get_api nil")
            return
        }
        let dir = strdup(shared.path)!
        let udir = strdup(user.path)!
        let codeName = strdup("coriander")!
        let distName = strdup("Coriander")!
        let distVersion = strdup("0.1")!
        let appName = strdup("coriander.keyboard")!
        defer {
            free(dir); free(udir)
            free(codeName); free(distName); free(distVersion); free(appName)
        }

        var traits = RimeTraits()
        traits.data_size = Int32(MemoryLayout<RimeTraits>.size - MemoryLayout<Int32>.size)
        traits.shared_data_dir = UnsafePointer(dir)
        traits.user_data_dir = UnsafePointer(udir)
        traits.distribution_code_name = UnsafePointer(codeName)
        traits.distribution_name = UnsafePointer(distName)
        traits.distribution_version = UnsafePointer(distVersion)
        traits.app_name = UnsafePointer(appName)

        api.setup(&traits)
        let initStart = Date()
        api.initialize(&traits)
        report(String(format: "initialize: %.2fs, memory %.1f MB",
                      Date().timeIntervalSince(initStart), RimeMeter.residentMemoryMB()))

        let session = api.create_session()
        guard session != 0 else {
            report("create_session: FAILED")
            return
        }
        report(String(format: "session: memory %.1f MB", RimeMeter.residentMemoryMB()))

        // Type "nihao" to force dictionary load, then read candidates.
        for char in "nihao" {
            _ = api.process_key(session, Int32(char.asciiValue!), 0)
        }
        var context = RimeContext()
        context.data_size = Int32(MemoryLayout<RimeContext>.size - MemoryLayout<Int32>.size)
        if api.get_context(session, &context) != 0 {
            report(String(format: "candidates after 'nihao': %d, memory %.1f MB",
                          context.menu.num_candidates, RimeMeter.residentMemoryMB()))
            api.free_context(&context)
        } else {
            report("get_context failed (no candidates?)")
        }

        api.destroy_session(session)
        api.finalize()
        report(String(format: "teardown: memory %.1f MB", RimeMeter.residentMemoryMB()))
    }

    /// Deliberately escalate memory until jetsam kills the extension — the
    /// Console/Settings panic log shows where it died. Manual trigger only.
    @objc private func jetsamProbe() {
        report("jetsam probe: allocating 10 MB chunks…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for i in 1...40 {
                self?.balloons.append(Data(repeating: 0xAB, count: 10 * 1_048_576))
                let mb = RimeMeter.residentMemoryMB()
                NSLog("[CorianderKeyboard] jetsam probe: %d chunks, %.1f MB", i, mb)
                DispatchQueue.main.async { self?.report(String(format: "probe %d: %.1f MB", i, mb)) }
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
    }

    private func report(_ text: String) {
        NSLog("[CorianderKeyboard] %@", text)
        statusLabel.text = (statusLabel.text ?? "") + text + "\n"
    }
}
