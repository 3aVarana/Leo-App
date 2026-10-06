/// A topic of a round: the English phrase the model writes about, and the name the reader sees.
nonisolated struct RoundTopic: Hashable, Sendable {
    /// The English phrase for the model.
    let prompt: String
    /// Shown to the reader: the localized name of a suggested topic, or the name of the reader's own.
    let name: String
}
