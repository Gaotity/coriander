import SwiftUI
import Rime

@main
struct CorianderApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var result = "running Rime smoke…"
    @State private var didRun = false

    var body: some View {
        ScrollView {
            Text(result)
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .onAppear {
            guard !didRun else { return }  // finalize→re-initialize is not a safe cycle
            didRun = true
            result = RimeSmoke.run()
        }
    }
}

/// Ticket 04 smoke: print the librime version and drive a full
/// setup → initialize → create session → destroy session → finalize cycle
/// against empty scratch data dirs. Success means the XCFramework links and
/// the Engine's C API is reachable from Swift with no C++ exposure.
///
/// librime 1.17 exposes the API as a struct of function pointers
/// (`rime_get_api()`); the classic free functions are deprecated.
enum RimeSmoke {
    static func run() -> String {
        var lines: [String] = []
        func report(_ line: String) {
            lines.append(line)
            NSLog("[RimeSmoke] %@", line)
        }

        guard let api = rime_get_api()?.pointee else {
            report("rime_get_api: FAILED (nil)")
            return lines.joined(separator: "\n")
        }

        report("get_version: \(api.get_version().map { String(cString: $0) } ?? "(nil)")")

        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("rime-smoke", isDirectory: true)
        try? FileManager.default.removeItem(at: base)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        // strdup keeps the C strings alive until finalize returns; all Rime
        // dirs point at the same scratch dir for this smoke.
        let dir = strdup(base.path)!
        let codeName = strdup("coriander-smoke")!
        let distName = strdup("Coriander Smoke")!
        let distVersion = strdup("0.1")!
        let appName = strdup("coriander.smoke")!
        defer {
            free(dir)
            free(codeName); free(distName); free(distVersion); free(appName)
        }

        var traits = RimeTraits()
        // librime ABI convention: data_size = sizeof(RimeTraits) - sizeof(int)
        traits.data_size = Int32(MemoryLayout<RimeTraits>.size - MemoryLayout<Int32>.size)
        traits.shared_data_dir = UnsafePointer(dir)
        traits.user_data_dir = UnsafePointer(dir)
        traits.log_dir = UnsafePointer(dir)
        traits.distribution_code_name = UnsafePointer(codeName)
        traits.distribution_name = UnsafePointer(distName)
        traits.distribution_version = UnsafePointer(distVersion)
        traits.app_name = UnsafePointer(appName)

        api.setup(&traits)
        api.initialize(&traits)
        report("setup + initialize: done")

        let session = api.create_session()
        report(session != 0
            ? "create_session: ok (id \(session))"
            : "create_session: FAILED (id 0)")
        if session != 0 {
            report("destroy_session: \(api.destroy_session(session) != 0 ? "ok" : "FAILED")")
        }

        api.finalize()
        report("finalize: done")
        return lines.joined(separator: "\n")
    }
}

#Preview { ContentView() }
