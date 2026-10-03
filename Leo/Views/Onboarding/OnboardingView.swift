import SwiftUI

/// Shown on first launch: the reader picks their age group, then their topics.
struct OnboardingView: View {
    @Environment(PreferencesStore.self) private var store

    @State private var selection: AgeGroup?
    @State private var draft = ReaderPreferences(ageGroup: .fifteen)
    @State private var isShowingTopics = false

    var body: some View {
        NavigationStack {
            AgeGroupPicker(selection: $selection) {
                guard let selection else { return }
                draft.ageGroup = selection
                isShowingTopics = true
            }
            .navigationDestination(isPresented: $isShowingTopics) {
                topics
            }
        }
    }

    private var topics: some View {
        List {
            Text("What do you like reading about?")
                .font(.largeTitle.bold())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            TopicsEditor(preferences: $draft, group: draft.ageGroup)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { store.preferences = draft }
            }
        }
    }
}

struct AgeGroupPicker: View {
    @Binding var selection: AgeGroup?
    let onContinue: () -> Void

    var body: some View {
        List {
            ForEach(AgeGroup.allCases, id: \.self) { group in
                Button {
                    selection = group
                } label: {
                    HStack {
                        Text(group.displayName)
                        Spacer()
                        if selection == group {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(.rect)
                }
                .tint(.primary)
                .accessibilityAddTraits(selection == group ? .isSelected : [])
            }
        }
        .navigationTitle("How old are you?")
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selection == nil)
            .padding(24)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(PreferencesStore(defaults: UserDefaults(suiteName: "preview")!))
}
