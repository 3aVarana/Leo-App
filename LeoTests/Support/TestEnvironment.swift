import Foundation
import FoundationModels

enum TestEnvironment {
    /// The language the app runs in, set by the test plan configuration. Added to snapshot names,
    /// so references recorded in other languages don't overwrite each other.
    static var appLanguage: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    static var isModelAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }
}
