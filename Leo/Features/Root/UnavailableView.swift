import SwiftUI

/// Shown instead of the app when the on-device model can't be used. No button: iOS can't open
/// the Apple Intelligence settings page directly.
struct UnavailableView: View {
    let reason: ModelUnavailableReason

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 40

    var body: some View {
        ScrollingScreen {
            TopOffset(height: 140)
            Image(systemName: "apple.intelligence")
                .font(.system(size: iconSize))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.leoAccent700)
                .accessibilityHidden(true)
            Kicker(verbatim: "Leo")
                .padding(.top, 16)
            Text("Apple Intelligence needed")
                .leoTextStyle(.display(40))
                .accessibilityAddTraits(.isHeader)
                .padding(.vertical, 10)
            Text(message)
                .leoTextStyle(.body)
                .foregroundStyle(Color.leoInkSoft)
            Spacer(minLength: 24)
        }
    }

    private var message: String {
        switch reason {
        case .deviceNotEligible:
            String(localized: "This device doesn't support Apple Intelligence, which Leo uses to create exercises.")
        case .appleIntelligenceNotEnabled:
            String(localized: "Turn on Apple Intelligence in Settings to start practicing.")
        case .modelNotReady:
            String(localized: "Apple Intelligence is still getting ready. Please try again in a few minutes.")
        case .other:
            String(localized: "Apple Intelligence isn't available right now.")
        }
    }
}

#Preview {
    UnavailableView(reason: .appleIntelligenceNotEnabled)
}
