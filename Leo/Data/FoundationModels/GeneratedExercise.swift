import Foundation
import FoundationModels

/// The raw structure the on-device model fills in.
/// The correct answer is generated separately from the distractors so the app,
/// not the model, decides where it lands among the options.
/// Properties are generated in declaration order: the passage first, so nothing written about it
/// steers it, and the title last, so it sums up the passage.
@Generable
nonisolated struct GeneratedExercise {
    @Guide(
        description: "The reading passage: a story or an informative text, written exactly as it would appear in a book. Plain text, no headings, no markdown, no commentary about the text itself",
    )
    var passage: String

    @Guide(
        description: "One question that tests the skill requested in the prompt and can only be answered by someone who understood the passage",
    )
    var question: String

    @Guide(
        description: "The correct answer: a short phrase or sentence, at most 12 words, in your own words rather than copied from the passage",
    )
    var correctAnswer: String

    @Guide(
        description: "Three wrong answers that a careless reader might pick: each about the topic, the same length, grammatical form and punctuation as the correct answer, and clearly wrong according to the passage",
        .count(3),
    )
    var incorrectAnswers: [String]

    @Guide(
        description: "One or two short sentences explaining why the correct answer is right, pointing to what the passage says",
    )
    var explanation: String

    @Guide(description: "A short, engaging title for the passage, at most 6 words")
    var title: String
}

nonisolated extension Exercise {
    /// Repairs and validates model output, in the order of docs/Leo-Exercise-Quality-Plan.md,
    /// section 2.4. Throws the rule that made the content unusable.
    init(
        generated: GeneratedExercise,
        topic: RoundTopic,
        skill: ComprehensionSkill,
        acceptedWordCount: ClosedRange<Int>,
        language: ContentLanguage,
    ) throws(ExerciseRejection) {
        func clean(_ text: String) -> String {
            ExerciseRepair.removingMarkdown(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        /// Answers that differ only in case or a final period are duplicates.
        func key(_ answer: String) -> String {
            answer.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".。"))
        }

        let correct = clean(generated.correctAnswer)
        var seen: Set<String> = [key(correct)]
        let distractors = generated.incorrectAnswers
            .map(clean)
            .filter { !$0.isEmpty && seen.insert(key($0)).inserted }

        let passage = clean(ExerciseRepair.removingLeadingTitle(generated.passage))
        let question = clean(generated.question)
        guard !correct.isEmpty, !question.isEmpty else { throw .emptyField }
        guard distractors.count == 3 else { throw .distractors }
        guard acceptedWordCount.contains(passage.wordCount) else { throw .passageLength }
        guard !ExerciseRepair.refersToItself(passage, language: language) else { throw .selfReference }
        guard !ExerciseRepair.correctAnswerStandsOut(correct, distractors: distractors) else {
            throw .standoutAnswer
        }

        // The correct answer goes first, then the app shuffles all four.
        let answers = ExerciseRepair.matchingPunctuation([correct] + distractors)
        let order = answers.indices.shuffled()
        self.init(
            topic: topic,
            skill: skill,
            title: clean(generated.title),
            passage: passage,
            question: question,
            options: order.map { answers[$0] },
            correctIndex: order.firstIndex(of: 0)!,
            explanation: ExerciseRepair.completeExplanation(clean(generated.explanation)),
        )
    }
}
