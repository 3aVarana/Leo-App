import Foundation

/// A finished round, saved once the reader reaches Results. A round left unfinished is never
/// reported.
nonisolated struct RoundRecord: Identifiable, Sendable {
    let id: UUID
    let finishedAt: Date
    let ageGroup: AgeGroup
    /// In round order, `index` 0...5.
    let answers: [RoundAnswer]

    var correctCount: Int {
        answers.count(where: \.isCorrect)
    }

    var misses: [RoundAnswer] {
        answers.filter { !$0.isCorrect }
    }
}
