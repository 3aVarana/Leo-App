import Foundation
import FoundationModels
import OSLog

enum ExerciseGenerationError: LocalizedError {
    case failed

    var errorDescription: String? {
        "We couldn't create this exercise. Please try again."
    }
}

/// Generates reading comprehension exercises with the on-device model.
struct ExerciseGenerator {
    private static let instructions = """
        You create reading comprehension exercises for students aged 15 to 18.
        Write original, accurate, age-appropriate texts in clear English.
        Each exercise has a passage, one question, one correct answer and plausible incorrect answers.
        The correct answer must be supported by the passage. Incorrect answers must be wrong \
        according to the passage, but believable to someone who read carelessly.
        Never mention the answer in the question.
        The passage must not state the answer word for word; the reader should have to understand it.
        Write every answer as a direct, natural option without phrases like "The main idea is".
        All answers must have a similar length and style, so the correct one doesn't stand out.
        """

    private static let maxAttempts = 3

    private let logger = Logger(subsystem: "Leo", category: "ExerciseGenerator")

    /// Tries each topic in order, so a topic that trips the model's guardrails
    /// or produces unusable content is replaced by the next one.
    func generate(topics: [String], skill: ComprehensionSkill) async throws -> Exercise {
        for topic in topics.prefix(Self.maxAttempts) {
            try Task.checkCancellation()
            let prompt = """
                Create a reading comprehension exercise about \(topic).
                \(skill.promptHint)
                """
            // A fresh session per exercise keeps each request well inside the context window.
            let session = LanguageModelSession(instructions: Self.instructions)
            do {
                let response = try await session.respond(
                    to: prompt,
                    generating: GeneratedExercise.self,
                    options: GenerationOptions(temperature: 0.8)
                )
                if let exercise = Exercise(generated: response.content, topic: topic, skill: skill) {
                    return exercise
                }
                logger.error("Invalid content for topic '\(topic)'")
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logger.error("Generation failed for topic '\(topic)': \(error)")
            }
        }
        throw ExerciseGenerationError.failed
    }
}
