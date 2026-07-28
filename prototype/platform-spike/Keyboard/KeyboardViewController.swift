// PROTOTYPE — Ticket 01 platform validation spike. Throwaway; never merge to main.
import UIKit

/// Measures keyboard-extension cold start and probes App Group access.
/// Full Access has no query API — the write probe is the signal: per Hamster's
/// production evidence, group-container writes fail without Full Access.
final class KeyboardViewController: UIInputViewController {
    private let initTime = Date()
    private var statusLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        let coldStartMs = Date().timeIntervalSince(ProbeKit.launchTimestamp) * 1000

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

        let probeButton = UIButton(type: .system)
        probeButton.setTitle("Run keyboard probes", for: .normal)
        probeButton.addTarget(self, action: #selector(runProbes), for: .touchUpInside)
        stack.addArrangedSubview(probeButton)

        report(String(format: "cold start: %.0f ms (process init → viewDidLoad)", coldStartMs))
        runProbes()
    }

    @objc private func runProbes() {
        report(String(format: "resident memory: %.1f MB", ProbeKit.residentMemoryMB()))
        report(ProbeKit.probeGroupRead().description)
        let write = ProbeKit.probeGroupWrite()
        report(write.description)
        report(write.ok
            ? "=> Full Access likely ON (group write succeeded)"
            : "=> Full Access likely OFF (group write failed)")
        report(ProbeKit.logToGroup("keyboard probe, write=\(write.ok)").description)
    }

    private func report(_ text: String) {
        NSLog("[SpikeKeyboard] %@", text)
        statusLabel.text = (statusLabel.text ?? "") + text + "\n"
    }
}
