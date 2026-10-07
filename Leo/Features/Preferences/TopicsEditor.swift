import SwiftUI

/// The topic sections shared by onboarding and settings, for use inside a `List` or `Form`.
/// Lays out the ViewModel's draft; the caller saves it when the reader is done.
struct TopicsEditor: View {
    @Bindable var viewModel: PreferencesEditorViewModel

    var body: some View {
        Section("Suggested") {
            ForEach(viewModel.suggestedTopics) { topic in
                Toggle(isOn: binding(for: topic)) {
                    Text(topic.name)
                }
                .disabled(viewModel.isToggleDisabled(topic))
            }
            if viewModel.canResetSuggestedTopics {
                Button("Reset suggested topics", action: viewModel.resetSuggestedTopics)
            }
        }

        Section {
            ForEach(viewModel.customTopics) { topic in
                Text(topic.name)
                    .deleteDisabled(viewModel.isAtMinimum)
            }
            .onDelete { offsets in
                offsets.map { viewModel.customTopics[$0] }.forEach(viewModel.removeCustomTopic)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField("Add a topic", text: $viewModel.newTopic)
                        .submitLabel(.done)
                        .onSubmit(viewModel.add)
                        .disabled(viewModel.isReviewing)
                    if viewModel.isReviewing {
                        ProgressView()
                    } else {
                        Button("Add", action: viewModel.add)
                            .disabled(!viewModel.canAdd)
                    }
                }
                if let message = viewModel.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Your topics")
        } footer: {
            if viewModel.isAtMinimum {
                Text("Keep at least 3 topics on.")
            }
        }
    }

    private func binding(for topic: DefaultTopic) -> Binding<Bool> {
        Binding {
            viewModel.isEnabled(topic)
        } set: { isOn in
            viewModel.setEnabled(isOn, topic)
        }
    }
}

#Preview {
    List {
        TopicsEditor(viewModel: PreferencesEditorViewModel(
            draft: ReaderPreferences(ageGroup: .nine),
            topicReviews: FoundationModelsTopicReviewRepository(),
            onSave: { _ in },
        ))
    }
}
