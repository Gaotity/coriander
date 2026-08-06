import UIKit

/// The keyboard's input path (tickets 08, 12) and Layout (tickets 22, 16).
/// Letter keys feed the Engine, the Composition renders
/// inline in the host app, a candidate bar shows the current page of
/// Candidates with their comments, and selection commits into the host app.
/// Page-turn keys at the bar's ends reach Candidates beyond the first page
/// (ticket 13); the keyboard keeps no paging state of its own — librime
/// resets the page when the Composition changes (probed). The layout follows
/// iOS-native typing chrome — QWERTY geometry with a 123 numbers/symbols
/// layer, shift with lowercase/uppercase/caps-lock states, and key-press
/// popups — all derived proportionally per presentation: iPhone portrait,
/// iPhone landscape, iPad full-size, and iPad floating (see
/// `KeyboardLayout`); the compact Layout choice (ticket 17) shrinks the
/// rows. The 方案 key opens the schema menu, switching
/// Schemas within the current Session. The keyboard is a pure forwarder —
/// every key goes through `processKey` and Commits are drained from the
/// Engine; key semantics (space selects first Candidate, Return commits
/// raw input, Backspace edits the Composition, punctuation shape) live in
/// the Rime configuration, not here. The Session is long-lived (one per
/// extension process, per spec); a stale Composition is dropped on each
/// presentation instead.
final class KeyboardViewController: UIInputViewController {
    /// Shift is keyboard-UI state only: it picks which character a letter
    /// key forwards (`a` vs `A`); the Rime configuration owns what
    /// uppercase input means.
    private enum ShiftState {
        case lowercase, uppercase, capsLock
    }

    private var engine: Engine?
    private let stack = UIStackView()
    private let candidateBar = UIStackView()
    private var qwertyLayer: UIStackView!
    private var numbersLayer: UIStackView!

    /// The candidate bar's page-turn keys (ticket 13). They sit outside the
    /// bar until a Composition opens, so they are held strongly; `refresh`
    /// re-adds them at the ends when the page state calls for them.
    private var pageBackKey: UIButton!
    private var pageForwardKey: UIButton!

    private var shiftState: ShiftState = .lowercase { didSet { applyShift() } }
    private weak var shiftKey: KeyButton?
    private var letterButtons: [KeyButton] = []
    private var characterButtons: [KeyButton] = []
    private var labelButtons: [KeyButton] = []
    private var iconKeys: [(button: UIButton, image: String)] = []

    /// Constraints and stacks whose constants track the keyboard width;
    /// re-resolved in `viewDidLayoutSubviews` from `KeyboardLayout`.
    private var widthSpecs: [(constraint: NSLayoutConstraint, resolve: (KeyboardLayout) -> CGFloat)] = []
    private var rowHeightConstraints: [NSLayoutConstraint] = []
    private var keyGapStacks: [UIStackView] = []
    private var stackLeading: NSLayoutConstraint?
    private var stackTrailing: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var symbolPointSize: CGFloat = 16
    private var laidOutWidth: CGFloat = 0
    private var laidOutBottomInset: CGFloat = 0
    private var laidOutCompact = false

