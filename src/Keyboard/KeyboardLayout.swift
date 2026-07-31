import CoreGraphics

/// Keyboard geometry, derived proportionally from the keyboard view's
/// width so it scales across devices instead of pinning one model's
/// points (ticket 22). Every presentation keeps the same structure; a
/// `Form` only changes the reference each metric scales from (ticket 16).
/// The iPhone-portrait ratios are measured from the iOS-native iPhone
/// keyboard at its 375pt reference width.
struct KeyboardLayout {
    /// The presentation the geometry adapts to.
    enum Form {
        /// iPhone portrait: the ticket 22 geometry, unchanged.
        case phonePortrait
        /// iPhone landscape: the native landscape keyboard keeps the
        /// portrait structure with shorter rows, so vertical metrics
        /// derive from the device's portrait width rather than the long
        /// dimension.
        case phoneLandscape
        /// iPad full-size: scales from a 768pt reference, the iPad
        /// counterpart of the 375pt iPhone reference.
        case padFull
        /// The floating iPad keyboard (and any other compact-width
        /// presentation) follows the iPhone-portrait ratios.
        case padFloating
    }

    let width: CGFloat
    let form: Form
    /// The device's portrait width; only `phoneLandscape` metrics use it.
    let portraitWidth: CGFloat

    init(width: CGFloat, form: Form = .phonePortrait, portraitWidth: CGFloat? = nil) {
        self.width = width
        self.form = form
        self.portraitWidth = portraitWidth ?? width
    }

    /// The reference width horizontal metrics scale from: the 375pt
    /// iPhone reference everywhere except iPad full-size, whose native
    /// gaps and margins track its 768pt reference instead.
    private var horizontalReference: CGFloat {
        form == .padFull ? 768 : 375
    }

    /// Distance from the keyboard's edges to the outermost keys.
    var sideMargin: CGFloat { width * 3 / horizontalReference }
    /// Horizontal gap between adjacent keys.
    var keyGap: CGFloat { width * 6 / horizontalReference }
    /// Vertical gap between rows.
    var rowGap: CGFloat {
        switch form {
        case .phonePortrait, .padFloating: return width * 12 / 375
        case .phoneLandscape: return portraitWidth * 8 / 375
        case .padFull: return width * 11 / 768
        }
    }
    /// Height of every row: the four key rows and the candidate bar.
    var rowHeight: CGFloat {
        switch form {
        case .phonePortrait, .padFloating: return width * 42 / 375
        // Native landscape rows run ~33pt where portrait's are 42pt.
        case .phoneLandscape: return portraitWidth * 33 / 375
        // Native iPad rows run ~55pt at the 768pt reference width.
        case .padFull: return width * 55 / 768
        }
    }

    /// The uniform letter-key width: ten letters plus gaps fill a row.
    var letterWidth: CGFloat {
        (width - 2 * sideMargin - 9 * keyGap) / 10
    }
    /// Row 2 is staggered by half a key pitch like the native layout; with
    /// uniform gaps each spacer is half a pitch minus one gap.
    var rowTwoInset: CGFloat { (letterWidth - keyGap) / 2 }
    /// Shift and backspace flank row 3; sized so the row fills exactly and
    /// its outer edges align with the letter rows.
    var rowThreeFlank: CGFloat { 1.5 * letterWidth + 0.5 * keyGap }

    /// 方案 needs extra room for two CJK glyphs; the other function-row
    /// keys take one letter-key width, return a bit over two, and space
    /// gets what remains of the ten-letter budget.
    var schemaWidth: CGFloat { 1.4 * letterWidth }
    var returnWidth: CGFloat { 2.1 * letterWidth }
    var spaceWidth: CGFloat {
        10 * letterWidth + 9 * keyGap
            - 2 * letterWidth - schemaWidth - 2 * letterWidth
            - returnWidth - 6 * keyGap
    }

    /// Keyboard height: candidate bar + four key rows plus padding.
    var totalHeight: CGFloat {
        6 + 5 * rowHeight + 4 * rowGap + 4
    }

    /// Letter/digit/symbol keycap size (~22pt at the reference width).
    var glyphFontSize: CGFloat { rowHeight * 0.52 }
    /// Label-key size (方案, 空格, 123, ABC).
    var labelFontSize: CGFloat { rowHeight * 0.36 }
    /// SF Symbol point size for the image keys (shift, backspace, …).
    var symbolPointSize: CGFloat { rowHeight * 0.42 }
}
