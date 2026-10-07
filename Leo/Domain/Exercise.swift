import Foundation

/// A ready-to-present exercise with shuffled options.
nonisolated struct Exercise: Identifiable, Sendable {
    let id = UUID()
    let topic: RoundTopic
    let skill: ComprehensionSkill
    let title: String
    let passage: String
    let question: String
    let options: [String]
    let correctIndex: Int
    /// Why the correct answer is right, shown after an incorrect pick. May be empty.
    let explanation: String

    /// Builds an exercise as given, without validation or shuffling. For tests and previews;
    /// model output goes through `init?(generated:topic:skill:acceptedWordCount:)`.
    init(topic: RoundTopic, skill: ComprehensionSkill, title: String, passage: String,
         question: String, options: [String], correctIndex: Int, explanation: String)
    {
        precondition(options.indices.contains(correctIndex))
        self.topic = topic
        self.skill = skill
        self.title = title
        self.passage = passage
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
    }
}

extension String {
    /// Counts words linguistically, so languages written without spaces (e.g. Japanese) work too.
    nonisolated var wordCount: Int {
        var count = 0
        enumerateSubstrings(in: startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }
}
