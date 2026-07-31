import UIKit

/// One keyboard key with iOS-native chrome: rounded corners, a hard bottom
/// shadow, and a background swap while pressed. Character keys (non-nil
/// `popupText`) additionally show an enlarged keycap popup above the key
/// for the duration of the touch.
final class KeyButton: UIButton {
    /// The string the key forwards or inserts; the controller rewrites it
    /// when the shift state changes. Nil for pure function keys.
    var forwardText: String?
    /// The glyph shown in the keycap popup; nil disables the popup.
    var popupText: String?
    /// The view the popup is added to — the keyboard's root view, so the
    /// popup may overlap the rows and candidate bar above the key.
    weak var popupHost: UIView?

    private let idleColor: UIColor
    private let pressedColor: UIColor
    private var popup: KeyPopupView?

    init(idle: UIColor, pressed: UIColor) {
        idleColor = idle
        pressedColor = pressed
        super.init(frame: .zero)
        backgroundColor = idle
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? pressedColor : idleColor }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Native keycap radius: about 5pt on a 42pt-tall key.
        layer.cornerRadius = bounds.height * 5 / 42
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        showPopup()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        hidePopup()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        hidePopup()
    }

    private func showPopup() {
        guard popup == nil, let host = popupHost, let text = popupText else { return }
        let keyFrame = convert(bounds, to: host)
        let popup = KeyPopupView(text: text, keySize: keyFrame.size, fill: idleColor)
        // Centered on the key, clamped inside the keyboard; the bottom
        // overlaps the key's top edge so bubble and key read as one shape.
        let overlap: CGFloat = 3
        let bottom = keyFrame.minY + overlap
        let top = max(2, bottom - popup.bounds.height)
        popup.frame = CGRect(
            x: min(max(keyFrame.midX - popup.bounds.width / 2, 2),
                   host.bounds.width - popup.bounds.width - 2),
            y: top,
            width: popup.bounds.width,
            height: bottom - top)
        host.addSubview(popup)
        self.popup = popup
    }

    private func hidePopup() {
        popup?.removeFromSuperview()
        popup = nil
    }
}
