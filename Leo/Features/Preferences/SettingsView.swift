import SwiftUI

/// Changes the age group and topics. Nothing is saved until Done.
struct SettingsView: View {
    @Environment(PreferencesStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ReaderPreferences

    init(preferences: ReaderPreferences) {
        _draft = State(initialValue: preferences)
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
                        store.preferences = draft
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(preferences: ReaderPreferences(ageGroup: .twelve))
        .environment(PreferencesStore(defaults: UserDefaults(suiteName: "preview")!))
}
