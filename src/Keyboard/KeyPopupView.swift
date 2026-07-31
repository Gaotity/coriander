import UIKit

/// The enlarged keycap iOS shows above a pressed key: a rounded bubble
/// joined back to the key by a trapezoid stem. Created on touch-down and
/// removed on release; sized from the pressed key so it scales with the
/// layout. The bubble keeps its size and the stem absorbs any clamping at
/// the keyboard's top edge, so the popup always stays connected to its key.
final class KeyPopupView: UIView {
    private let label = UILabel()
    private let fill: UIColor
    private let keyWidth: CGFloat
    private let bubbleHeight: CGFloat

    init(text: String, keySize: CGSize, fill: UIColor) {
        self.fill = fill
        self.keyWidth = keySize.width
        self.bubbleHeight = keySize.height * 1.15
        let stemHeight = keySize.height * 0.45
        let width = keySize.width * 1.75
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: bubbleHeight + stemHeight))
        backgroundColor = .clear
        isUserInteractionEnabled = false
        label.text = text
        label.textAlignment = .center
        label.font = .systemFont(ofSize: keySize.height * 0.75)
        label.frame = CGRect(x: 0, y: 0, width: width, height: bubbleHeight)
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        fill.setFill()
        let corner = bubbleHeight / 5
        UIBezierPath(
            roundedRect: CGRect(x: 0, y: 0, width: bounds.width, height: bubbleHeight),
            cornerRadius: corner
        ).fill()
        // Trapezoid stem: narrow at the bubble, flaring out to the key's
        // width at the bottom, overlapping the bubble to avoid a seam.
        let topWidth = bounds.width * 0.55
        let stem = UIBezierPath()
        stem.move(to: CGPoint(x: (bounds.width - topWidth) / 2, y: bubbleHeight - corner))
        stem.addLine(to: CGPoint(x: (bounds.width - keyWidth) / 2, y: bounds.height))
        stem.addLine(to: CGPoint(x: (bounds.width + keyWidth) / 2, y: bounds.height))
        stem.addLine(to: CGPoint(x: (bounds.width + topWidth) / 2, y: bubbleHeight - corner))
        stem.close()
        stem.fill()
    }
}
