@testable import Leo

/// An in-memory `PreferencesRepository` that records every save.
@MainActor
final class PreferencesRepositorySpy: PreferencesRepository {
    /// What `load()` returns. Updated by `save`, like the real one.
    var stored: ReaderPreferences?
    private(set) var saved: [ReaderPreferences] = []

    init(stored: ReaderPreferences? = nil) {
        self.stored = stored
    }

    func load() -> ReaderPreferences? {
        stored
    }

    func save(_ preferences: ReaderPreferences) {
        saved.append(preferences)
        stored = preferences
    }
}
