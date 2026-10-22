import SwiftUI

/// The composition root: builds the repositories and the ViewModels they're injected into.
@main struct MyApp: App {
    /// Passed by the test plans, so the test host doesn't show the app or start generating
    /// exercises, and never touches the on-disk round history store.
    private let isRunningTests = ProcessInfo.processInfo.arguments.contains("--leo-running-tests")

    @State private var root: RootViewModel

    init() {
        let history = RoundHistoryViewModel(
            repository: isRunningTests ? .inMemory() : SwiftDataRoundHistoryRepository.live(),
        )
        root = RootViewModel(
            preferences: UserDefaultsPreferencesRepository(defaults: .standard),
            availability: SystemModelAvailabilityProvider(),
            topicReviews: FoundationModelsTopicReviewRepository(),
            quiz: QuizViewModel(
                makeRepository: { FoundationModelsExerciseRepository(ageGroup: $0.ageGroup) },
                onRoundFinished: { history.record($0) },
            ),
            history: history,
        )
    }

    var body: some Scene {
        WindowGroup {
            if isRunningTests {
                EmptyView()
            } else {
                RootView(viewModel: root)
            }
        }
    }
}
