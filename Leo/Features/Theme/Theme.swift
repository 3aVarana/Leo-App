import SwiftUI
import UIKit

// The Broadsheet look of docs/Leo-Redesign-Plan.md, section 3: the color tokens, the Source Serif 4
// text styles and the screen layout helpers. Views use these instead of system colors and fonts.

// MARK: - Colors

/// The color sets in `Assets.xcassets/Colors`. Each has a light (2a) and a dark (3a) appearance.
extension Color {
    static let leoBackground = Color(.background)
    static let leoSurface = Color(.surface)
    static let leoInk = Color(.ink)
    /// Body text that's a step quieter than `leoInk`.
    static let leoInkSoft = leoInk.opacity(0.78)
    /// Kickers and captions.
    static let leoInkMuted = leoInk.opacity(0.7)
    static let leoDivider = Color(.divider)

    static let leoAccent = Color(.accent)
    static let leoAccentPressed = Color(.accentPressed)
    /// Ghost button labels: `leoAccent700` in light mode, where `leoAccent` is too light for small text.
    static let leoAccentLink = Color(.accentLink)
    static let leoAccent100 = Color(.accent100)
    static let leoAccent700 = Color(.accent700)
    static let leoAccent800 = Color(.accent800)
    static let leoAccent900 = Color(.accent900)

    static let leoMagenta = Color(.magenta)
    static let leoMagenta100 = Color(.magenta100)
    static let leoMagenta600 = Color(.magenta600)
    static let leoMagenta700 = Color(.magenta700)
    static let leoMagenta900 = Color(.magenta900)

    static let leoNeutral300 = Color(.neutral300)
    static let leoNeutral600 = Color(.neutral600)
    static let leoNeutral700 = Color(.neutral700)
}

// MARK: - Typography

enum LeoWeight {
    case regular, italic, semibold

    /// The PostScript names of the fonts in `Resources/Fonts`, registered through `UIAppFonts`.
    var fontName: String {
        switch self {
        case .regular: "SourceSerif4-Regular"
        case .italic: "SourceSerif4-It"
        case .semibold: "SourceSerif4-Semibold"
        }
    }
}

extension Font {
    /// Source Serif 4 at `size`, scaled with Dynamic Type like `style`.
    static func leo(_ size: CGFloat, _ weight: LeoWeight = .regular, relativeTo style: Font.TextStyle) -> Font {
        .custom(weight.fontName, size: size, relativeTo: style)
    }
}

/// A text role from the type table in section 3.2 of the redesign plan: the mock's size, weight
/// and line height, and the text style it scales with.
struct LeoTextStyle {
    var size: CGFloat
    var weight: LeoWeight = .regular
    var relativeTo: Font.TextStyle
    /// In points at the default text size. `nil` keeps the font's own line height.
    var lineHeight: CGFloat?
    /// Letter spacing in em.
    var tracking: CGFloat = 0
    /// `false` keeps the font at `size` at every text size.
    var scalesWithDynamicType = true

    var font: Font {
        scalesWithDynamicType ? .leo(size, weight, relativeTo: relativeTo) : .custom(weight.fontName, fixedSize: size)
    }

    /// Headlines: 48 on Welcome, 40 on Loading and Error, 38 and 34 in onboarding.
    static func display(_ size: CGFloat) -> LeoTextStyle {
        LeoTextStyle(
            size: size,
            weight: .semibold,
            relativeTo: .largeTitle,
            lineHeight: size * (size >= 48 ? 1.04 : 1.08),
            tracking: size >= 48 ? -0.025 : -0.02,
        )
    }

