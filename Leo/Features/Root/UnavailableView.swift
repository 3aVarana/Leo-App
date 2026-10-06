import SwiftUI

/// Shown instead of the app when the on-device model can't be used.
struct UnavailableView: View {
    let reason: ModelUnavailableReason

    var body: some View {
        ContentUnavailableView(
            "Apple Intelligence needed",
            systemImage: "apple.intelligence",
            description: Text(message),
        )
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
