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
                        content(ageGroup: preferences.ageGroup)
                            // Runs after onboarding, on launch and whenever settings are saved.
                            // Unchanged settings keep the round already prepared.
                            .task(id: preferences.roundSettings) {
                                viewModel.preferencesDidChange()
                            }
                            .toolbar {
                                if viewModel.canShowSettings {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        Button("Settings", systemImage: "gearshape") {
                                            viewModel.isShowingSettings = true
                                        }
                                    }
                                }
                            }
                            .sheet(isPresented: $viewModel.isShowingSettings) {
                                SettingsView(preferences: preferences) { viewModel.save($0) }
                            }
                    }
                    .animation(.default, value: quiz.phase)
                } else {
                    OnboardingView { viewModel.save($0) }
                }
            case let .unavailable(reason):
                UnavailableView(reason: reason)
            }
        }
        .animation(.default, value: viewModel.preferences == nil)
    }

    @ViewBuilder
    private func content(ageGroup: AgeGroup) -> some View {
        switch quiz.phase {
        case .welcome:
            WelcomeView(ageGroup: ageGroup, onStart: quiz.start)
        case .loading:
            LoadingView(index: quiz.currentIndex, total: QuizViewModel.exerciseCount)
        case .answering:
            if let exercise = quiz.currentExercise {
                ExerciseView(quiz: quiz, exercise: exercise)
                    .id(exercise.id)
            }
        case .finished:
            ResultView(correct: quiz.correctCount, total: QuizViewModel.exerciseCount, onRestart: quiz.start)
        case let .failed(message):
            ContentUnavailableView {
                Label("Something went wrong", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again", action: quiz.retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    RootView(viewModel: RootViewModel(
        preferences: UserDefaultsPreferencesRepository(defaults: UserDefaults(suiteName: "preview")!),
        availability: SystemModelAvailabilityProvider(),
        quiz: QuizViewModel { FoundationModelsExerciseRepository(ageGroup: $0.ageGroup) },
    ))
}
