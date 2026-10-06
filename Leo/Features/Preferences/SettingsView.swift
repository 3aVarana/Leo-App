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
            Form {
                Section("Age group") {
                    Picker("Age group", selection: $viewModel.draft.ageGroup) {
                        ForEach(AgeGroup.allCases, id: \.self) { group in
                            Text(group.displayName)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                TopicsEditor(viewModel: viewModel)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
    }
}

#Preview {
    SettingsView(viewModel: PreferencesEditorViewModel(
        draft: ReaderPreferences(ageGroup: .twelve),
        topicReviews: FoundationModelsTopicReviewRepository(),
        onSave: { _ in },
    ))
}
