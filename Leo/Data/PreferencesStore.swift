import Foundation
import Observation

/// Loads and saves the reader's preferences. `nil` until onboarding is done.
@Observable
final class PreferencesStore {
    private static let key = "readerPreferences"

    @ObservationIgnored private let defaults: UserDefaults

    var preferences: ReaderPreferences? {
        didSet {
            guard preferences != oldValue else { return }
            if let preferences, let data = try? JSONEncoder().encode(preferences) {
                defaults.set(data, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(ReaderPreferences.self, from: $0) }
    }
}
