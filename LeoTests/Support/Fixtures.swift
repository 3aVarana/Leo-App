import Foundation
@testable import Leo

extension String {
    /// A passage of exactly `n` words.
    static func words(_ n: Int) -> String {
        let vocabulary = ["the", "small", "fox", "ran", "across", "a", "quiet", "green", "field", "today"]
        return (0 ..< n).map { vocabulary[$0 % vocabulary.count] }.joined(separator: " ")
    }
}

extension GeneratedExercise {
    /// Valid model output. The default passage is 60 words, inside `AgeGroup.six.acceptedWordCount`.
    static func fixture(
        title: String = "The Quiet Field",
        passage: String = .words(60),
        question: String = "Where did the fox run?",
        correctAnswer: String = "Across a field",
        incorrectAnswers: [String] = ["Into a cave", "Up a tree", "Under a bridge"],
        explanation: String = "The passage says the fox ran across a quiet green field.",
    ) -> GeneratedExercise {
        GeneratedExercise(
            title: title,
            passage: passage,
            question: question,
            correctAnswer: correctAnswer,
            incorrectAnswers: incorrectAnswers,
            explanation: explanation,
        )
    }
}

extension ReaderPreferences {
    /// Preferences with some suggested topics turned off and custom topics added, per group.
    static func fixture(
        ageGroup: AgeGroup,
        disabled: [AgeGroup: Set<String>] = [:],
        custom: [AgeGroup: [String]] = [:],
    ) -> ReaderPreferences {
        var preferences = ReaderPreferences(ageGroup: ageGroup)
        preferences.disabledDefaultTopics = disabled
        preferences.customTopics = custom.mapValues { $0.map { CustomTopic(name: $0) } }
        return preferences
    }
}

extension PreferencesEditorViewModel {
    /// An editor over `draft` whose reviews go to `reviews` and whose saves go to `onSave`.
    @MainActor
    static func fixture(
        draft: ReaderPreferences,
        reviews: StubTopicReviewRepository = StubTopicReviewRepository(),
        onSave: @escaping (ReaderPreferences) -> Void = { _ in },
    ) -> PreferencesEditorViewModel {
        PreferencesEditorViewModel(draft: draft, topicReviews: reviews, onSave: onSave)
    }
}

extension Exercise {
    /// An exercise with fixed options, built without validation or shuffling.
    static func fixture(
        topic: String = "volcanoes",
        skill: ComprehensionSkill = .detail,
        title: String = "The Sleeping Mountain",
        passage: String = """
        Mount Rainier looks calm, but it is an active volcano. Deep under the snow, hot rock \
        called magma still moves. Scientists place sensors on its slopes to feel tiny shakes in \
        the ground. If the shakes grow stronger, they can warn the towns nearby long before \
        anything happens.
        """,
        question: String = "Why do scientists place sensors on the volcano?",
        options: [String] = [
            "To measure how much snow falls",
            "To feel small shakes that could warn of danger",
            "To find the best path to the top",
            "To keep the magma from moving",
        ],
        correctIndex: Int = 1,
        explanation: String = "The passage says the sensors feel tiny shakes so scientists can warn nearby towns.",
    ) -> Exercise {
        Exercise(
            topic: topic, skill: skill, title: title, passage: passage, question: question,
            options: options, correctIndex: correctIndex, explanation: explanation,
        )
    }
}
