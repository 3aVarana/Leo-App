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

    /// The language's name in English, e.g. "Spanish", for use in prompts. Leaves out the region:
    /// with "English (Bolivia)" the model writes about Bolivia instead of the reader's topic.
    /// Keeps a non-default script, e.g. "Chinese, Traditional".
    var name: String {
        guard let code = locale.language.languageCode else { return "English" }
        var identifier = code.identifier
        if let script = locale.language.script, script != Locale.Language(languageCode: code).script {
            identifier += "-\(script.identifier)"
        }
        return Locale(identifier: "en").localizedString(forIdentifier: identifier) ?? "English"
    }

    /// Apple's locale phrase for readers outside US English, empty for en_US. It comes from the
    /// model's training and reduces multilingual hallucination, so it goes first in instructions.
    var localeInstruction: String {
        locale.language.isEquivalent(to: Locale.Language(identifier: "en_US"))
            ? ""
            : "The person's locale is \(locale.identifier)."
    }

    /// `instructions` with `localeInstruction` as its first line, when there is one.
    func withLocaleInstruction(_ instructions: String) -> String {
        localeInstruction.isEmpty ? instructions : localeInstruction + "\n" + instructions
    }
}
