import Foundation
import OSLog
import SwiftData

/// Saves and loads finished rounds. Errors from `save` and `delete` are logged by the caller;
/// the reader never sees an error for history.
protocol RoundHistoryRepository {
    func save(_ round: RoundRecord) throws
    /// Rounds read at `ageGroup`, newest first.
    func summaries(for ageGroup: AgeGroup) throws -> [RoundSummary]
    /// `nil` when it was deleted or can't be read.
    func round(id: UUID) throws -> RoundRecord?
    func delete(id: UUID) throws
}

/// Keeps finished rounds in a local SwiftData store, on a `ModelContainer`'s `mainContext`.
final class SwiftDataRoundHistoryRepository: RoundHistoryRepository {
    private static let logger = Logger(subsystem: "Leo", category: "RoundHistoryRepository")

    private let container: ModelContainer

    private var context: ModelContext {
        container.mainContext
    }

    init(container: ModelContainer) {
        self.container = container
    }

    /// The on-disk store, named `RoundHistory.store` in Application Support, local only (no
    /// CloudKit). If it can't be created (full disk, damaged store), falls back to an in-memory
    /// container, so the app still runs; history just isn't kept that launch.
    static func live() -> SwiftDataRoundHistoryRepository {
        let url = URL.applicationSupportDirectory.appending(path: "RoundHistory.store")
        let configuration = ModelConfiguration(
            "RoundHistory",
            schema: Schema(versionedSchema: RoundHistorySchemaV1.self),
            url: url,
        )
        do {
            return try SwiftDataRoundHistoryRepository(container: makeContainer(configurations: [configuration]))
        } catch {
            logger.error("Couldn't open the round history store, keeping history in memory this launch: \(error)")
            return inMemory()
        }
    }

    /// For tests and previews.
    static func inMemory() -> SwiftDataRoundHistoryRepository {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // An in-memory container only fails to build for a programmer error in the schema.
        // swiftlint:disable:next force_try
        return SwiftDataRoundHistoryRepository(container: try! makeContainer(configurations: [configuration]))
    }

    /// Builds the container for `configurations`. Internal so tests can reopen an on-disk store.
    static func makeContainer(configurations: [ModelConfiguration]) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: RoundHistorySchemaV1.self),
            migrationPlan: RoundHistoryMigrationPlan.self,
            configurations: configurations,
        )
    }

    func save(_ round: RoundRecord) throws {
        context.insert(StoredRound(round))
        try context.save()
    }

    /// Doesn't touch `answers`, so the History list never faults in six passages per row: the
    /// score and dots come from `results`, saved alongside it from the same answers.
    func summaries(for ageGroup: AgeGroup) throws -> [RoundSummary] {
        let raw = ageGroup.rawValue
        let descriptor = FetchDescriptor<StoredRound>(
            predicate: #Predicate { $0.ageGroup == raw },
            sortBy: [SortDescriptor(\.finishedAt, order: .reverse)],
        )
        return try context.fetch(descriptor).map {
            RoundSummary(id: $0.id, finishedAt: $0.finishedAt, results: $0.results)
        }
    }

    func round(id: UUID) throws -> RoundRecord? {
        let descriptor = FetchDescriptor<StoredRound>(predicate: #Predicate { $0.id == id })
        guard let stored = try context.fetch(descriptor).first else { return nil }
        guard let record = RoundRecord(stored) else {
            Self.logger.error("Round \(id) has unreadable data, skipping it")
            return nil
        }
        return record
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<StoredRound>(predicate: #Predicate { $0.id == id })
        guard let stored = try context.fetch(descriptor).first else { return }
        context.delete(stored)
        try context.save()
    }
}

// MARK: - Mapping

private extension StoredRound {
    convenience init(_ round: RoundRecord) {
        self.init(
            id: round.id,
            finishedAt: round.finishedAt,
            ageGroup: round.ageGroup.rawValue,
            results: round.answers.map(\.isCorrect),
            answers: round.answers.map(StoredAnswer.init),
        )
    }
}

private extension StoredAnswer {
    convenience init(_ answer: RoundAnswer) {
        self.init(
            index: answer.index,
            exerciseID: answer.exercise.id,
            topicPrompt: answer.exercise.topic.prompt,
            topicName: answer.exercise.topic.name,
            topicKind: answer.exercise.topic.kind.rawValue,
            skill: answer.exercise.skill.rawValue,
            title: answer.exercise.title,
            passage: answer.exercise.passage,
            question: answer.exercise.question,
            options: answer.exercise.options,
            correctIndex: answer.exercise.correctIndex,
            selectedOption: answer.selectedOption,
            explanation: answer.exercise.explanation,
        )
    }
}

private extension RoundRecord {
    /// `nil` when `stored` has become unreadable: an out-of-range `correctIndex` or
    /// `selectedOption`, or an unknown raw value.
    init?(_ stored: StoredRound) {
        guard let ageGroup = AgeGroup(rawValue: stored.ageGroup) else { return nil }
        let sorted = stored.answers.sorted { $0.index < $1.index }
        let answers = sorted.compactMap(RoundAnswer.init)
        guard answers.count == sorted.count else { return nil }
        self.init(id: stored.id, finishedAt: stored.finishedAt, ageGroup: ageGroup, answers: answers)
    }
}

private extension RoundAnswer {
    init?(_ stored: StoredAnswer) {
        guard
            let kind = TopicKind(rawValue: stored.topicKind),
            let skill = ComprehensionSkill(rawValue: stored.skill),
            stored.options.indices.contains(stored.correctIndex),
            stored.options.indices.contains(stored.selectedOption)
        else { return nil }
        let exercise = Exercise(
            id: stored.exerciseID,
            topic: RoundTopic(prompt: stored.topicPrompt, name: stored.topicName, kind: kind),
            skill: skill,
            title: stored.title,
            passage: stored.passage,
            question: stored.question,
            options: stored.options,
            correctIndex: stored.correctIndex,
            explanation: stored.explanation,
        )
        self.init(index: stored.index, exercise: exercise, selectedOption: stored.selectedOption)
    }
}
