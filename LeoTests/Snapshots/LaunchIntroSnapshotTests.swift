@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct LaunchIntroSnapshotTests {
        private let topics = ["Volcanoes", "The solar system", "Pirates and treasure", "Inventors", "Rainforests"]

        private func welcome(intro phase: LaunchIntro.Phase) -> some View {
            WelcomeView(ageGroup: .six, topicNames: topics, onStart: {}, onSettings: {})
                .modifier(LaunchIntroModifier(initialPhase: phase, plays: false))
        }

        /// The first frame, for comparing by eye against the launch screen: a centered "Leo" on
        /// the ground, with the page hidden.
        @Test func launchFrame() {
            assertViewSnapshot(of: welcome(intro: .launch), named: "launch")
        }

        /// The last frame is Welcome as it is without the intro: the same image as
        /// `WelcomeViewSnapshotTests.ageGroup` for six.
        @Test func restFrame() {
            assertViewSnapshot(of: welcome(intro: .done), named: "six")
        }
    }
}
