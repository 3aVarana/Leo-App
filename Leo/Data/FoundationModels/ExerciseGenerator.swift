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

    /// Apple's prompting guide: a role, MUST for the rules the model keeps breaking, and nothing
    /// that only applies to some skills (those go in `ComprehensionSkill.promptHint`).
    var instructions: String {
        """
        You are an expert reading teacher who writes reading comprehension exercises for \(ageGroup.promptAudience).
        You MUST write the passage, title, question, answers and explanation in \(language.name).
        The passage is a story or an informative text \(wordRange). \(ageGroup.styleGuidance)
        Write it as it would appear in a book for these readers: original, accurate, and about the topic only. \
        It must never talk about itself: no "the author", "the passage", "the text", "the main idea", "this shows", \
        and no lesson spelled out at the end. Stories have a character who wants something, a problem and an ending. \
        Informative texts explain real, well-known facts. Plain text only, with no markdown, asterisks or headings.
        Then write one question that tests the skill the prompt asks for, one correct answer and three wrong answers. \
        Only the correct answer is supported by the passage; each wrong answer is believable but wrong according to \
        the passage. All four answers MUST have the same length, form and punctuation, so the correct one does not \
        stand out. Do not reuse the question's wording in the correct answer only. Never give away the answer in the \
        question.
        """
    }

    /// The word range is repeated from the instructions on purpose: the model keeps to it better.
    func prompt(topic: String, skill: ComprehensionSkill) -> String {
        """
        Write a reading comprehension exercise in \(language.name) about \(topic).
        The passage must be \(wordRange).
        Skill to test: \(skill.promptHint)
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
    /// or produces unusable content is replaced by the next one. `onAttempt` is called
    /// before each topic is tried, so the reader sees the one being written.
    func generate(
        topics: [RoundTopic],
        skill: ComprehensionSkill,
        onAttempt: (RoundTopic) -> Void = { _ in },
    ) async throws -> Exercise {
        for topic in topics.prefix(Self.maxAttempts) {
            try Task.checkCancellation()
            onAttempt(topic)
            let prompt = prompt(topic: topic.prompt, skill: skill)
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
                logger.error("Invalid content for topic '\(topic.prompt)'")
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logger.error("Generation failed for topic '\(topic.prompt)': \(error)")
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
