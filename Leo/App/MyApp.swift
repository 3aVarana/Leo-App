import SwiftUI

/// The composition root: builds the repositories and the ViewModels they're injected into.
@main struct MyApp: App {
    @State private var root = RootViewModel(
        preferences: UserDefaultsPreferencesRepository(defaults: .standard),
        availability: SystemModelAvailabilityProvider(),
        quiz: QuizViewModel { FoundationModelsExerciseRepository(ageGroup: $0.ageGroup) },
    )

    /// Passed by the test plans, so the test host doesn't show the app or start generating exercises.
    private let isRunningTests = ProcessInfo.processInfo.arguments.contains("--leo-running-tests")

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