    static let score = LeoTextStyle(
        size: 64, weight: .semibold, relativeTo: .largeTitle, lineHeight: 64, tracking: -0.03,
    )
    static let title = LeoTextStyle(size: 30, weight: .semibold, relativeTo: .title, lineHeight: 33, tracking: -0.02)
    static let question = LeoTextStyle(size: 20, weight: .semibold, relativeTo: .title3, lineHeight: 26)
    static let reviewQuestion = LeoTextStyle(size: 19, weight: .semibold, relativeTo: .title3, lineHeight: 24.7)
    static let verdict = LeoTextStyle(size: 20, weight: .semibold, relativeTo: .title3)
    static let ageLabel = LeoTextStyle(size: 22, weight: .semibold, relativeTo: .title2, lineHeight: 26.4)
    static let wordmark = LeoTextStyle(size: 20, weight: .semibold, relativeTo: .title3)
    /// The launch screen's "Leo". Fixed, like the launch image it continues.
    static let launchWordmark = LeoTextStyle(
        size: 48, weight: .semibold, relativeTo: .largeTitle, scalesWithDynamicType: false,
    )
    static let bodyLarge = LeoTextStyle(size: 17, relativeTo: .body, lineHeight: 27)
    static let resultMessage = LeoTextStyle(size: 19, relativeTo: .body, lineHeight: 29)
    static let body = LeoTextStyle(size: 16, relativeTo: .callout, lineHeight: 24)
    static let bodySmall = LeoTextStyle(size: 15, relativeTo: .subheadline, lineHeight: 22)
    static let caption = LeoTextStyle(size: 14, relativeTo: .subheadline)
    static let note = LeoTextStyle(size: 13, relativeTo: .footnote)
    static let explanation = LeoTextStyle(size: 18, weight: .italic, relativeTo: .body, lineHeight: 28)
    static let reviewExplanation = LeoTextStyle(size: 17, weight: .italic, relativeTo: .body, lineHeight: 26)
    static let answer = LeoTextStyle(size: 17, relativeTo: .body, lineHeight: 24)
    static let answerMarker = LeoTextStyle(size: 15, weight: .semibold, relativeTo: .subheadline)
    static let kicker = LeoTextStyle(size: 12, relativeTo: .caption, tracking: 0.08)
}

extension View {
    /// Sets the font, line height and letter spacing of a text role.
    func leoTextStyle(_ style: LeoTextStyle) -> some View {
        modifier(LeoTextStyleModifier(style: style))
    }
}

private struct LeoTextStyleModifier: ViewModifier {
    let style: LeoTextStyle

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking * style.size)
            .lineHeight(lineHeight.map { .exact(points: $0) })
    }

    /// The mock's line height, scaled with Dynamic Type like the font.
    private var lineHeight: CGFloat? {
        guard let points = style.lineHeight else { return nil }
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        return UIFontMetrics(forTextStyle: UIFont.TextStyle(style.relativeTo)).scaledValue(
            for: points,
            compatibleWith: traits,
        )
    }
}

private extension UIFont.TextStyle {
    private static let matching: [Font.TextStyle: UIFont.TextStyle] = [
        .largeTitle: .largeTitle, .title: .title1, .title2: .title2, .title3: .title3,
        .headline: .headline, .subheadline: .subheadline, .callout: .callout,
        .caption: .caption1, .caption2: .caption2, .footnote: .footnote,
    ]

    init(_ style: Font.TextStyle) {
        self = Self.matching[style] ?? .body
    }
}

// MARK: - Layout

extension View {
    /// The 24-point gutters, and a centered column of about 600 points on iPad and in landscape.
    /// Content stays left-aligned inside it.
    func leoReadableWidth() -> some View {
        padding(.horizontal, 24)
            .frame(maxWidth: 648, alignment: .leading)
            .frame(maxWidth: .infinity)
    }

    /// The Broadsheet ground behind a whole screen.
    func leoScreenBackground() -> some View {
        background(Color.leoBackground.ignoresSafeArea())
    }
}

extension EnvironmentValues {
    /// Whether placeholders pulse. Off in snapshot tests, so the image doesn't depend on timing.
    @Entry var animatesPlaceholders = true
}
