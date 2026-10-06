import Foundation
import FoundationModels

/// The raw structure the on-device model fills in.
/// The correct answer is generated separately from the distractors so the app,
/// not the model, decides where it lands among the options.
@Generable
nonisolated struct GeneratedExercise {
    @Guide(description: "A short, engaging title for the text, at most 6 words")
    var title: String

    @Guide(
        description: "An original, self-contained reading passage, with the length and reading level requested in the instructions",
    )
    var passage: String

    @Guide(description: "One question about the passage that can only be answered by understanding it")
    var question: String

    @Guide(description: "The single correct answer to the question, clearly supported by the passage, at most 15 words")
    var correctAnswer: String

    @Guide(
        description: "Plausible but clearly incorrect answers, each different from the correct answer and from each other, about as long as the correct answer",
        .count(2 ... 3),
    )
    var incorrectAnswers: [String]

    @Guide(
        description: "One or two short sentences explaining why the correct answer is right, pointing to what the passage says",
    )
    var explanation: String
}

nonisolated extension Exercise {
    /// Validates and normalizes model output. Returns `nil` when the content is unusable.
    init?(generated: GeneratedExercise, topic: String, skill: ComprehensionSkill, acceptedWordCount: ClosedRange<Int>) {
        func clean(_ text: String) -> String {
            text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let correct = clean(generated.correctAnswer)
        var seen: Set<String> = [correct.lowercased()]
        let distractors = generated.incorrectAnswers
            .map(clean)
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }

        let passage = clean(generated.passage)
        let question = clean(generated.question)
        guard !correct.isEmpty, (2 ... 3).contains(distractors.count),
              acceptedWordCount.contains(passage.wordCount), !question.isEmpty
        else { return nil }

        let options = (distractors + [correct]).shuffled()
        self.init(
            topic: topic,
            skill: skill,
            title: clean(generated.title),
            passage: passage,
            question: question,
            options: options,
            correctIndex: options.firstIndex(of: correct)!,
            explanation: clean(generated.explanation),
        )
    }
}
