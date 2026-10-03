import SwiftUI

/// The topic sections shared by onboarding and settings, for use inside a `List` or `Form`.
/// Edits go to `preferences`, which the caller saves when the reader is done.
struct TopicsEditor: View {
    @Binding var preferences: ReaderPreferences
    let group: AgeGroup

    @State private var newTopic = ""
    @State private var message: String?
    @State private var review = Review()

    private var defaults: [DefaultTopic] { DefaultTopics.topics(for: group) }
    private var customTopics: [CustomTopic] { preferences.customTopics[group] ?? [] }

    private var enabledCount: Int {
        defaults.filter { preferences.isEnabled($0, in: group) }.count + customTopics.count
    }

    private var isAtMinimum: Bool { enabledCount <= ReaderPreferences.minimumEnabledTopics }
    private var isReviewing: Bool { review.task != nil }

    var body: some View {
        Section("Suggested") {
            ForEach(defaults) { topic in
                let isOn = preferences.isEnabled(topic, in: group)
                Toggle(isOn: binding(for: topic)) {
                    Text(topic.name)
                }
                .disabled(isOn && isAtMinimum)
            }
            if !(preferences.disabledDefaultTopics[group]?.isEmpty ?? true) {
                Button("Reset suggested topics") {
                    preferences.disabledDefaultTopics[group] = nil
                }
            }
        }

        Section {
            ForEach(customTopics) { topic in
                Text(topic.name)
                    .deleteDisabled(isAtMinimum)
            }
            .onDelete { offsets in
                preferences.customTopics[group]?.remove(atOffsets: offsets)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField("Add a topic", text: $newTopic)
                        .submitLabel(.done)
                        .onSubmit(add)
                        .disabled(isReviewing)
                    if isReviewing {
                        ProgressView()
                    } else {
                        Button("Add", action: add)
                            .disabled(newTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Your topics")
        } footer: {
            if isAtMinimum {
                Text("Keep at least 3 topics on.")
            }
        }
        .onChange(of: newTopic) { message = nil }
        .onChange(of: group) { review.cancel() }
    }

    private func binding(for topic: DefaultTopic) -> Binding<Bool> {
        Binding {
            preferences.isEnabled(topic, in: group)
        } set: { isOn in
            if isOn {
                preferences.disabledDefaultTopics[group]?.remove(topic.id)
            } else {
                preferences.disabledDefaultTopics[group, default: []].insert(topic.id)
            }
        }
    }

    private enum Match {
        case enabled
        case disabledDefault(String)
    }

    /// Finds a topic already on the list with this name, ignoring case and accents.
    private func match(_ name: String) -> Match? {
        func same(_ other: String) -> Bool {
            name.compare(other, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if let topic = defaults.first(where: { same(String(localized: $0.name)) }) {
            return preferences.isEnabled(topic, in: group) ? .enabled : .disabledDefault(topic.id)
        }
        return customTopics.contains { same($0.name) } ? .enabled : nil
    }

    /// Adds `name` unless it's already on the list. Returns whether the field can be cleared.
    private func insert(_ name: String) -> Bool {
        switch match(name) {
        case .enabled:
            message = String(localized: "That topic is already on your list.")
            return false
        case .disabledDefault(let id):
            preferences.disabledDefaultTopics[group]?.remove(id)
        case nil:
            preferences.customTopics[group, default: []].append(CustomTopic(name: name))
        }
        return true
    }

    private func add() {
        guard !isReviewing else { return }
        let text = newTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard (2...60).contains(text.count) else {
            message = String(localized: "Topics must be between 2 and 60 characters.")
            return
        }
        // Checked before the model, so a topic already on the list costs nothing.
        if case .enabled = match(text) {
            message = String(localized: "That topic is already on your list.")
            return
        }
        if case .disabledDefault = match(text) {
            if insert(text) { newTopic = "" }
            return
        }
        guard customTopics.count < ReaderPreferences.maximumCustomTopics else {
            message = String(localized: "You can have up to 20 of your own topics.")
            return
        }

        message = nil
        let group = group
        let validator = TopicValidator(language: .current())
        review.task = Task {
            defer { if !Task.isCancelled { review.task = nil } }
            do {
                let outcome = try await validator.review(text, for: group)
                guard !Task.isCancelled else { return }
                switch outcome {
                case .accepted(let phrase):
                    if insert(phrase) { newTopic = "" }
                case .rejected(let reason):
                    message = reason
                }
            } catch {
                guard !Task.isCancelled else { return }
                message = String(localized: "We couldn't check that topic. Please try again.")
            }
        }
    }

}

/// Holds the review of a topic being added, and cancels it when the editor goes away.
/// `onDisappear` can't be used for that: in a `List` it also fires when the section
/// scrolls out of view, or when settings shows the age group picker.
@Observable
private final class Review {
    var task: Task<Void, Never>?

    func cancel() {
        task?.cancel()
        task = nil
    }

    isolated deinit {
        task?.cancel()
    }
}

#Preview {
    @Previewable @State var preferences = ReaderPreferences(ageGroup: .nine)
    List {
        TopicsEditor(preferences: $preferences, group: preferences.ageGroup)
    }
}
