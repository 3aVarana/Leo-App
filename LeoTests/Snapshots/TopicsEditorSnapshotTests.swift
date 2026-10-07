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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MinimumTopicsWarning(viewModel: viewModel)
                    TopicsEditor(viewModel: viewModel)
                }
                .leoReadableWidth()
            }
            .leoScreenBackground()
        }

        private var customizedPreferences: ReaderPreferences {
            .fixture(
                ageGroup: .nine,
                disabled: [.nine: ["volcanoes", "pirates-treasure"]],
                custom: [.nine: ["Chess", "Origami"]],
            )
        }

        /// Every suggested topic in `.six` turned off except the last 2, plus one of the reader's own.
        private var minimumPreferences: ReaderPreferences {
            let ids = DefaultTopics.topics(for: .six).map(\.id)
            return .fixture(ageGroup: .six, disabled: [.six: Set(ids.dropLast(2))], custom: [.six: ["Chess"]])
        }

        @Test func defaults() {
            assertViewSnapshot(of: editor(ReaderPreferences(ageGroup: .nine)), named: "9-11-defaults")
        }

        /// Turned-off chips, and the reader's own topics with their remove marks.
        @Test func customized() {
            assertViewSnapshot(of: editor(customizedPreferences), named: "9-11-customized")
        }

        /// The reader's own topic can't be removed, and after a refused tap the warning shows.
        @Test func atMinimum() throws {
            let viewModel = PreferencesEditorViewModel.fixture(draft: minimumPreferences)
            try viewModel.setEnabled(false, #require(DefaultTopics.topics(for: .six).last))
            #expect(viewModel.isAtMinimum)
            #expect(viewModel.isShowingMinimumWarning)
            assertViewSnapshot(of: editor(viewModel), named: "6-8-minimum")
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
            assertViewSnapshot(of: editor(viewModel), named: "9-11-message")
        }

        /// A pending review shows the progress indicator and disables the field.
        @Test func reviewing() {
            let viewModel = PreferencesEditorViewModel.fixture(draft: ReaderPreferences(ageGroup: .nine))
            viewModel.newTopic = "Chess"
            viewModel.add()
            #expect(viewModel.isReviewing)
            assertViewSnapshot(of: editor(viewModel), named: "9-11-reviewing")
        }
    }
}
