import SwiftUI
import FoundationModels

struct RootView: View {
    @Environment(PreferencesStore.self) private var store
    @State private var quiz = QuizModel()
    @State private var isShowingSettings = false
    private let model = SystemLanguageModel.default

    var body: some View {
        Group {
            switch model.availability {
            case .available:
                if let preferences = store.preferences {
                    NavigationStack {
                        content(ageGroup: preferences.ageGroup)
                            // Runs after onboarding, on launch and whenever settings are saved.
                            // Unchanged settings keep the round already prepared.
                            .task(id: preferences.roundSettings) {
                                quiz.configure(preferences.roundSettings)
                            }
                            .toolbar {
                                if quiz.phase == .welcome || quiz.phase == .finished {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        Button("Settings", systemImage: "gearshape") {
                                            isShowingSettings = true
                                        }
                                    }
                                }
                            }
                            .sheet(isPresented: $isShowingSettings) {
                                SettingsView(preferences: preferences)
                            }
                    }
                    .animation(.default, value: quiz.phase)
                } else {
                    OnboardingView()
                }
            case .unavailable(let reason):
                UnavailableView(reason: reason)
            }
        }
        .animation(.default, value: store.preferences == nil)
    }

    @ViewBuilder
    private func content(ageGroup: AgeGroup) -> some View {
        switch quiz.phase {
        case .welcome:
            WelcomeView(ageGroup: ageGroup, onStart: quiz.start)
        case .loading:
            LoadingView(index: quiz.currentIndex, total: QuizModel.exerciseCount)
        case .answering:
            if let exercise = quiz.currentExercise {
                ExerciseView(quiz: quiz, exercise: exercise)
                    .id(exercise.id)
            }
        case .finished:
            ResultView(correct: quiz.correctCount, total: QuizModel.exerciseCount, onRestart: quiz.start)
        case .failed(let message):
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

private struct UnavailableView: View {
    let reason: SystemLanguageModel.Availability.UnavailableReason

    var body: some View {
        ContentUnavailableView("Apple Intelligence needed", systemImage: "apple.intelligence", description: Text(message))
    }

    private var message: String {
        switch reason {
        case .deviceNotEligible:
            String(localized: "This device doesn't support Apple Intelligence, which Leo uses to create exercises.")
        case .appleIntelligenceNotEnabled:
            String(localized: "Turn on Apple Intelligence in Settings to start practicing.")
        case .modelNotReady:
            String(localized: "Apple Intelligence is still getting ready. Please try again in a few minutes.")
        @unknown default:
            String(localized: "Apple Intelligence isn't available right now.")
        }
    }
}

#Preview {
    RootView()
        .environment(PreferencesStore(defaults: UserDefaults(suiteName: "preview")!))
}
