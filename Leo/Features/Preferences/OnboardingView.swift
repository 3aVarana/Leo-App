import SwiftUI

/// Shown on first launch: the reader picks their age group, then their topics.
struct OnboardingView: View {
    @State private var viewModel: PreferencesEditorViewModel
    @State private var selection: AgeGroup?
    @State private var isShowingTopics = false

    init(viewModel: PreferencesEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            AgeGroupPicker(selection: $selection) {
                guard let selection else { return }
                viewModel.draft.ageGroup = selection
                isShowingTopics = true
            }
            .navigationDestination(isPresented: $isShowingTopics) {
                topics
            }
        }
    }

    private var topics: some View {
        List {
            Section {} header: {
                OnboardingTitle("What do you like reading about?")
            }
            TopicsEditor(viewModel: viewModel)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: viewModel.save)
            }
        }
    }
}

struct AgeGroupPicker: View {
    @Binding var selection: AgeGroup?
    let onContinue: () -> Void

    var body: some View {
        List {
            Section {
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
            } header: {
                OnboardingTitle("How old are you?")
            }
        }
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

/// A large title for the top of an onboarding list. Used as a section header rather than a
/// navigation title, which truncates long translations, or a row, whose rounded corners clip it.
private struct OnboardingTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.largeTitle.bold())
            // A section header draws in a secondary style, which `.primary` would follow.
            .foregroundStyle(Color.primary)
            .textCase(nil)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    OnboardingView(viewModel: PreferencesEditorViewModel(
        draft: ReaderPreferences(ageGroup: .fifteen),
        topicReviews: FoundationModelsTopicReviewRepository(),
        onSave: { _ in },
    ))
}
