import SwiftUI

/// Changes the age group and topics. Nothing is saved until Done.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ReaderPreferences
    private let onSave: (ReaderPreferences) -> Void

    init(preferences: ReaderPreferences, onSave: @escaping (ReaderPreferences) -> Void) {
        _draft = State(initialValue: preferences)
        self.onSave = onSave
    }

    var body: some View {
        // A sheet doesn't inherit the presenter's navigation stack.
        NavigationStack {
            Form {
                Section("Age group") {
                    Picker("Age group", selection: $draft.ageGroup) {
                        ForEach(AgeGroup.allCases, id: \.self) { group in
                            Text(group.displayName)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                TopicsEditor(preferences: $draft, group: draft.ageGroup)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(draft)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(preferences: ReaderPreferences(ageGroup: .twelve)) { _ in }
}
