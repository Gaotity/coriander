import UIKit

/// The MVP keyboard input path (ticket 08): letter keys feed the Engine, the
/// Composition renders inline in the host app, a candidate bar shows the
/// current page of Candidates, and selection commits into the host app. The
/// 方案 key (ticket 12) opens the schema menu, switching Schemas within the
/// current Session. The keyboard is a pure forwarder — every key goes
/// through `processKey` and Commits are drained from the Engine; key
/// semantics (space selects first Candidate, Return commits raw input,
/// Backspace edits the Composition) live in the Rime configuration, not
/// here. The Session is long-lived (one per extension process, per spec);
/// a stale Composition is dropped on each presentation instead.
final class KeyboardViewController: UIInputViewController {
    private var engine: Engine?
    private let stack = UIStackView()
    private let candidateBar = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        buildKeyboard()
        if case .success(let engine) = KeyboardEngine.shared {
            self.engine = engine
            // True only when this call actually creates the Session — a
            // no-op for an existing one, whose build time must be left alone.
            if engine.startSession() {
                KeyboardEngine.sessionBuiltAt = RimeDirectory.appGroup()?.lastDeployTime
            }
        } else {
            showSetupHint()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // A new presentation may follow a different text field: drop any
        // stale Composition before typing resumes.
        engine?.clearComposition()
        reloadSessionIfDeployed()
        refresh()
    }

    /// Picks up artifacts from a Deploy that ran while this keyboard process
    /// was warm (ADR-0001: the next Session loads the new artifacts). The
    /// Deploy is noticed via `user.yaml`'s build time; a Session restart is
    /// enough to load the new artifacts (probed).
    private func reloadSessionIfDeployed() {
        guard let engine,
              let current = RimeDirectory.appGroup()?.lastDeployTime,
              current != KeyboardEngine.sessionBuiltAt else { return }
        engine.endSession()
        if engine.startSession() {
            KeyboardEngine.sessionBuiltAt = current
        }
    }

    // MARK: Key handling

    @objc private func letterTapped(_ sender: UIButton) {
        guard let character = sender.title(for: .normal)?.first,
              let key = Engine.Key(character: character) else { return }
        engine?.processKey(key)
        refresh()
    }

    @objc private func candidateTapped(_ sender: UIButton) {
        engine?.selectCandidate(at: sender.tag)
        drainCommit()
        refresh()
    }

    @objc private func backspaceTapped() {
        if let engine, !engine.input.composition.isEmpty {
            engine.processKey(.backspace)
        } else {
            textDocumentProxy.deleteBackward()
        }
        refresh()
    }

    @objc private func spaceTapped() {
        forwardOrInsert(.space, " ")
    }

    @objc private func returnTapped() {
        forwardOrInsert(.return, "\n")
    }

    /// Forwards `key` to the Engine while a Composition is in progress
    /// (draining any resulting Commit); otherwise types `fallback` literally.
    private func forwardOrInsert(_ key: Engine.Key, _ fallback: String) {
        if let engine, !engine.input.composition.isEmpty {
            engine.processKey(key)
            drainCommit()
        } else {
            textDocumentProxy.insertText(fallback)
        }
        refresh()
    }

    /// Inserts the pending Commit, if any, into the host app (replacing the
    /// inline marked text).
    private func drainCommit() {
        guard let commit = engine?.takeCommit() else { return }
        textDocumentProxy.insertText(commit)
    }

    private func refresh() {
        guard let engine else { return }
        let state = engine.input
        if state.composition.isEmpty {
            textDocumentProxy.unmarkText()
        } else {
            textDocumentProxy.setMarkedText(
                state.composition,
                selectedRange: NSRange(location: state.composition.utf16.count, length: 0))
        }
        candidateBar.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, candidate) in state.candidates.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(candidate.text, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 20)
            button.tag = index
            button.addTarget(self, action: #selector(candidateTapped), for: .touchUpInside)
            candidateBar.addArrangedSubview(button)
        }
    }

    // MARK: UI construction

    private func buildKeyboard() {
        view.backgroundColor = .secondarySystemBackground
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            view.heightAnchor.constraint(equalToConstant: 280),
        ])

        candidateBar.axis = .horizontal
        candidateBar.distribution = .fillEqually
        candidateBar.spacing = 6
        stack.addArrangedSubview(candidateBar)

        for row in ["qwertyuiop", "asdfghjkl", "zxcvbnm"] {
            stack.addArrangedSubview(makeRow(row.map(String.init), action: #selector(letterTapped)))
        }
        stack.addArrangedSubview(makeFunctionRow())
    }

    private func makeRow(_ titles: [String], action: Selector) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 6
        for title in titles {
            row.addArrangedSubview(makeKey(title: title, action: action))
        }
        return row
    }

    private func makeFunctionRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 6

        // The globe key required by App Store guideline 4.4.1: cycles
        // keyboards on tap, shows the input-mode menu on long press.
        let globe = makeKey(image: "globe",
                            action: #selector(handleInputModeList(from:with:)),
                            events: .allTouchEvents)
        globe.widthAnchor.constraint(equalToConstant: 48).isActive = true
        row.addArrangedSubview(globe)

        // The schema menu (ticket 12): lists exactly the deployed/enabled
        // Schemas; selection switches within the current Session. The menu
        // is computed when opened, so the checkmark always reflects the
        // Session's current Schema and a Container App Deploy's list.
        let schema = makeKey(title: "方案", action: nil)
        schema.widthAnchor.constraint(equalToConstant: 56).isActive = true
        schema.showsMenuAsPrimaryAction = true
        schema.menu = UIMenu(children: [
            UIDeferredMenuElement { [weak self] completion in
                completion(self?.schemaMenuActions() ?? [])
            },
        ])
        row.addArrangedSubview(schema)

        let backspace = makeKey(image: "delete.backward", action: #selector(backspaceTapped))
        backspace.widthAnchor.constraint(equalToConstant: 48).isActive = true
        row.addArrangedSubview(backspace)

        row.addArrangedSubview(makeKey(title: "空格", action: #selector(spaceTapped)))

        let `return` = makeKey(image: "return", action: #selector(returnTapped))
        `return`.widthAnchor.constraint(equalToConstant: 72).isActive = true
        row.addArrangedSubview(`return`)
        return row
    }

    /// One menu action per enabled Schema, the Session's current one
    /// checkmarked. Selecting one switches within the current Session;
    /// librime drops any in-progress Composition (probed), which `refresh`
    /// then unmarks.
    private func schemaMenuActions() -> [UIAction] {
        guard let engine else { return [] }
        let current = engine.currentSchemaID
        return engine.schemas.map { schema in
            UIAction(title: schema.name, state: schema.id == current ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.engine?.selectSchema(schema.id)
                self.refresh()
            }
        }
    }

    private func makeKey(title: String? = nil, image: String? = nil,
                         action: Selector?, events: UIControl.Event = .touchUpInside) -> UIButton {
        let button = UIButton(type: .system)
        if let title {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 20)
        }
        if let image {
            button.setImage(UIImage(systemName: image), for: .normal)
        }
        button.tintColor = .label
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 5
        if let action {
            button.addTarget(self, action: action, for: events)
        }
        return button
    }

    private func showSetupHint() {
        let label = UILabel()
        label.text = "Open the Coriander app to finish setup."
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        stack.addArrangedSubview(label)
    }
}
