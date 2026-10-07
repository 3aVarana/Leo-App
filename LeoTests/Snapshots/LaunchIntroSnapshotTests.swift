@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct LaunchIntroSnapshotTests {
        private let topics = ["Volcanoes", "The solar system", "Pirates and treasure", "Inventors", "Rainforests"]

        private func welcome(intro phase: LaunchIntro.Phase, reduceMotion: Bool? = nil) -> some View {
            WelcomeView(ageGroup: .six, topicNames: topics, onStart: {}, onSettings: {})
                .modifier(LaunchIntroModifier(initialPhase: phase, plays: false, reduceMotion: reduceMotion))
        }

        /// The first frame, for comparing by eye against the launch screen: a centered "Leo" on
        /// the ground, with the page hidden.
        @Test func launchFrame() {
            assertViewSnapshot(of: welcome(intro: .launch), named: "launch")
        }

        /// With Reduce Motion the header "Leo" is part of the page, so it's there as soon as the
        /// page is, not hidden until the intro ends. Frozen frames show the end of the fade.
        @Test func reducedMotionShowsTheHeaderWithThePage() {
            assertViewSnapshot(
                of: welcome(intro: .playing, reduceMotion: true),
                named: "reduced-motion",
            )
        }

        /// The last frame is Welcome as it is without the intro: the same image as
        /// `WelcomeViewSnapshotTests.ageGroup` for six.
        @Test func restFrame() {
            assertViewSnapshot(of: welcome(intro: .done), named: "six")
        }
    }
}
