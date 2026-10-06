import Foundation

/// Supplies the exercises of one round. A new one is made for each round, so a change
/// to the device language applies to the next round.
protocol ExerciseRepository {
    func exercise(topics: [String], skill: ComprehensionSkill) async throws -> Exercise
}

enum ExerciseGenerationError: LocalizedError {
    case failed

    var errorDescription: String? {
        String(localized: "We couldn't create this exercise. Please try again.")
    }
}

/// Writes each exercise with the on-device model.
struct FoundationModelsExerciseRepository: ExerciseRepository {
    /// Internal, so tests can check how it was built.
    let generator: ExerciseGenerator

    /// - Parameter language: Picked when the repository is made, once per round.
    init(ageGroup: AgeGroup, language: ContentLanguage = .current()) {
        generator = ExerciseGenerator(language: language, ageGroup: ageGroup)
    }

    func exercise(topics: [String], skill: ComprehensionSkill) async throws -> Exercise {
        try await generator.generate(topics: topics, skill: skill)
    }
}
