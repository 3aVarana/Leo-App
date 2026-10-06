/// The verdict on a topic the reader wants to add.
nonisolated enum TopicReviewOutcome: Equatable, Sendable {
    /// The cleaned-up phrase to store and show.
    case accepted(String)
    /// Why the topic can't be added, for the reader.
    case rejected(String)
}
