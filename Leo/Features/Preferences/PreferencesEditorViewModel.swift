import Foundation
import Observation

/// Edits a draft of the reader's preferences, for onboarding and settings. Nothing reaches
/// `onSave` until `save()`.
@Observable
final class PreferencesEditorViewModel {
    var draft: ReaderPreferences {
        didSet {
            // A review checks the topic for the group it was typed under.
            if draft.ageGroup != oldValue.ageGroup {
                cancelReview()
            }
        }
    }

    /// The topic being typed. Editing it clears `message`.
    var newTopic = "" {
        didSet {
            if newTopic != oldValue {
                message = nil
            }
        }
    }

    /// Why the last topic wasn't added, for the reader.
    private(set) var message: String?

    private var review: Task<Void, Never>?
    private let topicReviews: any TopicReviewRepository
    private let onSave: (ReaderPreferences) -> Void

    init(
        draft: ReaderPreferences,
        topicReviews: any TopicReviewRepository,
        onSave: @escaping (ReaderPreferences) -> Void,
    ) {
        self.draft = draft
        self.topicReviews = topicReviews
        self.onSave = onSave
    }

    /// Cancels a pending review when the editor goes away. `onDisappear` can't be used for
    /// that: in a `List` it also fires when the section scrolls out of view, or when settings
    /// shows the age group picker.
    isolated deinit {
        review?.cancel()
    }

    var isReviewing: Bool {
        review != nil
    }

    var canAdd: Bool {
        !trimmedTopic.isEmpty && !isReviewing
    }

    // MARK: - The topics of the draft's age group

    var suggestedTopics: [DefaultTopic] {
        DefaultTopics.topics(for: group)
    }

    var customTopics: [CustomTopic] {
        draft.customTopics[group] ?? []
    }

    /// Suggested and custom topics that are on.
    var enabledTopicCount: Int {
        draft.enabledTopicCount(in: group)
    }

    var enabledSuggestedCount: Int {
        draft.enabledSuggestedTopicCount(in: group)
    }

    var isAtMinimum: Bool {
        draft.isAtMinimum(in: group)
    }

    var canResetSuggestedTopics: Bool {
        !(draft.disabledDefaultTopics[group]?.isEmpty ?? true)
    }

    func isEnabled(_ topic: DefaultTopic) -> Bool {
        draft.isEnabled(topic, in: group)
    }

    /// A topic that's on can't be turned off at the minimum.
    func isToggleDisabled(_ topic: DefaultTopic) -> Bool {
        isEnabled(topic) && isAtMinimum
    }

    func setEnabled(_ isOn: Bool, _ topic: DefaultTopic) {
        draft.setEnabled(isOn, topic, in: group)
    }

    func resetSuggestedTopics() {
        draft.resetSuggestedTopics(in: group)
    }

    /// Does nothing at the minimum, where the remove control is hidden.
    func removeCustomTopic(_ topic: CustomTopic) {
        guard !isAtMinimum else { return }
        draft.removeCustomTopic(id: topic.id, in: group)
    }

    // MARK: - Adding a topic

    /// Adds the typed topic after the local checks, asking the model to review it when needed.
    func add() {
        guard !isReviewing else { return }
        let text = trimmedTopic
        guard !text.isEmpty else { return }
        switch draft.check(newTopic: text, in: group) {
        case .invalidLength:
            message = String(localized: "Topics must be between 2 and 60 characters.")
        case .alreadyOnList:
            message = Self.alreadyOnList
        case .reEnablesSuggested:
            insert(text, in: group)
        case .tooManyCustomTopics:
            message = String(localized: "You can have up to 20 of your own topics.")
        case .needsReview:
            startReview(of: text)
        }
    }

    func cancelReview() {
        review?.cancel()
        review = nil
    }

    func save() {
        onSave(draft)
    }

    private var group: AgeGroup {
        draft.ageGroup
    }

    private var trimmedTopic: String {
        newTopic.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static var alreadyOnList: String {
        String(localized: "That topic is already on your list.")
    }

    /// Adds `name` unless it's already on the list, and clears the field when it was added.
    private func insert(_ name: String, in group: AgeGroup) {
        if draft.insertTopic(name, in: group) {
            newTopic = ""
        } else {
            message = Self.alreadyOnList
        }
    }

    /// Asks the model whether `text` suits the reader, and adds its tidied-up phrase if it does.
    /// The review belongs to the age group at this moment, and is dropped if it's cancelled.
    private func startReview(of text: String) {
        message = nil
        let group = group
        review = Task { [weak self, topicReviews] in
            let result: Result<TopicReviewOutcome, any Error>
            do {
                result = try await .success(topicReviews.review(text, for: group))
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled, let self else { return }
            review = nil
            switch result {
            case let .success(.accepted(phrase)):
                insert(phrase, in: group)
            case let .success(.rejected(reason)):
                message = reason
            case .failure:
                message = String(localized: "We couldn't check that topic. Please try again.")
            }
        }
    }
}
