/// The reader's choices, saved so later launches skip onboarding.
nonisolated struct ReaderPreferences: Codable, Equatable, Sendable {
    var ageGroup: AgeGroup
    /// Ids of the suggested topics the reader turned off. Stored instead of the enabled ones,
    /// so suggested topics added in later versions start out enabled.
    var disabledDefaultTopics: [AgeGroup: Set<String>] = [:]
    var customTopics: [AgeGroup: [CustomTopic]] = [:]
    /// Whether the question replaces the passage when its reading time runs out. Without it,
    /// the passage stays until the reader moves on.
    var isReadingTimerOn = true

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
        isReadingTimerOn = try container.decodeIfPresent(Bool.self, forKey: .isReadingTimerOn) ?? true
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
        // Fewer than the minimum only happens with stale data. makePlan needs that many topics,
        // so top up with suggested topics the reader turned off, keeping the ones they chose.
        guard topics.count < Self.minimumEnabledTopics else { return topics }
        let disabled = defaults.filter { !isEnabled($0, in: group) }.map(\.roundTopic)
        return topics + disabled.prefix(Self.minimumEnabledTopics - topics.count)
    }

    var roundSettings: RoundSettings {
        RoundSettings(ageGroup: ageGroup, topics: enabledTopics(for: ageGroup))
    }
}
