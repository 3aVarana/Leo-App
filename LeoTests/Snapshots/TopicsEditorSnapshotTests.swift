@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct TopicsEditorSnapshotTests {
        private func editor(_ preferences: ReaderPreferences) -> some View {
            editor(.fixture(draft: preferences))
        }

        private func editor(_ viewModel: PreferencesEditorViewModel) -> some View {
            List {
                TopicsEditor(viewModel: viewModel)
            }
        }

        private var customizedPreferences: ReaderPreferences {
            .fixture(
                ageGroup: .nine,
                disabled: [.nine: ["volcanoes", "pirates-treasure"]],
                custom: [.nine: ["Chess", "Origami"]],
            )
        }

        /// Every suggested topic in `.six` turned off except the last 3.
        private var minimumPreferences: ReaderPreferences {
            let ids = DefaultTopics.topics(for: .six).map(\.id)
            return .fixture(ageGroup: .six, disabled: [.six: Set(ids.dropLast(3))])
        }

        @Test func defaults() {
            assertViewSnapshot(of: editor(ReaderPreferences(ageGroup: .nine)), named: "9-11-defaults", height: 1250)
        }

        /// "Reset suggested topics" shows once a suggested topic is off.
        @Test func customized() {
            assertViewSnapshot(of: editor(customizedPreferences), named: "9-11-customized", height: 1250)
        }

        /// The footer shows, and the topics still on can't be turned off.
        @Test func atMinimum() {
            assertViewSnapshot(of: editor(minimumPreferences), named: "6-8-minimum", height: 1250)
        }

        /// After a rejected review, the reason shows under the field and the topic stays in it.
        @Test func withMessage() async {
            let reviews = StubTopicReviewRepository(results: [
                .success(.rejected("Pick something you'd enjoy reading about.")),
            ])
            let viewModel = PreferencesEditorViewModel.fixture(
                draft: ReaderPreferences(ageGroup: .nine),
                reviews: reviews,
            )
            viewModel.newTopic = "Taxes"
            viewModel.add()
            await waitUntil { viewModel.message != nil }
            assertViewSnapshot(of: editor(viewModel), named: "9-11-message", height: 1250)
        }

        /// A pending review shows the progress indicator and disables the field.
        @Test func reviewing() {
            let viewModel = PreferencesEditorViewModel.fixture(draft: ReaderPreferences(ageGroup: .nine))
            viewModel.newTopic = "Chess"
            viewModel.add()
            #expect(viewModel.isReviewing)
            assertViewSnapshot(of: editor(viewModel), named: "9-11-reviewing", height: 1250)
        }
    }
}
