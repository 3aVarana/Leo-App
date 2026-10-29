import Foundation

/// A finished round, saved once the reader reaches Results. A round left unfinished is never
/// reported.
nonisolated struct RoundRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    let finishedAt: Date
    let ageGroup: AgeGroup
    /// In round order, `index` 0 to the round's text count minus 1.
    let answers: [RoundAnswer]

    var correctCount: Int {
        answers.count(where: \.isCorrect)
    }

    var misses: [RoundAnswer] {
        answers.filter { !$0.isCorrect }
    }

    /// Two records are the same round when their `id` matches; `answers` holds no `Hashable`
    /// conformance of its own and doesn't need one just for this.
    static func == (lhs: RoundRecord, rhs: RoundRecord) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
