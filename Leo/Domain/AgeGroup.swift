import Foundation

/// The reader's age group. Controls how long the passages are and how complex their language is.
nonisolated enum AgeGroup: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case six = "6-8"
    case nine = "9-11"
    case twelve = "12-14"
    case fifteen = "15-17"
    case adult = "18+"

    var displayName: String {
        switch self {
        case .six: String(localized: "6 to 8")
        case .nine: String(localized: "9 to 11")
        case .twelve: String(localized: "12 to 14")
        case .fifteen: String(localized: "15 to 17")
        case .adult: String(localized: "18 or older")
        }
    }

    /// The label of a segment in the settings age picker.
    var shortName: String {
        switch self {
        case .six: String(localized: "6–8")
        case .nine: String(localized: "9–11")
        case .twelve: String(localized: "12–14")
        case .fifteen: String(localized: "15–17")
        case .adult: String(localized: "18+")
        }
    }

    /// What the texts are like, for example "Everyday words · 80–120 words". The figures come
    /// from `passageWordRange`, so they always match what the model is asked for.
    var summary: String {
        let lower = passageWordRange.lowerBound
        let upper = passageWordRange.upperBound
        return switch self {
        case .six: String(localized: "Short stories · \(lower)–\(upper) words")
        case .nine: String(localized: "Everyday words · \(lower)–\(upper) words")
        case .twelve: String(localized: "Some new vocabulary · \(lower)–\(upper) words")
        case .fifteen: String(localized: "Richer vocabulary · \(lower)–\(upper) words")
        case .adult: String(localized: "Nuance and inference · \(lower)–\(upper) words")
        }
    }

    var passageWordRange: ClosedRange<Int> {
        switch self {
        case .six: 50 ... 80
        case .nine: 80 ... 120
        case .twelve: 100 ... 150
        case .fifteen: 120 ... 180
        case .adult: 160 ... 230
        }
    }

    /// The passage lengths accepted from the model: wider than the requested range, since the
    /// model doesn't count words precisely, but excluding passages it never finished or that ran on.
    var acceptedWordCount: ClosedRange<Int> {
        passageWordRange.lowerBound * 6 / 10 ... passageWordRange.upperBound * 3 / 2
    }

    /// A slow silent reading pace for this age, in words per minute.
    var readingWordsPerMinute: Int {
        switch self {
        case .six: 60
        case .nine: 100
        case .twelve: 140
        case .fifteen: 170
        case .adult: 200
        }
    }

    static let minimumReadingTime = Duration.seconds(30)

    /// How long the reader gets to read a passage of `wordCount` words: their pace with half as
    /// much again to spare, rounded up to 10 seconds, and never less than `minimumReadingTime`.
    func readingTime(wordCount: Int) -> Duration {
        // 90 seconds per `readingWordsPerMinute` words, in tens of seconds rounded up. Integer
        // math, so an exact multiple of 10 isn't rounded up past itself.
        let tens = (wordCount * 9 + readingWordsPerMinute - 1) / readingWordsPerMinute
        return max(.seconds(tens * 10), Self.minimumReadingTime)
    }
}
