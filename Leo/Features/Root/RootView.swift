import SwiftUI

struct RootView: View {
    @Bindable var viewModel: RootViewModel

    private var quiz: QuizViewModel {
        viewModel.quiz
    }

    var body: some View {
        Group {
            switch viewModel.availability {
            case .available:
                if let preferences = viewModel.preferences {
                    NavigationStack {
                        content(preferences)
                            // Runs after onboarding, on launch and whenever settings are saved.
                            // Unchanged settings keep the round already prepared.
                            .task(id: preferences.roundSettings) {
                                viewModel.preferencesDidChange()
                            }
                            .sheet(isPresented: $viewModel.isShowingSettings) {
                                if let editor = viewModel.makeSettingsEditor() {
                                    SettingsView(viewModel: editor)
                                }
                            }
                    }
                    .animation(.default, value: quiz.phase)
                } else {
                    OnboardingView(viewModel: viewModel.makeOnboardingEditor())
                }
            case let .unavailable(reason):
                UnavailableView(reason: reason)
            }
        }
        .animation(.default, value: viewModel.preferences == nil)
        .launchIntro()
    }

    @ViewBuilder
    private func content(_ preferences: ReaderPreferences) -> some View {
        let ageGroup = preferences.ageGroup
        switch quiz.phase {
        case .welcome:
            WelcomeView(
                ageGroup: ageGroup,
                topicNames: quiz.plannedTopicNames,
                onStart: quiz.start,
                onSettings: viewModel.canShowSettings ? { viewModel.isShowingSettings = true } : nil,
            )
            .toolbar(.hidden, for: .navigationBar)
        case .loading:
            LoadingView(
                index: quiz.currentIndex,
                dots: dots,
                topicName: quiz.writingTopicName,
                ageGroup: quiz.roundAgeGroup ?? ageGroup,
            )
            .toolbar(.hidden, for: .navigationBar)
        case .answering:
            if let exercise = quiz.currentExercise {
                ExerciseView(quiz: quiz, exercise: exercise, isReadingTimed: preferences.isReadingTimerOn)
                    .id(exercise.id)
                    .toolbar(.hidden, for: .navigationBar)
            }
        case .finished:
            ResultView(
                answers: quiz.answers,
                ageGroup: quiz.roundAgeGroup ?? ageGroup,
                onRestart: quiz.start,
                onSettings: viewModel.canShowSettings ? { viewModel.isShowingSettings = true } : nil,
            )
            .toolbar(.hidden, for: .navigationBar)
        case .failed:
            GenerationFailedView(
                index: quiz.currentIndex,
                dots: dots,
                topicName: quiz.plannedTopicName(at: quiz.currentIndex),
                onRetry: quiz.retry,
                onTryDifferentTopic: quiz.retryWithDifferentTopics,
            )
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var dots: [DotState] {
        (0 ..< QuizViewModel.exerciseCount).map(quiz.dotState(at:))
    }
}

#Preview {
    RootView(viewModel: RootViewModel(
        preferences: UserDefaultsPreferencesRepository(defaults: UserDefaults(suiteName: "preview")!),
        availability: SystemModelAvailabilityProvider(),
        topicReviews: FoundationModelsTopicReviewRepository(),
        quiz: QuizViewModel { FoundationModelsExerciseRepository(ageGroup: $0.ageGroup) },
    ))
}
