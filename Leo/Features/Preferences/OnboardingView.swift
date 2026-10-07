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
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingTopics) {
                OnboardingTopics(viewModel: viewModel)
            }
        }
    }
}

struct AgeGroupPicker: View {
    @Binding var selection: AgeGroup?
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker("Welcome to Leo")
                Text("How old are you?")
                    .leoTextStyle(.display(38))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.vertical, 12)
                Text("Every text is written for your age — its length, its words, its questions.")
                    .leoTextStyle(.body)
                    .foregroundStyle(Color.leoInkSoft)
                    .padding(.bottom, 24)
                VStack(spacing: 2) {
                    ForEach(AgeGroup.allCases, id: \.self) { group in
                        AgeRow(label: group.displayName, description: group.summary, isSelected: selection == group) {
                            selection = group
                        }
                    }
                }
            }
            .foregroundStyle(Color.leoInk)
            .padding(.top, 20)
            .leoReadableWidth()
        }
        .safeAreaInset(edge: .bottom) {
            Button("Continue", action: onContinue)
                .buttonStyle(.leo(.primary))
                .disabled(selection == nil)
                .leoReadableWidth()
                .padding(.top, 16)
                .background(Color.leoBackground)
        }
        .leoScreenBackground()
    }
}

/// The second onboarding screen. The system back button returns to the age groups.
struct OnboardingTopics: View {
    let viewModel: PreferencesEditorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker("Welcome to Leo")
                Text("What do you like reading about?")
                    .leoTextStyle(.display(34))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.vertical, 10)
                Text("\(viewModel.enabledTopicCount) topics on · keep at least 3. Leo picks one for each text.")
                    .leoTextStyle(.bodySmall)
                    .foregroundStyle(Color.leoInkSoft)
                MinimumTopicsWarning(viewModel: viewModel)
                    .padding(.top, 6)
                Kicker("Suggested for \(viewModel.draft.ageGroup.displayName)")
                    .padding(.top, 22)
                    .padding(.bottom, 10)
                    .accessibilityAddTraits(.isHeader)
                TopicsEditor(viewModel: viewModel)
            }
            .foregroundStyle(Color.leoInk)
            .padding(.top, 8)
            .leoReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button("Done", action: viewModel.save)
                .buttonStyle(.leo(.primary))
                .leoReadableWidth()
                .padding(.top, 14)
                .background(Color.leoBackground)
        }
        .navigationBarTitleDisplayMode(.inline)
        .leoScreenBackground()
    }
}

#Preview {
    OnboardingView(viewModel: PreferencesEditorViewModel(
        draft: ReaderPreferences(ageGroup: .fifteen),
        topicReviews: FoundationModelsTopicReviewRepository(),
        onSave: { _ in },
    ))
}
