import Foundation

// The rules for editing the topics of one age group, shared by onboarding and settings.
// They return what happened; `PreferencesEditorViewModel` turns that into messages.

nonisolated extension ReaderPreferences {
    /// How long a topic the reader types can be.
    static let topicNameLength = 2 ... 60

    /// A topic already on the list with a given name.
    enum TopicMatch: Equatable {
        case enabled
        case disabledDefault(id: String)
    }

    /// What adding a topic needs, checked in this order: length, enabled duplicate,
    /// disabled suggested topic, custom topic limit.
    enum NewTopicCheck: Equatable {
        case invalidLength
        case alreadyOnList
        case reEnablesSuggested(id: String)
        case tooManyCustomTopics
        case needsReview
    }

    func enabledTopicCount(in group: AgeGroup) -> Int {
        enabledSuggestedTopicCount(in: group) + (customTopics[group] ?? []).count
    }

    func enabledSuggestedTopicCount(in group: AgeGroup) -> Int {
        DefaultTopics.topics(for: group).filter { isEnabled($0, in: group) }.count
    }

    /// Whether no more topics can be turned off or removed.
    func isAtMinimum(in group: AgeGroup) -> Bool {
        enabledTopicCount(in: group) <= Self.minimumEnabledTopics
    }

    /// Finds a topic already on the list with this name, ignoring case and accents.
    func match(_ name: String, in group: AgeGroup) -> TopicMatch? {
        func same(_ other: String) -> Bool {
            name.compare(other, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if let topic = DefaultTopics.topics(for: group).first(where: { same(String(localized: $0.name)) }) {
            return isEnabled(topic, in: group) ? .enabled : .disabledDefault(id: topic.id)
        }
        return (customTopics[group] ?? []).contains { same($0.name) } ? .enabled : nil
    }

    /// What adding `text`, already trimmed, to `group` needs.
    func check(newTopic text: String, in group: AgeGroup) -> NewTopicCheck {
        guard Self.topicNameLength.contains(text.count) else { return .invalidLength }
        switch match(text, in: group) {
        case .enabled:
            return .alreadyOnList
        case let .disabledDefault(id):
            return .reEnablesSuggested(id: id)
        case nil:
            break
        }
        guard (customTopics[group] ?? []).count < Self.maximumCustomTopics else { return .tooManyCustomTopics }
        return .needsReview
    }

    /// Doesn't enforce the minimum: the editor disables the toggle instead.
    mutating func setEnabled(_ isOn: Bool, _ topic: DefaultTopic, in group: AgeGroup) {
        if isOn {
            disabledDefaultTopics[group]?.remove(topic.id)
        } else {
            disabledDefaultTopics[group, default: []].insert(topic.id)
        }
    }

    mutating func resetSuggestedTopics(in group: AgeGroup) {
        disabledDefaultTopics[group] = nil
    }

    /// Doesn't enforce the minimum: the editor hides the remove control instead.
    mutating func removeCustomTopic(id: CustomTopic.ID, in group: AgeGroup) {
        customTopics[group]?.removeAll { $0.id == id }
    }

    /// Adds a reviewed phrase, re-enabling the suggested topic it names if there is one.
    /// Returns `false`, changing nothing, when the topic is already enabled.
    mutating func insertTopic(_ name: String, in group: AgeGroup) -> Bool {
        switch match(name, in: group) {
        case .enabled:
            return false
        case let .disabledDefault(id):
            disabledDefaultTopics[group]?.remove(id)
        case nil:
            customTopics[group, default: []].append(CustomTopic(name: name))
        }
        return true
    }
}
