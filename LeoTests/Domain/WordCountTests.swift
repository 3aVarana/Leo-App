@testable import Leo
import Testing

struct WordCountTests {
    @Test(arguments: [
        ("", 0),
        ("Hello world.", 2),
        ("Don't stop, it's 3:45 p.m.", 6),
        ("  a\n\nb  ", 2),
    ])
    func wordCount(_ text: String, expected: Int) {
        #expect(text.wordCount == expected)
    }

    /// Hyphens split words with ICU's word breaking, which may change between OS versions.
    @Test func hyphenatedWords() {
        #expect("e-mail well-known".wordCount >= 2)
    }

    /// Japanese has no spaces between words, so counting spaces would give 1.
    @Test func languagesWithoutSpaces() {
        #expect("猫が好きです。犬も好きです。".wordCount > 1)
    }

    @Test(arguments: [1, 29, 60, 121, 345])
    func wordsFixture(_ n: Int) {
        #expect(String.words(n).wordCount == n)
    }
}
