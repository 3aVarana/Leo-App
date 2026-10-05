import Foundation
import FoundationModels
import Testing

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

/// Groups the suites that use the real on-device model. Only `LeoLiveModel.xctestplan` runs
/// them. They run one at a time, so requests don't compete for the model and each test's
/// time limit covers only its own work.
@Suite(.serialized, .tags(.liveModel), .enabled(if: TestEnvironment.isModelAvailable))
enum LiveModel {}
