import Foundation

// English prose that goes into the model prompts, kept out of the domain layer.

nonisolated extension AgeGroup {
    /// Who the texts are written for, for use in English prompts.
    var promptAudience: String {
        switch self {
        case .six: "children aged 6 to 8"
        case .nine: "children aged 9 to 11"
        case .twelve: "readers aged 12 to 14"
        case .fifteen: "students aged 15 to 17"
        case .adult: "adult readers"
        }
    }

    /// How many sentences to ask for alongside the word range, if any. With short, simple sentences
    /// the model stops well under the word range unless it's also given a sentence count. Older
    /// groups reach the range without one, and asking them for sentences makes passages run on.
    var passageSentenceRange: ClosedRange<Int>? {
        switch self {
        case .six, .nine, .twelve: 10 ... 13
        case .fifteen, .adult: nil
        }
    }

    /// How the passages and questions should read, for use in English prompts.
    var styleGuidance: String {
        switch self {
        case .six:
            """
            Use short sentences and familiar, everyday words, with a warm and friendly tone. \
            Keep the question and every answer simple and concrete.
            """
        case .nine:
            "Use simple sentences and everyday vocabulary, and focus on concrete ideas."
        case .twelve:
            """
            Write clear paragraphs that may introduce a few new words, explained by context. \
            Questions may ask for light inference.
            """
        case .fifteen:
            "Write engaging, age-appropriate texts with clear structure and moderately rich vocabulary."
        case .adult:
            """
            Use varied sentence structure and precise vocabulary. \
            Questions may require careful reading and an understanding of nuance.
            """
        }
    }
}

nonisolated extension ComprehensionSkill {
    /// Three parts: what the question asks, what the passage must do so the skill can be tested,
    /// and what the wrong answers are. The model reads this before it writes the passage.
    var promptHint: String {
        switch self {
        case .mainIdea:
            """
            The question asks what the passage is mostly about, or what its central message is. \
            The passage must not state its own main idea or moral in a sentence; the reader works it out \
            from the whole text. The wrong answers are details from the passage that are true but too narrow, \
            or ideas the passage never supports.
            """
        case .detail:
            """
            The question asks about one specific, important fact or event in the passage. \
            State that fact plainly in the passage. The question and the correct answer must rephrase it \
            in different words. The wrong answers are other things from the passage, slightly changed \
            so they are false.
            """
        case .inference:
            """
            The question asks about something the passage never says directly but clearly implies: \
            how a character feels, why someone did something, what will probably happen next, \
            or what caused something described. The passage must give the clues but never state the answer. \
            The wrong answers are conclusions the clues do not support.
            """
        case .vocabulary:
            """
            Use one word or expression in the passage that is slightly above the reader's level, in a sentence \
            whose context shows its meaning. Do not define it in the passage, do not mark it in any way, \
            and do not pick the topic word. The question asks what that word means in the passage and repeats \
            the word. The wrong answers are meanings that word could have in other contexts, or meanings that fit \
            the sentence badly.
            """
        case .purpose:
            """
            The question asks why the writer wrote the passage, or why the writer included a specific event, \
            detail or example. A character in a story is never the writer. The passage itself must never mention \
            the writer, the reader, the passage or its purpose; it simply tells or explains. The wrong answers \
            are purposes that sound reasonable but do not match what the passage actually does.
            """
        }
    }
}
