import Foundation

/// Why model output was not turned into an exercise. Logged, so on-device logs show which rule fired.
nonisolated enum ExerciseRejection: String, Error {
    case emptyField
    case distractors
    case passageLength
    case selfReference
    case standoutAnswer
}

/// The repairs and checks applied to model output, as pure functions so they can be tested
/// without the model. Rules: docs/Leo-Exercise-Quality-Plan.md, section 2.4.
nonisolated enum ExerciseRepair {
    // MARK: Repairs

    /// Removes a title the model put at the start of the passage: a `#` heading, a bold phrase on
    /// its own line or before a new sentence, a "Title:" line, or a short first line without
    /// sentence punctuation or commas. The title is generated last, as its own field, so the
    /// model sometimes writes one into the passage too. Bold words that start a sentence, as in
    /// "**Volcanoes** are mountains", are left for `removingMarkdown`.
    static func removingLeadingTitle(_ passage: String) -> String {
        let range = NSRange(passage.startIndex..., in: passage)
        guard let match = leadingTitlePattern.firstMatch(in: passage, range: range),
              let matched = Range(match.range, in: passage)
        else { return passage }
        return String(passage[matched.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let leadingTitlePattern: NSRegularExpression = {
        let titles = [
            #"#+[^\n]*\n"#,
            #"\*\*[^*\n.!?]+\*\*[ \t]*(?:\n|(?=\p{Lu}))"#,
            #"(?i:title|t[ií]tulo)[ \t]*:[^\n]*\n"#,
            #"[^\n.!?。！？:,，]{1,60}\n"#,
        ]
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: #"^\s*(?:"# + titles.joined(separator: "|") + ")")
    }()

    /// Joins lines the model broke after every sentence, which the reader would see as a list.
    /// Blank lines between paragraphs are kept, as one blank line.
    static func joiningLines(_ passage: String) -> String {
        let range = NSRange(passage.startIndex..., in: passage)
        let marked = paragraphBreak.stringByReplacingMatches(in: passage, range: range, withTemplate: "\u{2029}")
        let joined = lineBreak.stringByReplacingMatches(
            in: marked, range: NSRange(marked.startIndex..., in: marked), withTemplate: " ",
        )
        return joined.replacingOccurrences(of: "\u{2029}", with: "\n\n")
    }

    // swiftlint:disable force_try
    private static let paragraphBreak = try! NSRegularExpression(pattern: #"[ \t]*\n(?:[ \t]*\n)+[ \t]*"#)
    private static let lineBreak = try! NSRegularExpression(pattern: #"[ \t]*\n[ \t]*"#)
    // swiftlint:enable force_try

    /// Removes markdown the model sometimes adds: `*` and `_` used for emphasis, `#` headings and
    /// backticks. An asterisk or underscore with letters or digits on both sides, as in "2*3" or
    /// "snake_case", is left alone.
    static func removingMarkdown(_ text: String) -> String {
        var text = text
        for (pattern, template) in markdownPatterns {
            text = pattern.stringByReplacingMatches(
                in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template,
            )
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let markdownPatterns: [(NSRegularExpression, String)] = [
        (#"(?m)^[ \t]*#+[ \t]*"#, ""),
        (#"`+"#, ""),
        (#"(?<![\p{L}\p{N}])\*+|\*+(?![\p{L}\p{N}])"#, ""),
        (#"(?<![\p{L}\p{N}])_+(?=\S)|(?<=\S)_+(?![\p{L}\p{N}])"#, ""),
        (#"(?m)^[ \t]+"#, ""),
        (#"[ \t]{2,}"#, " "),
    ].map { pattern, template in
        // swiftlint:disable:next force_try
        (try! NSRegularExpression(pattern: pattern), template)
    }

    /// Gives all four answers the same ending, so the correct one doesn't stand out by its
    /// punctuation: if at least half end in terminal punctuation, a period is added to the others;
    /// otherwise the final period is removed from all of them.
    static func matchingPunctuation(_ answers: [String]) -> [String] {
        let terminated = answers.filter(endsSentence)
        guard terminated.count * 2 >= answers.count else {
            return answers.map { answer in
                guard let last = answer.last, periods.contains(last) else { return answer }
                return String(answer.dropLast()).trimmingCharacters(in: .whitespaces)
            }
        }
        // Japanese and Chinese answers get their own full stop.
        let period = terminated.compactMap(\.last).first(where: periods.contains) ?? "."
        return answers.map { endsSentence($0) ? $0 : $0 + String(period) }
    }

    /// An explanation cut off by the response token limit doesn't end a sentence. The framework
    /// doesn't report the cut-off, so it is detected here and the explanation dropped; the reader
    /// sees no explanation rather than half of one.
    static func completeExplanation(_ explanation: String) -> String {
        explanation.isEmpty || endsSentence(explanation) ? explanation : ""
    }

    private static let periods: Set<Character> = [".", "。", "．"]
    private static let terminalPunctuation: Set<Character> = [".", "!", "?", "…", "。", "！", "？", "．"]
    private static let closingQuotes: Set<Character> = ["\"", "'", "”", "’", "»", "」", "』"]

    /// Ends in terminal punctuation, possibly followed by closing quotes. A closing quote alone
    /// counts too, since quoted speech often ends the sentence inside the quote in some languages.
    private static func endsSentence(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return terminalPunctuation.contains(last) || closingQuotes.contains(last)
    }

    // MARK: Checks

    /// Whether the passage talks about itself ("the author wanted to show..."), in the languages
    /// with a phrase list. Case-insensitive, whole words only. Other languages always pass.
    static func refersToItself(_ passage: String, language: ContentLanguage) -> Bool {
        guard let code = language.locale.language.languageCode?.identifier,
              let pattern = selfReferencePatterns[code]
        else { return false }
        return pattern.firstMatch(in: passage, range: NSRange(passage.startIndex..., in: passage)) != nil
    }

    private static let selfReferencePatterns: [String: NSRegularExpression] = [
        "en": ["the author", "the writer", "the passage", "the text", "the main idea", "this shows", "this passage"],
        "es": ["el autor", "la autora", "el texto", "el pasaje", "la idea principal"],
        "pt": ["o autor", "a autora", "o texto", "a passagem", "a ideia principal"],
    ].mapValues { phrases in
        let alternatives = phrases.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(
            pattern: #"(?<![\p{L}\p{N}])(?:"# + alternatives + #")(?![\p{L}\p{N}])"#,
            options: .caseInsensitive,
        )
    }

    /// Whether the correct answer is visibly longer than every distractor: more than one and a
    /// half times the longest one, and at least 3 words longer, so short answers aren't rejected
    /// by the ratio alone.
    static func correctAnswerStandsOut(_ correct: String, distractors: [String]) -> Bool {
        let correctWords = correct.wordCount
        let longest = distractors.map(\.wordCount).max() ?? 0
        return correctWords * 2 > longest * 3 && correctWords >= longest + 3
    }
}
