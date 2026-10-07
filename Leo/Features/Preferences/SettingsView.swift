import SwiftUI

/// Changes the age group and topics. Nothing is saved until Done.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PreferencesEditorViewModel

    init(viewModel: PreferencesEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        // A sheet doesn't inherit the presenter's navigation stack.
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Kicker("Age group")
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 10)
                    AgeSegmentedControl(selection: $viewModel.draft.ageGroup)
                    Text(viewModel.draft.ageGroup.summary)
                        .leoTextStyle(.caption)
                        .foregroundStyle(Color.leoInkMuted)
                        .padding(.top, 8)

                    HStack(alignment: .firstTextBaseline) {
                        Kicker("Suggested · \(viewModel.enabledSuggestedCount) on")
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        if viewModel.canResetSuggestedTopics {
                            Button("Reset", action: viewModel.resetSuggestedTopics)
                                .buttonStyle(.leo(.ghost))
                                .font(.leo(14, relativeTo: .subheadline))
                        }
                    }
                    .frame(minHeight: 44)
                    .padding(.top, 14)
                    MinimumTopicsWarning(viewModel: viewModel)
                        .padding(.bottom, 8)
                    TopicsEditor(viewModel: viewModel)
                }
                .foregroundStyle(Color.leoInk)
                .padding(.top, 22)
                .padding(.bottom, 24)
                .leoReadableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .leoScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .leoTextStyle(LeoTextStyle(size: 17, weight: .semibold, relativeTo: .headline))
                        .foregroundStyle(Color.leoInk)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.save()
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(Color.leoBackground)
    }
}

#Preview {
    SettingsView(viewModel: PreferencesEditorViewModel(
        draft: ReaderPreferences(ageGroup: .twelve),
        topicReviews: FoundationModelsTopicReviewRepository(),
        onSave: { _ in },
    ))
}
