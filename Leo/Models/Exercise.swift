import Foundation
import FoundationModels

/// The raw structure the on-device model fills in.
/// The correct answer is generated separately from the distractors so the app,
/// not the model, decides where it lands among the options.
@Generable
nonisolated struct GeneratedExercise {
    @Guide(description: "A short, engaging title for the text, at most 6 words")
    var title: String

    @Guide(description: "An original, self-contained reading passage of 120 to 180 words, written for students aged 15 to 18")
    var passage: String

    @Guide(description: "One question about the passage that can only be answered by understanding it")
    var question: String

    @Guide(description: "The single correct answer to the question, clearly supported by the passage, at most 15 words")
    var correctAnswer: String

    @Guide(description: "Plausible but clearly incorrect answers, each different from the correct answer and from each other, about as long as the correct answer", .count(2...3))
    var incorrectAnswers: [String]
}

/// A ready-to-present exercise with shuffled options.
nonisolated struct Exercise: Identifiable, Sendable {
    let id = UUID()
    let topic: String
    let skill: ComprehensionSkill
    let title: String
    let passage: String
    let question: String
    let options: [String]
    let correctIndex: Int

    /// Validates and normalizes model output. Returns `nil` when the content is unusable.
    init?(generated: GeneratedExercise, topic: String, skill: ComprehensionSkill) {
        func clean(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

        let correct = clean(generated.correctAnswer)
        var seen: Set<String> = [correct.lowercased()]
        let distractors = generated.incorrectAnswers
            .map(clean)
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }

        let passage = clean(generated.passage)
        let question = clean(generated.question)
        // Counts words linguistically, so languages written without spaces (e.g. Japanese) work too.
        var wordCount = 0
        passage.enumerateSubstrings(in: passage.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            wordCount += 1
        }
        guard !correct.isEmpty, (2...3).contains(distractors.count),
              wordCount >= 60, !question.isEmpty
        else { return nil }

        let options = (distractors + [correct]).shuffled()
        self.topic = topic
        self.skill = skill
        self.title = clean(generated.title)
        self.passage = passage
        self.question = question
        self.options = options
        self.correctIndex = options.firstIndex(of: correct)!
    }
}

/// The comprehension skill each question targets, so a round covers different kinds of understanding.
nonisolated enum ComprehensionSkill: String, CaseIterable, Sendable {
    case mainIdea, detail, inference, vocabulary, purpose

    var displayName: String {
        switch self {
        case .mainIdea: String(localized: "Main idea")
        case .detail: String(localized: "Key detail")
        case .inference: String(localized: "Inference")
        case .vocabulary: String(localized: "Vocabulary in context")
        case .purpose: String(localized: "Author's purpose")
        }
    }

    var promptHint: String {
        switch self {
        case .mainIdea: "Ask about the main idea or central message of the passage."
        case .detail: "Ask about a specific, important detail stated in the passage."
        case .inference: "Ask something that is not stated directly but can be logically inferred from the passage."
        case .vocabulary: "Ask what a specific word or phrase used in the passage means in that context. Quote the word in the question."
        case .purpose: "Ask why the author wrote the passage or why they included a specific part of it."
        }
    }
}
