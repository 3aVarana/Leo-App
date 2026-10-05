import FoundationModels
@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct UnavailableViewSnapshotTests {
        @Test func deviceNotEligible() {
            assertViewSnapshot(of: UnavailableView(reason: .deviceNotEligible), named: "device-not-eligible")
        }

        @Test func appleIntelligenceNotEnabled() {
            assertViewSnapshot(of: UnavailableView(reason: .appleIntelligenceNotEnabled), named: "not-enabled")
        }

        @Test func modelNotReady() {
            assertViewSnapshot(of: UnavailableView(reason: .modelNotReady), named: "not-ready")
        }
    }
}
