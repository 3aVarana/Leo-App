import Foundation
import FoundationModels

/// The language exercises are written in: the device's preferred language when the
/// on-device model supports it, English otherwise.
nonisolated struct ContentLanguage: Sendable {
    let locale: Locale

    static let english = ContentLanguage(locale: Locale(identifier: "en_US"))

    /// Uses the language selected on the device rather than `Locale.current`, which only
    /// reflects the languages the app's UI is localized into.
    static func current(model: SystemLanguageModel = .default) -> ContentLanguage {
        guard let identifier = Locale.preferredLanguages.first else { return .english }
        let locale = Locale(identifier: identifier)
        return model.supportsLocale(locale) ? ContentLanguage(locale: locale) : .english
    }

    /// The language's name in English, e.g. "Spanish (Mexico)", for use in prompts.
    var name: String {
        Locale(identifier: "en").localizedString(forIdentifier: locale.identifier) ?? "English"
    }
}
