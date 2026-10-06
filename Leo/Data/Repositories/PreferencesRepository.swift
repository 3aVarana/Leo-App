import Foundation
import OSLog

/// Loads and saves the reader's preferences. Stateless: `RootViewModel` holds the current value.
protocol PreferencesRepository {
    /// `nil` until onboarding is done, or when the saved data can't be read.
    func load() -> ReaderPreferences?
    func save(_ preferences: ReaderPreferences)
}

/// Keeps the preferences as JSON in `UserDefaults`.
struct UserDefaultsPreferencesRepository: PreferencesRepository {
    /// Never change it: existing installs read their preferences under this key.
    static let key = "readerPreferences"

    let defaults: UserDefaults

    private let logger = Logger(subsystem: "Leo", category: "PreferencesRepository")

    func load() -> ReaderPreferences? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        do {
            return try JSONDecoder().decode(ReaderPreferences.self, from: data)
        } catch {
            logger.error("Couldn't read the saved preferences: \(error)")
            return nil
        }
    }

    /// Keeps the saved data if encoding fails, which `ReaderPreferences` never does in practice.
    func save(_ preferences: ReaderPreferences) {
        do {
            try defaults.set(JSONEncoder().encode(preferences), forKey: Self.key)
        } catch {
            logger.error("Couldn't save the preferences: \(error)")
        }
    }
}
