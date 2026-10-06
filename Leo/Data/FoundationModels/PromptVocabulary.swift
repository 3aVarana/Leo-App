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
    var promptHint: String {
        switch self {
        case .mainIdea: "Ask about the main idea or central message of the passage."
        case .detail: "Ask about a specific, important detail stated in the passage."
        case .inference: "Ask something that is not stated directly but can be logically inferred from the passage."
        case .vocabulary:
            """
            Ask what a specific word or phrase used in the passage means in that context. \
            Quote the word in the question.
            """
        case .purpose: "Ask why the author wrote the passage or why they included a specific part of it."
        }
    }
}
