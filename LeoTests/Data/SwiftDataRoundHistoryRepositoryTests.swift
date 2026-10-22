import Foundation
@testable import Leo
import SwiftData
import Testing

@MainActor
struct SwiftDataRoundHistoryRepositoryTests {
    @Test func saveThenRoundRestoresEveryField() throws {
        let repository = SwiftDataRoundHistoryRepository.inMemory()
        let round = RoundRecord.fixture(ageGroup: .nine, results: [true, false, true, true, false, true])
        try repository.save(round)

        let restored = try #require(try repository.round(id: round.id))
        #expect(restored.id == round.id)
        #expect(restored.finishedAt == round.finishedAt)
        #expect(restored.ageGroup == round.ageGroup)
        #expect(restored.answers.map(\.index) == round.answers.map(\.index))
        #expect(restored.answers.map(\.selectedOption) == round.answers.map(\.selectedOption))
        #expect(restored.answers.map(\.exercise.id) == round.answers.map(\.exercise.id))
        #expect(restored.answers.map(\.exercise.topic) == round.answers.map(\.exercise.topic))
        #expect(restored.answers.map(\.exercise.skill) == round.answers.map(\.exercise.skill))
        #expect(restored.answers.map(\.exercise.title) == round.answers.map(\.exercise.title))
        #expect(restored.answers.map(\.exercise.passage) == round.answers.map(\.exercise.passage))
        #expect(restored.answers.map(\.exercise.question) == round.answers.map(\.exercise.question))
        #expect(restored.answers.map(\.exercise.options) == round.answers.map(\.exercise.options))
        #expect(restored.answers.map(\.exercise.correctIndex) == round.answers.map(\.exercise.correctIndex))
        #expect(restored.answers.map(\.exercise.explanation) == round.answers.map(\.exercise.explanation))
    }

    @Test func summariesAreNewestFirstAndPerAgeGroup() throws {
        let repository = SwiftDataRoundHistoryRepository.inMemory()
        let old = RoundRecord.fixture(ageGroup: .nine, finishedAt: Date(timeIntervalSinceReferenceDate: 0))
        let new = RoundRecord.fixture(ageGroup: .nine, finishedAt: Date(timeIntervalSinceReferenceDate: 1000))
        let other = RoundRecord.fixture(ageGroup: .twelve, finishedAt: Date(timeIntervalSinceReferenceDate: 500))
        try repository.save(old)
        try repository.save(new)
        try repository.save(other)

        #expect(try repository.summaries(for: .nine).map(\.id) == [new.id, old.id])
        #expect(try repository.summaries(for: .twelve).map(\.id) == [other.id])
    }

    @Test func summaryResultsMatchAnswers() throws {
        let repository = SwiftDataRoundHistoryRepository.inMemory()
        let round = RoundRecord.fixture(results: [true, false, true, true, false, true])
        try repository.save(round)

        let summary = try #require(repository.summaries(for: round.ageGroup).first)
        #expect(summary.id == round.id)
        #expect(summary.results == [true, false, true, true, false, true])
        #expect(summary.correctCount == 4)
    }

    @Test func deleteRemovesTheRoundAndItsAnswers() throws {
        let container = try SwiftDataRoundHistoryRepository.makeContainer(
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)],
        )
        let repository = SwiftDataRoundHistoryRepository(container: container)
        let round = RoundRecord.fixture()
        try repository.save(round)

        try repository.delete(id: round.id)

        #expect(try repository.round(id: round.id) == nil)
        #expect(try container.mainContext.fetch(FetchDescriptor<StoredAnswer>()).isEmpty)
    }

    /// Deleting a round that was never saved does nothing.
    @Test func deletingAnUnknownRoundDoesNothing() throws {
        let repository = SwiftDataRoundHistoryRepository.inMemory()
        #expect(throws: Never.self) { try repository.delete(id: UUID()) }
    }

    @Test func unreadableRoundIsSkipped() throws {
        let container = try SwiftDataRoundHistoryRepository.makeContainer(
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)],
        )
        let repository = SwiftDataRoundHistoryRepository(container: container)
        let context = container.mainContext

        let answer = StoredAnswer(
            index: 0,
            exerciseID: UUID(),
            topicPrompt: "owls",
            topicName: "Owls",
            topicKind: TopicKind.informative.rawValue,
            skill: "not-a-real-skill",
            title: "Owls",
            passage: "Owls are nocturnal birds.",
            question: "What are owls?",
            options: ["Birds", "Fish"],
            correctIndex: 0,
            selectedOption: 9,
            explanation: "",
        )
        let round = StoredRound(
            id: UUID(), finishedAt: Date(), ageGroup: AgeGroup.nine.rawValue, results: [true], answers: [answer],
        )
        context.insert(round)
        try context.save()

        #expect(try repository.round(id: round.id) == nil)
    }

    @Test func roundsSurviveANewContainer() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "RoundHistory.store")
        let round = RoundRecord.fixture()

        do {
            let container = try SwiftDataRoundHistoryRepository.makeContainer(
                configurations: [onDiskConfiguration(url)],
            )
            try SwiftDataRoundHistoryRepository(container: container).save(round)
        }

        let reopened = try SwiftDataRoundHistoryRepository.makeContainer(
            configurations: [onDiskConfiguration(url)],
        )
        let restored = try SwiftDataRoundHistoryRepository(container: reopened).round(id: round.id)
        #expect(restored?.id == round.id)
        #expect(restored?.answers.count == round.answers.count)
    }

    private func onDiskConfiguration(_ url: URL) -> ModelConfiguration {
        ModelConfiguration(schema: Schema(versionedSchema: RoundHistorySchemaV1.self), url: url)
    }
}
