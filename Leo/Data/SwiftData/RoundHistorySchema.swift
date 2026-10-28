import Foundation
import SwiftData

/// The on-disk schema for saved rounds, version 1. Versioned so a later change (for example
/// per-skill stats) adds a migration stage instead of starting over.
enum RoundHistorySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [StoredRound.self, StoredAnswer.self]
    }
}

/// A finished round. Default actor isolation in this target is `MainActor`; `@Model` classes are
/// marked `nonisolated` like the Domain types, since SwiftData's `PersistentModel` conformance is
/// itself nonisolated.
@Model
final nonisolated class StoredRound {
    @Attribute(.unique) var id: UUID
    var finishedAt: Date
    /// `AgeGroup.rawValue`.
    var ageGroup: String
    /// Whether each answer was right, in round order. Duplicates what `answers` says, on
    /// purpose: the History list reads this without faulting in up to nine passages per row.
    var results: [Bool]
    @Relationship(deleteRule: .cascade) var answers: [StoredAnswer]

    init(id: UUID, finishedAt: Date, ageGroup: String, results: [Bool], answers: [StoredAnswer]) {
        self.id = id
        self.finishedAt = finishedAt
        self.ageGroup = ageGroup
        self.results = results
        self.answers = answers
    }
}

/// One answer of a finished round: what the reader saw, as they saw it. Nothing here is
/// re-localized later.
@Model
final nonisolated class StoredAnswer {
    /// The exercise's 0-based position in the round. SwiftData relationship arrays aren't
    /// ordered, so answers are sorted by this when read.
    var index: Int
    var exerciseID: UUID
    var topicPrompt: String
    var topicName: String
    /// `TopicKind.rawValue`.
    var topicKind: String
    /// `ComprehensionSkill.rawValue`.
    var skill: String
    var title: String
    var passage: String
    var question: String
    var options: [String]
    var correctIndex: Int
    var selectedOption: Int
    var explanation: String
    var round: StoredRound?

    init(
        index: Int,
        exerciseID: UUID,
        topicPrompt: String,
        topicName: String,
        topicKind: String,
        skill: String,
        title: String,
        passage: String,
        question: String,
        options: [String],
        correctIndex: Int,
        selectedOption: Int,
        explanation: String,
    ) {
        self.index = index
        self.exerciseID = exerciseID
        self.topicPrompt = topicPrompt
        self.topicName = topicName
        self.topicKind = topicKind
        self.skill = skill
        self.title = title
        self.passage = passage
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
        self.selectedOption = selectedOption
        self.explanation = explanation
    }
}

/// One schema so far; a later version adds a migration stage here instead of starting over.
enum RoundHistoryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [RoundHistorySchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
