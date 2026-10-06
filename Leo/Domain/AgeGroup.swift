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
}
