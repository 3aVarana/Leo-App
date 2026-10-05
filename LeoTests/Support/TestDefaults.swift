import Foundation

/// A UserDefaults suite of its own, removed when the test ends. Tests run in parallel,
/// so each one needs its own suite, and none may touch `UserDefaults.standard`.
final class TestDefaults {
    let suiteName = "LeoTests.\(UUID().uuidString)"

    var defaults: UserDefaults { UserDefaults(suiteName: suiteName)! }

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }
}
