import SwiftUI

/// The three Broadsheet buttons. Square 2-point corners, serif labels.
struct LeoButtonStyle: ButtonStyle {
    enum Kind {
        /// Full width, accent fill: the screen's main action.
        case primary
        /// A hairline border, for actions beside content, like Add.
        case secondary
        /// Accent text without a border, for quieter actions.
        case ghost
    }

    let kind: Kind

    init(_ kind: Kind) {
        self.kind = kind
    }

    func makeBody(configuration: Configuration) -> some View {
        LeoButton(kind: kind, configuration: configuration)
    }
}

extension ButtonStyle where Self == LeoButtonStyle {
    static func leo(_ kind: LeoButtonStyle.Kind) -> LeoButtonStyle {
        LeoButtonStyle(kind)
    }
}

private struct LeoButton: View {
    let kind: LeoButtonStyle.Kind
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .headline) private var primaryHeight = 52
    @ScaledMetric(relativeTo: .subheadline) private var secondaryHeight = 44

    var body: some View {
        styled
            .opacity(isEnabled ? 1 : 0.45)
    }

    @ViewBuilder
    private var styled: some View {
        switch kind {
        case .primary:
            label
                .leoTextStyle(LeoTextStyle(size: 17, weight: .semibold, relativeTo: .headline))
                .foregroundStyle(Color.leoBackground)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: primaryHeight)
                .background(
                    configuration.isPressed ? Color.leoAccentPressed : Color.leoAccent,
                    in: .rect(cornerRadius: 2),
                )
        case .secondary:
            label
                .leoTextStyle(LeoTextStyle(size: 15, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(Color.leoInk)
                .padding(.horizontal, 14)
                .frame(minHeight: secondaryHeight)
                .background(configuration.isPressed ? Color.leoInk.opacity(0.14) : .clear, in: .rect(cornerRadius: 2))
                .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(Color.leoDivider) }
        case .ghost:
            label
                .leoTextStyle(LeoTextStyle(size: 16, weight: .semibold, relativeTo: .callout))
                .foregroundStyle(Color.leoAccentLink)
                .padding(.horizontal, 4)
                .frame(minHeight: secondaryHeight)
                .background(
                    configuration.isPressed ? Color.leoAccent.opacity(0.18) : .clear,
                    in: .rect(cornerRadius: 2),
                )
        }
    }

    private var label: some View {
        configuration.label
            .multilineTextAlignment(.center)
            .contentShape(.rect)
    }
}

#Preview {
    VStack(spacing: 16) {
        Button("Start") {}
            .buttonStyle(.leo(.primary))
        Button("Continue") {}
            .buttonStyle(.leo(.primary))
            .disabled(true)
        Button("Try again", systemImage: "arrow.clockwise") {}
            .buttonStyle(.leo(.primary))
        Button("Add") {}
            .buttonStyle(.leo(.secondary))
        Button("Try a different topic") {}
            .buttonStyle(.leo(.ghost))
    }
    .padding(24)
    .leoScreenBackground()
}
