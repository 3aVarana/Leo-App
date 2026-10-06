/// Checks that a topic the reader typed suits them, and tidies up its wording.
protocol TopicReviewRepository {
    func review(_ text: String, for group: AgeGroup) async throws -> TopicReviewOutcome
}

/// Reviews topics with the on-device model.
struct FoundationModelsTopicReviewRepository: TopicReviewRepository {
    /// Resolves the language on every call, so a change to the device language applies to the next review.
    func review(_ text: String, for group: AgeGroup) async throws -> TopicReviewOutcome {
        try await TopicValidator(language: .current()).review(text, for: group)
    }
}
