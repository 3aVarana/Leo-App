import FoundationModels
@testable import Leo
import Testing

/// `.other` is only reached through `@unknown default`, so it can't be built from the framework's cases.
struct ModelAvailabilityTests {
    @Test func available() {
        #expect(ModelAvailability(.available) == .available)
    }

    @Test func deviceNotEligible() {
        #expect(ModelAvailability(.unavailable(.deviceNotEligible)) == .unavailable(.deviceNotEligible))
    }

    @Test func appleIntelligenceNotEnabled() {
        #expect(ModelAvailability(.unavailable(.appleIntelligenceNotEnabled)) ==
            .unavailable(.appleIntelligenceNotEnabled))
    }

    @Test func modelNotReady() {
        #expect(ModelAvailability(.unavailable(.modelNotReady)) == .unavailable(.modelNotReady))
    }
}
