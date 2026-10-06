import Foundation
@testable import Leo
import Testing

/// Not tested: `current(model:)`, which depends on the device language and the real model.
@MainActor
struct ContentLanguageTests {
    @Test(arguments: [
        ("en_US", "English"),
        ("es_BO", "Spanish"),
        ("pt_BR", "Portuguese"),
        ("zh-Hans-CN", "Chinese"),
        ("zh-Hant-TW", "Chinese, Traditional"),
        ("zh_TW", "Chinese, Traditional"),
        ("sr-Latn-RS", "Serbian (Latin)"),
        ("sr-Cyrl", "Serbian"),
        ("ja_JP", "Japanese"),
        ("", "English"),
    ])
    func name(_ identifier: String, expected: String) {
        #expect(ContentLanguage(locale: Locale(identifier: identifier)).name == expected)
    }

    /// Locks current behavior.
    @Test func undeterminedLanguage() {
        #expect(ContentLanguage(locale: Locale(identifier: "und")).name == "Unknown language")
    }

    @Test func english() {
        #expect(ContentLanguage.english.locale.identifier == "en_US")
    }
}
