import Foundation
@testable import Leo

/// An in-memory `RoundHistoryRepository` that records every save and delete. Set `errorToThrow`
/// to make every call fail instead.
@MainActor
final class RoundHistoryRepositorySpy: RoundHistoryRepository {
    private(set) var saved: [RoundRecord] = []
    private(set) var deleted: [UUID] = []
    private var rounds: [UUID: RoundRecord] = [:]
    var errorToThrow: (any Error)?

    func save(_ round: RoundRecord) throws {
        if let errorToThrow {
            throw errorToThrow
        }
        saved.append(round)
        rounds[round.id] = round
    }

    func summaries(for ageGroup: AgeGroup) throws -> [RoundSummary] {
        if let errorToThrow {
            throw errorToThrow
        }
        return rounds.values
            .filter { $0.ageGroup == ageGroup }
            .sorted { $0.finishedAt > $1.finishedAt }
            .map { RoundSummary(id: $0.id, finishedAt: $0.finishedAt, results: $0.answers.map(\.isCorrect)) }
    }

    func round(id: UUID) throws -> RoundRecord? {
        if let errorToThrow {
            throw errorToThrow
        }
        return rounds[id]
    }

    func delete(id: UUID) throws {
        if let errorToThrow {
            throw errorToThrow
        }
        deleted.append(id)
        rounds[id] = nil
    }
}
