import Foundation

/// What a History row needs, without the texts.
nonisolated struct RoundSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let finishedAt: Date
    /// Whether each answer was right, in round order. Drives the score and the dots.
    let results: [Bool]

    var correctCount: Int {
        results.count(where: \.self)
    }
}
