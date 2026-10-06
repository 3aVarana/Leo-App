import SwiftUI

/// The design tokens of the Broadsheet redesign (docs/Leo-Redesign-2a-plan.md, section 4).
///
/// Colors are the color sets in `Assets.xcassets/Theme`, each with a dark variant, used through
/// their generated symbols: `.paper`, `.ink`, `.accentInk` and so on. `AccentColor` is the accent.
/// Everything else lives here. Sizes are in points at the default text size; scale the ones that
/// hold text with `@ScaledMetric`.
enum Theme {
    enum Spacing {
        /// Between a label and its description, as in the age rows.
        static let hairline: CGFloat = 2
        /// Between chips, answer rows and round-strip circles, and from an eyebrow to its heading.
        static let tight: CGFloat = 8
        /// Between a heading and the text under it.
        static let compact: CGFloat = 12
        /// Between a question and its answers, and a title and its passage.
        static let related: CGFloat = 14
        /// Inside answer rows, and above a bottom button.
        static let regular: CGFloat = 16
        /// Between sections.
        static let section: CGFloat = 24
        /// Between the round strip and the content under it.
        static let group: CGFloat = 28
        /// The screen's side margin.
        static let gutter: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 1
        /// Buttons, chips, answer rows, inputs and the segmented control.
        static let standard: CGFloat = 2
        static let large: CGFloat = 4
    }

    enum Size {
        static let primaryButtonHeight: CGFloat = 52
        /// Inputs and secondary buttons.
        static let controlHeight: CGFloat = 44
        static let iconButton: CGFloat = 40
        static let stripCircle: CGFloat = 28
        /// The round strip on the welcome screen.
        static let stripCircleLarge: CGFloat = 36
        static let radio: CGFloat = 24
        static let radioStroke: CGFloat = 1.5
        static let checkCircle: CGFloat = 28
        /// Borders of chips, inputs, secondary buttons and upcoming strip circles.
        static let border: CGFloat = 1
    }

    enum Opacity {
        /// Body text that isn't the main text, such as subtitles and the results message.
        static let secondaryText = 0.78
        /// Eyebrows, captions and descriptions.
        static let tertiaryText = 0.70
        /// Answer rows that are neither the correct answer nor the reader's.
        static let dimmed = 0.55
        static let disabled = 0.45
    }
}

extension ShapeStyle where Self == Color {
    static var inkSecondary: Color {
        .ink.opacity(Theme.Opacity.secondaryText)
    }

    static var inkTertiary: Color {
        .ink.opacity(Theme.Opacity.tertiaryText)
    }
}

// MARK: - Type

extension Theme {
    /// A step of the type scale, set in New York. `lineHeight` is a multiple of the size and
    /// `tracking` a fraction of it, as in the design.
    struct TextStyle {
        let size: CGFloat
        var weight: Font.Weight = .regular
        var lineHeight: CGFloat?
        var tracking: CGFloat = 0
        var isItalic = false
        /// The Dynamic Type style the size scales with.
        let relativeTo: Font.TextStyle

        /// The score on the results screen.
        static let display = TextStyle(
            size: 64,
            weight: .semibold,
            lineHeight: 1,
            tracking: -0.03,
            relativeTo: .largeTitle,
        )
        /// The welcome heading.
        static let title1 = TextStyle(
            size: 48,
            weight: .semibold,
            lineHeight: 1.04,
            tracking: -0.025,
            relativeTo: .largeTitle,
        )
        /// The topic being written, on the loading screen.
        static let title2 = TextStyle(
            size: 40,
            weight: .semibold,
            lineHeight: 1.08,
            tracking: -0.02,
            relativeTo: .largeTitle,
        )
        /// "How old are you?"
        static let title3 = TextStyle(
            size: 38,
            weight: .semibold,
            lineHeight: 1.08,
            tracking: -0.02,
            relativeTo: .largeTitle,
        )
        /// "What do you like reading about?"
        static let title4 = TextStyle(
            size: 34,
            weight: .semibold,
            lineHeight: 1.08,
            tracking: -0.02,
            relativeTo: .largeTitle,
        )
        /// The exercise title.
        static let title5 = TextStyle(size: 30, weight: .semibold, lineHeight: 1.1, tracking: -0.02, relativeTo: .title)
        /// Age group labels.
        static let heading = TextStyle(size: 22, weight: .semibold, lineHeight: 1.2, relativeTo: .title2)
        /// The question, the "Leo" wordmark and the feedback heading.
        static let subheading = TextStyle(size: 20, weight: .semibold, lineHeight: 1.3, relativeTo: .title3)
        /// The results message.
        static let lead = TextStyle(size: 19, lineHeight: 29.0 / 19, relativeTo: .body)
        /// The explanation after a wrong answer.
        static let explanation = TextStyle(size: 18, lineHeight: 28.0 / 18, isItalic: true, relativeTo: .body)
        /// Answer options and button titles.
        static let bodyLarge = TextStyle(size: 17, lineHeight: 24.0 / 17, relativeTo: .body)
        /// Subtitles and other running text.
        static let body = TextStyle(size: 16, lineHeight: 1.5, relativeTo: .callout)
        /// Topic chips.
        static let label = TextStyle(size: 15, relativeTo: .subheadline)
        /// Option letters and the numerals of the large round strip.
        static let labelStrong = TextStyle(size: 15, weight: .semibold, relativeTo: .subheadline)
        /// Descriptions and captions.
        static let caption = TextStyle(size: 14, relativeTo: .footnote)
        /// "Your answer", under the reader's wrong pick.
        static let footnote = TextStyle(size: 13, relativeTo: .footnote)
        /// The numerals of the round strip.
        static let footnoteStrong = TextStyle(size: 13, weight: .semibold, relativeTo: .footnote)
        /// Small capitals above a heading. Uppercase the text where it's used.
        static let eyebrow = TextStyle(size: 12, tracking: 0.08, relativeTo: .caption)
    }
}

extension View {
    /// Sets text in a step of the theme's type scale, scaled with Dynamic Type.
    func themeFont(_ style: Theme.TextStyle) -> some View {
        modifier(ThemeFontModifier(style: style))
    }

    /// The app-wide look: the paper ground, ink text and New York for any text that doesn't set
    /// its own font. Apply once, at the root. A `NavigationStack` draws its own background, so
    /// its content also needs `.containerBackground(.paper, for: .navigation)`.
    func leoTheme() -> some View {
        fontDesign(.serif)
            .foregroundStyle(.ink)
            .background(.paper)
    }
}

private struct ThemeFontModifier: ViewModifier {
    let style: Theme.TextStyle
    @ScaledMetric private var size: CGFloat

    init(style: Theme.TextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: style.weight, design: .serif))
            .italic(style.isItalic)
            .tracking(style.tracking * size)
            .lineHeight(style.lineHeight.map { .exact(points: $0 * size) })
    }
}