    /// Character keys use the native white keycaps that gray out while
    /// pressed; function keys sit one step darker and flip when pressed
    /// (the flip goes lighter in dark mode).
    private static let characterIdle = UIColor.systemBackground
    private static let characterPressed = UIColor.systemGray2
    private static let functionIdle = UIColor.systemGray2
    private static let functionPressed = UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark ? .systemGray : .systemBackground
    })

    override func viewDidLoad() {
        super.viewDidLoad()
        buildKeyboard()
        if case .success(let engine) = KeyboardEngine.shared {
            self.engine = engine
            // True only when this call actually creates the Session — a
            // no-op for an existing one, whose snapshots must be left alone.
            if engine.startSession() {
                KeyboardEngine.sessionBuiltAt = RimeDirectory.appGroup()?.lastDeployTime
                KeyboardEngine.sessionDictionaryGeneration =
                    KeyboardSettings().userDictionaryGeneration
            }
        } else {
            showSetupHint()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // A new presentation may follow a different text field: drop any
        // stale Composition before typing resumes. Shift likewise reopens
        // in lowercase, matching the native keyboard.
        engine?.clearComposition()
        shiftState = .lowercase
        applySettings()
        reloadSessionIfDeployed()
        reloadSessionIfDictionaryChanged()
        refresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        // The geometry depends on the width, the bottom safe-area inset
        // (the home-indicator side moves when the device flips 180°), and
        // the compact Layout choice; side insets are always zero for the
        // keyboard window (probed) — like the native keyboard, rows span
        // the full width in landscape.
        let compact = KeyboardSettings().keyboardHeight == .compact
        guard width > 0,
              width != laidOutWidth || view.safeAreaInsets.bottom != laidOutBottomInset
                || compact != laidOutCompact
        else { return }
        laidOutWidth = width
        laidOutBottomInset = view.safeAreaInsets.bottom
        laidOutCompact = compact
        let layout = KeyboardLayout(
            width: width, form: layoutForm(width: width), portraitWidth: portraitWidth,
            compact: compact)
        stack.spacing = layout.rowGap
        qwertyLayer.spacing = layout.rowGap
        numbersLayer.spacing = layout.rowGap
        for rowStack in keyGapStacks { rowStack.spacing = layout.keyGap }
        for spec in widthSpecs { spec.constraint.constant = spec.resolve(layout) }
        for constraint in rowHeightConstraints { constraint.constant = layout.rowHeight }
        stackLeading?.constant = layout.sideMargin
        stackTrailing?.constant = -layout.sideMargin
        // The stack's bottom anchors inside the safe area, so the fixed
        // content height must ride above any home-indicator inset.
        heightConstraint?.constant = layout.totalHeight + view.safeAreaInsets.bottom
        symbolPointSize = layout.symbolPointSize
        for iconKey in iconKeys {
            iconKey.button.setImage(UIImage(
                systemName: iconKey.image,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: layout.symbolPointSize)),
                for: .normal)
        }
        for button in letterButtons + characterButtons {
            button.titleLabel?.font = .systemFont(ofSize: layout.glyphFontSize)
        }
        for button in labelButtons {
            button.titleLabel?.font = .systemFont(ofSize: layout.labelFontSize)
        }
        applyShift()
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

    /// Picks up a User Dictionary Clear/Restore that landed while this
    /// keyboard process was warm (ENG-69): the live Session keeps serving
    /// the store it holds open (POSIX unlink, probed in ticket 15), so the
    /// Container App bumps the generation in the settings bridge and the
    /// next presentation restarts the Session — the fresh Session reopens
    /// the store and sees the cleared/restored state. The check is one App
    /// Group defaults read per presentation; the keystroke path pays
    /// nothing.
    private func reloadSessionIfDictionaryChanged() {
        guard let engine else { return }
        let generation = KeyboardSettings().userDictionaryGeneration
        guard generation != KeyboardEngine.sessionDictionaryGeneration else { return }
        engine.endSession()
        if engine.startSession() {
            KeyboardEngine.sessionDictionaryGeneration = generation
        }
    }

    // MARK: Layout forms + settings bridge (ticket 16)

    /// Which presentation the geometry adapts to. iPhone landscape is the
    /// compact-vertical size class; on iPad the idiom never changes, but
    /// the floating presentation (like other compact-width cases) is far
    /// narrower than any docked iPad keyboard, so width discriminates —
    /// 500pt sits between the floating panel (~320pt) and the smallest
    /// full-size iPad width (744pt).
    private func layoutForm(width: CGFloat) -> KeyboardLayout.Form {
        if traitCollection.userInterfaceIdiom == .pad {
            return width < 500 ? .padFloating : .padFull
        }
        return traitCollection.verticalSizeClass == .compact ? .phoneLandscape : .phonePortrait
    }

    /// The device's portrait width: the screen's short side regardless of
    /// orientation. Landscape row heights derive from it so keys track the
    /// device instead of stretching with the long dimension.
    private var portraitWidth: CGFloat {
        min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
    }

    /// Re-reads the settings bridge on every presentation so changes made
    /// in the Container App apply without a Session restart.
    private func applySettings() {
        let settings = KeyboardSettings()
        for button in letterButtons + characterButtons {
            button.popupEnabled = settings.showsKeyPopup
        }
    }

    // MARK: Key handling

    /// Letters always go through the Engine, even with no Composition —
    /// the Session decides whether one starts.
    @objc private func letterTapped(_ sender: KeyButton) {
        guard let text = sender.forwardText, let character = text.first,
              let key = Engine.Key(character: character) else { return }
        engine?.processKey(key)
        drainCommit()
        // Native behavior: one shifted letter drops back to lowercase
        // unless caps lock is on.
        if shiftState == .uppercase { shiftState = .lowercase }
        refresh()
    }

    /// Digits, symbols, and the space-bar punctuation.
    @objc private func characterTapped(_ sender: KeyButton) {
        guard let text = sender.forwardText, let character = text.first else { return }
        forwardCharacter(character, literal: text)
    }

    /// Non-letter keys are forwarded to the Session while a Composition is
    /// active and typed literally otherwise. A character the Session
    /// declines — the baseline config binds none for `。` (probed) — first
    /// commits the first Candidate through the config's space binding,
    /// matching what its bound punctuation keys do (probed), so the key
    /// never dies mid-Composition.
    private func forwardCharacter(_ character: Character, literal: String) {
        if let engine, !engine.input.composition.isEmpty {
            if engine.processKey(key(for: character)) {
                drainCommit()
            } else {
                engine.processKey(.space)
                drainCommit()
                textDocumentProxy.insertText(literal)
            }
        } else {
            textDocumentProxy.insertText(literal)
        }
        refresh()
    }

    /// The Engine key for a character: printable ASCII maps 1:1 onto X11
    /// keysyms; anything else uses the X11 Unicode zone
    /// (0x01000000 | code point) so a configuration that binds the
    /// character still owns its semantics.
    private func key(for character: Character) -> Engine.Key {
        if let key = Engine.Key(character: character) { return key }
        let scalar = character.unicodeScalars.first.map { Int32($0.value) } ?? 0
        return Engine.Key(code: 0x01000000 | scalar)
    }

    @objc private func candidateTapped(_ sender: UIButton) {
        engine?.selectCandidate(at: sender.tag)
        drainCommit()
        refresh()
    }

    @objc private func pageBackTapped() {
        engine?.previousPage()
        refresh()
    }

    @objc private func pageForwardTapped() {
        engine?.nextPage()
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

    /// Single-tap cycles lowercase ⇄ uppercase (and clears caps lock);
    /// double-tap locks caps.
    @objc private func shiftTapped(_ sender: UIControl, event: UIEvent) {
        if (event.touches(for: sender)?.first?.tapCount ?? 1) > 1 {
            shiftState = .capsLock
        } else {
            switch shiftState {
            case .lowercase: shiftState = .uppercase
            case .uppercase, .capsLock: shiftState = .lowercase
            }
        }
    }

    @objc private func layerTapped() {
        numbersLayer.isHidden.toggle()
        qwertyLayer.isHidden.toggle()
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
        if state.pageNo > 0 {
            candidateBar.addArrangedSubview(pageBackKey)
        }
        for (index, candidate) in state.candidates.enumerated() {
            candidateBar.addArrangedSubview(makeCandidateButton(candidate, index: index))
        }
        if state.hasNextPage {
            candidateBar.addArrangedSubview(pageForwardKey)
        }
    }

    /// A candidate bar button: the Candidate's text, with its comment (when
    /// the Schema emits one) trailing smaller and de-emphasized — the
    /// desktop Rime presentation (spec user story 4).
    private func makeCandidateButton(_ candidate: Engine.Candidate, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        let title = NSMutableAttributedString(
            string: candidate.text,
            attributes: [.font: UIFont.systemFont(ofSize: 20)])
        if let comment = candidate.comment {
            title.append(NSAttributedString(
                string: " " + comment,
                attributes: [.font: UIFont.systemFont(ofSize: 13),
                             .foregroundColor: UIColor.secondaryLabel]))
        }
        button.setAttributedTitle(title, for: .normal)
        // Long "text + comment" pairs shrink to fit the bar instead of
        // truncating into ellipses.
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.5
        button.tag = index
        button.addTarget(self, action: #selector(candidateTapped), for: .touchUpInside)
        return button
    }

    /// One of the bar's page-turn keys (ticket 13). Sizing comes from
    /// `KeyboardLayout` like every other key.
    private func makeCandidatePageKey(image: String, action: Selector,
                                      identifier: String) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = .label
        button.accessibilityIdentifier = identifier
        button.addTarget(self, action: action, for: .touchUpInside)
        iconKeys.append((button, image))
        pinWidth(button) { $0.candidateChevronWidth }
        return button
    }

    private func applyShift() {
        let shifted = shiftState != .lowercase
        for button in letterButtons {
            button.forwardText = shifted
                ? button.forwardText?.uppercased()
                : button.forwardText?.lowercased()
        }
        let image: String
        switch shiftState {
        case .lowercase: image = "shift"
        case .uppercase: image = "shift.fill"
        case .capsLock: image = "capslock.fill"
        }
        shiftKey?.setImage(UIImage(
            systemName: image,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: symbolPointSize)),
            for: .normal)
    }

    // MARK: UI construction

    private func buildKeyboard() {
        view.backgroundColor = .secondarySystemBackground
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let leading = stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3)
        let trailing = stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3)
        let height = view.heightAnchor.constraint(equalToConstant: 280)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            leading,
            trailing,
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            height,
        ])
        stackLeading = leading
        stackTrailing = trailing
        heightConstraint = height

        candidateBar.axis = .horizontal
        candidateBar.distribution = .fillEqually
        candidateBar.spacing = 6
        pinRowHeight(candidateBar)
        stack.addArrangedSubview(candidateBar)
        pageBackKey = makeCandidatePageKey(
            image: "chevron.left", action: #selector(pageBackTapped),
            identifier: "candidate-page-back")
        pageForwardKey = makeCandidatePageKey(
            image: "chevron.right", action: #selector(pageForwardTapped),
            identifier: "candidate-page-forward")

        qwertyLayer = buildQwertyLayer()
        numbersLayer = buildNumbersLayer()
        numbersLayer.isHidden = true
        stack.addArrangedSubview(qwertyLayer)
        stack.addArrangedSubview(numbersLayer)
        applyShift()
    }

    private func buildQwertyLayer() -> UIStackView {
        let row1 = makeRow("qwertyuiop".map { makeLetterKey($0) })
        let row2 = makeRow([makeSpacer({ $0.rowTwoInset })]
            + "asdfghjkl".map { makeLetterKey($0) }
            + [makeSpacer({ $0.rowTwoInset })])

        let shift = makeFunctionKey(image: "shift", action: #selector(shiftTapped(_:event:)))
        shiftKey = shift
        pinWidth(shift) { $0.rowThreeFlank }
        let backspace = makeFunctionKey(image: "delete.backward", action: #selector(backspaceTapped))
        pinWidth(backspace) { $0.rowThreeFlank }
        let row3 = makeRow([shift as UIView] + "zxcvbnm".map { makeLetterKey($0) } + [backspace])

        return makeLayer(rows: [row1, row2, row3, makeFunctionRow(lettersLayer: true)])
    }

    private func buildNumbersLayer() -> UIStackView {
        let row1 = makeRow("1234567890".map { makeCharacterKey(String($0)) })
        let row2 = makeRow(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
            .map { makeCharacterKey($0) })
        // The punct keys share the row's remaining width equally, like the
        // native number layer; backspace keeps its QWERTY slot.
        let punctKeys = UIStackView(arrangedSubviews:
            [".", ",", "?", "!", "'"].map { makeCharacterKey($0, pinned: false) })
        punctKeys.axis = .horizontal
        punctKeys.distribution = .fillEqually
        keyGapStacks.append(punctKeys)
        let backspace = makeFunctionKey(image: "delete.backward", action: #selector(backspaceTapped))
        pinWidth(backspace) { $0.rowThreeFlank }
        let row3 = makeRow([makeSpacer({ $0.rowThreeFlank }), punctKeys, backspace])

        return makeLayer(rows: [row1, row2, row3, makeFunctionRow(lettersLayer: false)])
    }

    private func makeFunctionRow(lettersLayer: Bool) -> UIStackView {
        let layerKey = makeLabelKey(lettersLayer ? "123" : "ABC", action: #selector(layerTapped))
        pinWidth(layerKey) { $0.letterWidth }

        // The globe key required by App Store guideline 4.4.1: cycles
        // keyboards on tap, shows the input-mode menu on long press.
        let globe = makeFunctionKey(image: "globe",
                                    action: #selector(handleInputModeList(from:with:)),
                                    events: .allTouchEvents)
        pinWidth(globe) { $0.letterWidth }

        let comma = makeCharacterKey(",")
        let space = makeLabelKey("空格", action: #selector(spaceTapped), characterStyle: true)
        pinWidth(space) { $0.spaceWidth }
        let period = makeCharacterKey("。")
        let returnKey = makeFunctionKey(image: "return", action: #selector(returnTapped))
        pinWidth(returnKey) { $0.returnWidth }
        return makeRow([layerKey, globe, makeSchemaKey(), comma, space, period, returnKey])
    }

    /// The schema menu key (ticket 12), kept one tap away on the function
    /// row of both layers. It lists exactly the deployed/enabled Schemas;
    /// selection switches within the current Session. The deferred element
    /// must be `uncached` — the plain provider variant realizes its items
    /// only once and reuses them, freezing the checkmark (and a re-Deployed
    /// list) at first open; found in the ticket 12 device smoke.
    private func makeSchemaKey() -> UIView {
        let button = KeyButton(idle: Self.functionIdle, pressed: Self.functionPressed)
        button.setTitle("方案", for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.showsMenuAsPrimaryAction = true
        button.menu = UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                completion(self?.schemaMenuActions() ?? [])
            },
        ])
        labelButtons.append(button)
        pinWidth(button) { $0.schemaWidth }
        return button
    }

    private func makeLetterKey(_ letter: Character) -> UIView {
        let button = KeyButton(idle: Self.characterIdle, pressed: Self.characterPressed)
        // Native keycaps always show the uppercase glyph; shift changes
        // only which character is forwarded.
        button.setTitle(String(letter).uppercased(), for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.forwardText = String(letter)
        button.popupText = String(letter).uppercased()
        button.popupHost = view
        button.addTarget(self, action: #selector(letterTapped(_:)), for: .touchUpInside)
        letterButtons.append(button)
        pinWidth(button) { $0.letterWidth }
        return button
    }

    private func makeCharacterKey(_ character: String, pinned: Bool = true) -> UIView {
        let button = KeyButton(idle: Self.characterIdle, pressed: Self.characterPressed)
        button.setTitle(character, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.forwardText = character
        button.popupText = character
        button.popupHost = view
        button.addTarget(self, action: #selector(characterTapped(_:)), for: .touchUpInside)
        characterButtons.append(button)
        if pinned { pinWidth(button) { $0.letterWidth } }
        return button
    }

    private func makeFunctionKey(image: String, action: Selector,
                                 events: UIControl.Event = .touchUpInside) -> KeyButton {
        let button = KeyButton(idle: Self.functionIdle, pressed: Self.functionPressed)
        button.tintColor = .label
        button.addTarget(self, action: action, for: events)
        iconKeys.append((button, image))
        return button
    }

    private func makeLabelKey(_ title: String, action: Selector,
                              characterStyle: Bool = false) -> UIView {
        let button = KeyButton(
            idle: characterStyle ? Self.characterIdle : Self.functionIdle,
            pressed: characterStyle ? Self.characterPressed : Self.functionPressed)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        labelButtons.append(button)
        return button
    }

    /// An invisible spacer holding a key's slot where a row leaves it
    /// empty (row 2's inset, the number layer's missing shift key).
    private func makeSpacer(_ resolve: @escaping (KeyboardLayout) -> CGFloat) -> UIView {
        let spacer = UIView()
        spacer.isUserInteractionEnabled = false
        return pinWidth(spacer, resolve)
    }

    private func makeRow(_ keys: [UIView]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: keys)
        row.axis = .horizontal
        keyGapStacks.append(row)
        pinRowHeight(row)
        return row
    }

    private func makeLayer(rows: [UIStackView]) -> UIStackView {
        let layer = UIStackView(arrangedSubviews: rows)
        layer.axis = .vertical
        return layer
    }

    /// Registers a width constraint re-resolved from `KeyboardLayout` on
    /// every layout pass.
    @discardableResult
    private func pinWidth(_ view: UIView,
                          _ resolve: @escaping (KeyboardLayout) -> CGFloat) -> UIView {
        let constraint = view.widthAnchor.constraint(equalToConstant: 0)
        constraint.isActive = true
        widthSpecs.append((constraint, resolve))
        return view
    }

    private func pinRowHeight(_ view: UIView) {
        let constraint = view.heightAnchor.constraint(equalToConstant: 42)
        constraint.isActive = true
        rowHeightConstraints.append(constraint)
    }

    /// One menu action per enabled Schema, the Session's current one
    /// checkmarked. Selecting one switches within the current Session;
    /// librime drops any in-progress Composition on switch (probed), which
    /// `refresh` then unmarks.
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

    /// With no Engine there is nothing to type on: hide the typing UI and
    /// show only the hint (the rows' pinned heights leave the label no room).
    private func showSetupHint() {
        candidateBar.isHidden = true
        qwertyLayer.isHidden = true
        numbersLayer.isHidden = true
        let label = UILabel()
        label.text = "Open the Coriander app to finish setup."
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        stack.addArrangedSubview(label)
    }
}
