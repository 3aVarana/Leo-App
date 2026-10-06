import Foundation
import FoundationModels
import OSLog

/// Generates reading comprehension exercises with the on-device model.
/// `FoundationModelsExerciseRepository` wraps it for the rest of the app.
struct ExerciseGenerator {
    let language: ContentLanguage
    let ageGroup: AgeGroup

    var wordRange: String {
        let range = ageGroup.passageWordRange
        let midpoint = (range.lowerBound + range.upperBound) / 2
        let words = "between \(range.lowerBound) and \(range.upperBound) words long, about \(midpoint) words"
        guard let sentences = ageGroup.passageSentenceRange else { return words }
        return "\(words) in \(sentences.lowerBound) to \(sentences.upperBound) sentences"
    }

    var instructions: String {
        """
        You create reading comprehension exercises for \(ageGroup.promptAudience).
        The passage must be \(wordRange). \(ageGroup.styleGuidance)
        Write original, accurate, age-appropriate texts in clear \(language.name).
        Write the title, passage, question, every answer and the explanation in \(language.name), \
        even though these instructions are in English.
        Each exercise has a passage, one question, one correct answer and plausible incorrect answers.
        The correct answer must be supported by the passage. Incorrect answers must be wrong \
        according to the passage, but believable to someone who read carelessly.
        Never mention the answer in the question.
        The passage must not state the answer word for word; the reader should have to understand it.
        Write every answer as a direct, natural option without phrases like "The main idea is".
        All answers must have a similar length and style, so the correct one doesn't stand out.
        """
    }

    func prompt(topic: String, skill: ComprehensionSkill) -> String {
        """
        Create a reading comprehension exercise in \(language.name) about \(topic).
        The passage must be \(wordRange).
        \(skill.promptHint)
        """
    }

    private static let maxAttempts = 3

    /// A complete exercise takes well under 800 tokens even for long passages in wordier languages.
    /// Sometimes the model never stops writing; without a cap it runs until the context window
    /// is full, which takes minutes, before the next topic is tried.
    private static let maxResponseTokens = 1200

    /// The model kept writing the passage past the accepted length.
    private struct RunawayPassage: Error {}

    private let logger = Logger(subsystem: "Leo", category: "ExerciseGenerator")

    /// Tries each topic in order, so a topic that trips the model's guardrails
    /// or produces unusable content is replaced by the next one.
    func generate(topics: [String], skill: ComprehensionSkill) async throws -> Exercise {
        for topic in topics.prefix(Self.maxAttempts) {
            try Task.checkCancellation()
            let prompt = prompt(topic: topic, skill: skill)
            // A fresh session per exercise keeps each request well inside the context window.
            let session = LanguageModelSession(instructions: instructions)
            do {
                let generated = try await respond(to: prompt, in: session)
                if let exercise = Exercise(
                    generated: generated,
                    topic: topic,
                    skill: skill,
                    acceptedWordCount: ageGroup.acceptedWordCount,
                ) {
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

    /// Streams the response so a passage that never ends is abandoned as soon as it runs past
    /// the accepted length, after seconds rather than when the token cap is reached.
    private func respond(to prompt: String, in session: LanguageModelSession) async throws -> GeneratedExercise {
        let stream = session.streamResponse(
            to: prompt,
            generating: GeneratedExercise.self,
            options: GenerationOptions(temperature: 0.8, maximumResponseTokens: Self.maxResponseTokens),
        )
        var content: GeneratedContent?
        for try await snapshot in stream {
            if let passage = snapshot.content.passage, passage.wordCount > ageGroup.acceptedWordCount.upperBound {
                throw RunawayPassage()
            }
            content = snapshot.rawContent
        }
        guard let content else { throw ExerciseGenerationError.failed }
        return try GeneratedExercise(content)
    }
}
