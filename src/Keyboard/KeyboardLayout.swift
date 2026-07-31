import CoreGraphics

/// iPhone portrait keyboard geometry, derived proportionally from the
/// keyboard view's width so it scales across devices instead of pinning
/// one model's points. The ratios are measured from the iOS-native iPhone
/// keyboard at its 375pt reference width. Portrait only — landscape and
/// iPad adaptations are ticket 16.
struct KeyboardLayout {
    let width: CGFloat

    /// Distance from the keyboard's edges to the outermost keys.
    var sideMargin: CGFloat { width * 3 / 375 }
    /// Horizontal gap between adjacent keys.
    var keyGap: CGFloat { width * 6 / 375 }
    /// Vertical gap between rows.
    var rowGap: CGFloat { width * 12 / 375 }
    /// Height of every row: the four key rows and the candidate bar.
    var rowHeight: CGFloat { width * 42 / 375 }

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
