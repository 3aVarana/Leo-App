/// Whether a topic asks for a story or for facts. Stories are written more freely than facts.
/// `open` is a reader's own topic, which could be either: the model decides from the phrase.
/// Raw values are persisted with a saved round. Never change them.
nonisolated enum TopicKind: String, Sendable {
    case story, informative, open
}

/// A topic of a round: the English phrase the model writes about, and the name the reader sees.
nonisolated struct RoundTopic: Hashable, Sendable {
    /// The English phrase for the model.
    let prompt: String
    /// Shown to the reader: the localized name of a suggested topic, or the name of the reader's own.
    let name: String
    let kind: TopicKind

    init(prompt: String, name: String, kind: TopicKind = .informative) {
        self.prompt = prompt
        self.name = name
        self.kind = kind
    }
}
