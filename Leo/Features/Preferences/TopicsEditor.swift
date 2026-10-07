import SwiftUI

/// The topic chips, the reader's own topics and the field to add one, shared by onboarding
/// and settings. The caller puts its own heading above the suggested topics, and saves the
/// ViewModel's draft when the reader is done.
struct TopicsEditor: View {
    @Bindable var viewModel: PreferencesEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FlowLayout {
                ForEach(viewModel.suggestedTopics) { topic in
                    TopicChip(name: String(localized: topic.name), isOn: binding(for: topic))
                        .accessibilityHint(minimumHint(for: topic))
                }
            }

            Kicker("Your topics")
                .padding(.top, 22)
                .padding(.bottom, 10)
                .accessibilityAddTraits(.isHeader)

            if !viewModel.customTopics.isEmpty {
                FlowLayout {
                    ForEach(viewModel.customTopics) { topic in
                        CustomTopicChip(
                            name: topic.name,
                            onRemove: viewModel.isAtMinimum ? nil : { viewModel.removeCustomTopic(topic) },
                        )
                    }
                }
                .padding(.bottom, 10)
            }

            AddTopicField(viewModel: viewModel)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.minimumWarningCount)
    }

    private static let minimumHint: LocalizedStringResource = "At least 3 topics must stay on."

    /// Why a topic that's on can't be turned off, at the minimum.
    private func minimumHint(for topic: DefaultTopic) -> Text {
        viewModel.isToggleDisabled(topic) ? Text(Self.minimumHint) : Text(verbatim: "")
    }

    private func binding(for topic: DefaultTopic) -> Binding<Bool> {
        Binding {
            viewModel.isEnabled(topic)
        } set: { isOn in
            viewModel.setEnabled(isOn, topic)
        }
    }
}

/// "Keep at least 3 topics on.", shown after the reader tried to turn off a topic at the minimum.
struct MinimumTopicsWarning: View {
    let viewModel: PreferencesEditorViewModel

    var body: some View {
        if viewModel.isShowingMinimumWarning {
            Text("Keep at least 3 topics on.")
                .leoTextStyle(.note)
                .foregroundStyle(Color.leoMagenta700)
        }
    }
}

private struct AddTopicField: View {
    @Bindable var viewModel: PreferencesEditorViewModel

    @ScaledMetric(relativeTo: .callout) private var height = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField(text: $viewModel.newTopic) {
                    Text("Add a topic")
                        .foregroundStyle(Color.leoInk.opacity(0.65))
                }
                .leoTextStyle(LeoTextStyle(size: 16, relativeTo: .callout))
                .foregroundStyle(Color.leoInk)
                .submitLabel(.done)
                .onSubmit(viewModel.add)
                .disabled(viewModel.isReviewing)
                .padding(.horizontal, 10)
                .frame(minHeight: height)
                .background(Color.leoSurface, in: .rect(cornerRadius: 2))
                .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(Color.leoDivider) }
                if viewModel.isReviewing {
                    ProgressView()
                        .frame(minWidth: height, minHeight: height)
                } else {
                    Button("Add", action: viewModel.add)
                        .buttonStyle(.leo(.secondary))
                        .disabled(!viewModel.canAdd)
                }
            }
            if let message = viewModel.message {
                Text(message)
                    .leoTextStyle(.note)
                    .foregroundStyle(Color.leoMagenta700)
            }
        }
    }
}

#Preview {
    ScrollView {
        TopicsEditor(viewModel: PreferencesEditorViewModel(
            draft: ReaderPreferences(ageGroup: .nine),
            topicReviews: FoundationModelsTopicReviewRepository(),
            onSave: { _ in },
        ))
        .padding(24)
    }
    .leoScreenBackground()
}
