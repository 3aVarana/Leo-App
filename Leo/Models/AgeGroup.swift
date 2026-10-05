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

    /// Who the texts are written for, for use in English prompts.
    var promptAudience: String {
        switch self {
        case .six: "children aged 6 to 8"
        case .nine: "children aged 9 to 11"
        case .twelve: "readers aged 12 to 14"
        case .fifteen: "students aged 15 to 17"
        case .adult: "adult readers"
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

    /// How many sentences to ask for alongside the word range, if any. With short, simple sentences
    /// the model stops well under the word range unless it's also given a sentence count. Older
    /// groups reach the range without one, and asking them for sentences makes passages run on.
    var passageSentenceRange: ClosedRange<Int>? {
        switch self {
        case .six, .nine, .twelve: 10 ... 13
        case .fifteen, .adult: nil
        }
    }

    /// The passage lengths accepted from the model: wider than the requested range, since the
    /// model doesn't count words precisely, but excluding passages it never finished or that ran on.
    var acceptedWordCount: ClosedRange<Int> {
        passageWordRange.lowerBound * 6 / 10 ... passageWordRange.upperBound * 3 / 2
    }

    /// How the passages and questions should read, for use in English prompts.
    var styleGuidance: String {
        switch self {
        case .six:
            "Use short sentences and familiar, everyday words, with a warm and friendly tone. Keep the question and every answer simple and concrete."
        case .nine:
            "Use simple sentences and everyday vocabulary, and focus on concrete ideas."
        case .twelve:
            "Write clear paragraphs that may introduce a few new words, explained by context. Questions may ask for light inference."
        case .fifteen:
            "Write engaging, age-appropriate texts with clear structure and moderately rich vocabulary."
        case .adult:
            "Use varied sentence structure and precise vocabulary. Questions may require careful reading and an understanding of nuance."
        }
    }
}
