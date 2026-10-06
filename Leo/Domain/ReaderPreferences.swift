/// The reader's choices, saved so later launches skip onboarding.
nonisolated struct ReaderPreferences: Codable, Equatable, Sendable {
    var ageGroup: AgeGroup
    /// Ids of the suggested topics the reader turned off. Stored instead of the enabled ones,
    /// so suggested topics added in later versions start out enabled.
    var disabledDefaultTopics: [AgeGroup: Set<String>] = [:]
    var customTopics: [AgeGroup: [CustomTopic]] = [:]

    static let minimumEnabledTopics = 3
    static let maximumCustomTopics = 20

    init(ageGroup: AgeGroup) {
        self.ageGroup = ageGroup
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ageGroup = try container.decode(AgeGroup.self, forKey: .ageGroup)
        disabledDefaultTopics = try container.decodeIfPresent(
            [AgeGroup: Set<String>].self,
            forKey: .disabledDefaultTopics,
        ) ?? [:]
        customTopics = try container.decodeIfPresent([AgeGroup: [CustomTopic]].self, forKey: .customTopics) ?? [:]
    }

    func isEnabled(_ topic: DefaultTopic, in group: AgeGroup) -> Bool {
        !(disabledDefaultTopics[group]?.contains(topic.id) ?? false)
    }

    /// The topics to write about, in a stable order (suggested topics, then the reader's own),
    /// so equal preferences always produce equal round settings.
    func enabledTopics(for group: AgeGroup) -> [RoundTopic] {
        let defaults = DefaultTopics.topics(for: group)
        let topics = defaults.filter { isEnabled($0, in: group) }.map(\.roundTopic)
            + (customTopics[group] ?? []).map(\.roundTopic)
        // Only possible with stale data, since the editor keeps a minimum enabled.
        return topics.isEmpty ? defaults.map(\.roundTopic) : topics
    }

    var roundSettings: RoundSettings {
        RoundSettings(ageGroup: ageGroup, topics: enabledTopics(for: ageGroup))
    }
}
