import Foundation
import Observation

/// Owns the reader's preferences and the quiz, and is the only place preferences are saved.
@Observable
final class RootViewModel {
    /// `nil` until onboarding is done.
    private(set) var preferences: ReaderPreferences?
    let quiz: QuizViewModel
    var isShowingSettings = false

    private let preferencesRepository: any PreferencesRepository
    private let availabilityProvider: any ModelAvailabilityProvider

    init(
        preferences: any PreferencesRepository,
        availability: any ModelAvailabilityProvider,
        quiz: QuizViewModel,
    ) {
        preferencesRepository = preferences
        availabilityProvider = availability
        self.quiz = quiz
        self.preferences = preferences.load()
    }

    /// Forwarded on every access, never cached, so a view that reads it re-renders when the
    /// model becomes available.
    var availability: ModelAvailability {
        availabilityProvider.availability
    }

    /// Settings can be opened between rounds, not while one is being answered or generated.
    var canShowSettings: Bool {
        quiz.phase == .welcome || quiz.phase == .finished
    }

    /// Saves and applies `preferences`. Does nothing when they haven't changed.
    func save(_ preferences: ReaderPreferences) {
        guard preferences != self.preferences else { return }
        preferencesRepository.save(preferences)
        self.preferences = preferences
    }

    /// Prepares a round with the current preferences. The quiz keeps the round it already has
    /// when the settings are the same.
    func preferencesDidChange() {
        guard let preferences else { return }
        quiz.configure(preferences.roundSettings)
    }
}
