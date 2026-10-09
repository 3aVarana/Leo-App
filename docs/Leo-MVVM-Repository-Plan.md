# Leo MVVM + Repository Plan

## 1. Scope

Leo's code is organized as observable models and views: `QuizModel` and `PreferencesStore` are `@Observable` classes, and the views read and write them directly. This plan restructures the app into **MVVM with repositories**:

1. A **Domain** layer of plain value types and rules, with no SwiftUI or FoundationModels imports.
2. A **Data** layer: repository protocols, their implementations, and the on-device model data sources behind them.
3. **ViewModels** that own screen state and logic, and views that only lay it out.
4. **Tests for every change**: each pull request adds or updates unit tests for the code it touches, and keeps every snapshot reference unchanged.

This is a refactor. **Apart from the one change listed in section 8.2, the app's behavior must not change.** In each pull request, every existing snapshot reference image and text file must stay byte-for-byte the same.

Out of scope: new features, UI changes, changes to prompts, persistence format changes, coverage gates, UI tests (XCUITest).

## 2. Agreed decisions

| Area | Decision |
|---|---|
| Preferences state | **Stateless repository + `RootViewModel`.** `PreferencesRepository` only loads and saves. `RootViewModel` holds `preferences` and is the only place that saves them. Onboarding and Settings hand their result back through an `onSave` closure. No protocol is injected through the SwiftUI environment. |
| Topic editing | **One shared `PreferencesEditorViewModel`** for Onboarding and Settings. It owns the draft, the new-topic text, the message and the review task. The pure rules (duplicate matching, minimum enabled, maximum custom, name length) move onto `ReaderPreferences` as domain methods. |
| Folder layout | **By feature**: `App/`, `Domain/`, `Data/`, `Features/<Feature>/`. Tests mirror it. |
| Views without a ViewModel | `WelcomeView`, `LoadingView`, `ResultView`, `UnavailableView` and `AgeGroupPicker` take plain values and closures, as they do now. They don't get a ViewModel. |
| Navigation state | Purely presentational state (`OnboardingView`'s age selection and push, `isShowingTopics`) stays in the view as `@State`. Everything that decides or mutates data moves to a ViewModel. |
| Dependency injection | Constructor injection only. `MyApp` is the composition root. Test doubles live in `LeoTests/Support/`, never in the app target. |
| Actor isolation | Unchanged: the app target defaults to `MainActor`. ViewModels, repositories and protocols are main-actor isolated by default. Types that are `nonisolated` today stay `nonisolated`. |
| Tests | Swift Testing, as today. Hand-written fakes, following the `StubGenerator` pattern. Snapshot references must not be re-recorded. |
| Document location | This file, next to the other plans in `docs/`. |

## 3. Project facts relevant to implementation

- Both `Leo/` and `LeoTests/` are file-system synchronized groups: moving or adding files needs no `project.pbxproj` edits.
- Snapshot references are stored in `LeoTestsSnapshots/<test file name>/` (see `assertReferenceSnapshot` in `LeoTests/Support/SnapshotHelpers.swift`). The **file name** decides the folder, not the directory the file is in, so test files can move to new folders. **Never rename these test files**: `ExerciseViewSnapshotTests`, `LoadingViewSnapshotTests`, `OnboardingSnapshotTests`, `ResultViewSnapshotTests`, `SettingsViewSnapshotTests`, `TopicsEditorSnapshotTests`, `UnavailableViewSnapshotTests`, `WelcomeViewSnapshotTests`, `ExerciseGeneratorPromptTests`, `DefaultTopicsTests`, `ReaderPreferencesTests`.
- `SystemLanguageModel` conforms to `Observable` (checked in the iOS 27 SDK interface). `RootView` reading `availability` today re-renders when the model becomes ready. The new availability provider must keep that working (section 5.2).
- With default `MainActor` isolation, an extension of a `nonisolated` type declared in another file is main-actor isolated unless it is written `nonisolated extension`. This matters when members move between files (section 6, PR 1).
- The `Leo` test plan passes `--leo-running-tests`, which `MyApp` uses to show an empty view. That guard stays.
- The CI requires SwiftLint, SwiftFormat and the `Leo` test plan to pass on every pull request.

## 4. Target architecture

```
Leo/
├── App/
│   └── MyApp.swift                        Composition root: builds repositories and RootViewModel
├── Domain/                                No SwiftUI, no FoundationModels
│   ├── AgeGroup.swift                     displayName, passageWordRange, acceptedWordCount
│   ├── ComprehensionSkill.swift           displayName
│   ├── Exercise.swift                     Exercise, String.wordCount
│   ├── ModelAvailability.swift            ModelAvailability, ModelUnavailableReason
│   ├── ReaderPreferences.swift            + topic editing rules (section 5.1)
│   ├── RoundSettings.swift
│   ├── Topic.swift                        DefaultTopic, CustomTopic, DefaultTopics
│   └── TopicReviewOutcome.swift
├── Data/
│   ├── Repositories/
│   │   ├── PreferencesRepository.swift    protocol + UserDefaultsPreferencesRepository
│   │   ├── ExerciseRepository.swift       protocol + FoundationModelsExerciseRepository + ExerciseGenerationError
│   │   ├── TopicReviewRepository.swift    protocol + FoundationModelsTopicReviewRepository
│   │   └── ModelAvailabilityProvider.swift protocol + SystemModelAvailabilityProvider
│   └── FoundationModels/
│       ├── ContentLanguage.swift
│       ├── ExerciseGenerator.swift
│       ├── GeneratedExercise.swift        @Generable type + Exercise.init?(generated:…)
│       ├── PromptVocabulary.swift         promptAudience, styleGuidance, passageSentenceRange, promptHint
│       └── TopicValidator.swift           TopicReview + TopicValidator
└── Features/
    ├── Root/
    │   ├── RootView.swift
    │   ├── RootViewModel.swift
    │   └── UnavailableView.swift
    ├── Quiz/
    │   ├── QuizViewModel.swift            renamed from QuizModel
    │   ├── WelcomeView.swift
    │   ├── LoadingView.swift
    │   ├── ExerciseView.swift
    │   └── ResultView.swift
    └── Preferences/
        ├── PreferencesEditorViewModel.swift
        ├── OnboardingView.swift           + AgeGroupPicker, OnboardingTitle
        ├── SettingsView.swift
        └── TopicsEditor.swift

LeoTests/
├── Domain/          AgeGroupTests, DefaultTopicsTests, ExerciseTests, ReaderPreferencesTests,
│                    ReaderPreferencesTopicEditingTests (new), WordCountTests
├── Data/            UserDefaultsPreferencesRepositoryTests (replaces PreferencesStoreTests),
│                    FoundationModelsExerciseRepositoryTests (new), ModelAvailabilityTests (new),
│                    ContentLanguageTests, ExerciseGeneratorPromptTests, TopicValidatorTests
├── Features/        QuizViewModelTests (renamed), QuizPlanTests, RootViewModelTests (new),
│                    PreferencesEditorViewModelTests (new)
├── LiveModel/       unchanged
├── Snapshots/       same file names, updated constructors, two new TopicsEditor cases
└── Support/         StubExerciseRepository, ExerciseRepositoryFactorySpy, StubTopicReviewRepository,
                     PreferencesRepositorySpy, StubModelAvailabilityProvider, ViewModel fixtures
```

`Localizable.xcstrings` and the asset catalog stay at the `Leo/` root.

### Dependency direction

```
Features (Views → ViewModels) ──▶ Data/Repositories (protocols) ──▶ Domain
                                          ▲
App (composition root) ── builds ─────────┘ implementations ──▶ Data/FoundationModels, UserDefaults
```

- Views depend on their ViewModel and on Domain types. They never import `FoundationModels`.
- ViewModels depend on repository **protocols** and Domain types only.
- Repository implementations depend on data sources (`ExerciseGenerator`, `TopicValidator`, `UserDefaults`, `SystemLanguageModel`).
- Domain depends on nothing but Foundation.

## 5. Design

### 5.1 Domain

**Moved unchanged:** `AgeGroup`, `ComprehensionSkill` (split out of `Exercise.swift`), `Exercise`, `String.wordCount`, `RoundSettings` (split out of `ReaderPreferences.swift`), `DefaultTopic`, `CustomTopic`, `DefaultTopics`.

**Moved out of Domain into `Data/FoundationModels/`:**

- `GeneratedExercise` and `Exercise.init?(generated:topic:skill:acceptedWordCount:)` (as an extension), so `Exercise.swift` no longer imports FoundationModels.
- Prompt prose, as `nonisolated extension`s in `PromptVocabulary.swift`: `AgeGroup.promptAudience`, `AgeGroup.styleGuidance`, `AgeGroup.passageSentenceRange`, `ComprehensionSkill.promptHint`.

**New: `ModelAvailability`** replaces `SystemLanguageModel.Availability` in views:

```swift
nonisolated enum ModelUnavailableReason: Equatable, Sendable {
    case deviceNotEligible, appleIntelligenceNotEnabled, modelNotReady, other
}

nonisolated enum ModelAvailability: Equatable, Sendable {
    case available
    case unavailable(ModelUnavailableReason)
}
```

**New: `TopicReviewOutcome`**, renamed from `TopicValidator.Outcome` (`accepted(String)`, `rejected(String)`).

**New: topic editing rules on `ReaderPreferences`**, moved out of `TopicsEditor` without changing behavior:

```swift
extension ReaderPreferences {
    static let topicNameLength = 2 ... 60          // was a literal in TopicsEditor

    enum TopicMatch: Equatable { case enabled, disabledDefault(id: String) }

    /// What adding `text` (already trimmed) to `group` needs, checked in this order:
    /// length, enabled duplicate, disabled suggested topic, custom topic limit.
    enum NewTopicCheck: Equatable {
        case invalidLength
        case alreadyOnList
        case reEnablesSuggested(id: String)
        case tooManyCustomTopics
        case needsReview
    }

    func enabledTopicCount(in group: AgeGroup) -> Int
    func isAtMinimum(in group: AgeGroup) -> Bool
    func match(_ name: String, in group: AgeGroup) -> TopicMatch?   // ignores case and accents
    func check(newTopic text: String, in group: AgeGroup) -> NewTopicCheck

    mutating func setEnabled(_ isOn: Bool, _ topic: DefaultTopic, in group: AgeGroup)
    mutating func resetSuggestedTopics(in group: AgeGroup)
    mutating func removeCustomTopics(atOffsets offsets: IndexSet, in group: AgeGroup)

    /// Adds a reviewed phrase. Returns false, changing nothing, when it is already enabled.
    mutating func insertTopic(_ name: String, in group: AgeGroup) -> Bool
}
```

The domain methods return results. The ViewModel turns them into localized messages. Like today, `setEnabled` doesn't enforce the minimum itself: the view disables the toggle.

### 5.2 Data: repositories

All protocols are main-actor isolated (the module default), like `ExerciseGenerating` today.

**`PreferencesRepository`**

```swift
protocol PreferencesRepository {
    func load() -> ReaderPreferences?
    func save(_ preferences: ReaderPreferences)
}

struct UserDefaultsPreferencesRepository: PreferencesRepository {
    static let key = "readerPreferences"     // never change: existing installs read it
    let defaults: UserDefaults
}
```

- Same JSON format and key as `PreferencesStore`. Missing or corrupt data loads as `nil`.
- `PreferencesStore` is deleted.

**`ExerciseRepository`** (renamed from `ExerciseGenerating`):

```swift
/// Supplies the exercises of one round. A new one is made for each round, so a change
/// to the device language applies to the next round.
protocol ExerciseRepository {
    func exercise(topics: [String], skill: ComprehensionSkill) async throws -> Exercise
}

struct FoundationModelsExerciseRepository: ExerciseRepository {
    let generator: ExerciseGenerator      // internal, so tests can check how it was built
    init(ageGroup: AgeGroup, language: ContentLanguage = .current())
}
```

`ExerciseGenerationError` moves next to the protocol, because it is part of the repository's contract.

**`TopicReviewRepository`**

```swift
protocol TopicReviewRepository {
    func review(_ text: String, for group: AgeGroup) async throws -> TopicReviewOutcome
}

struct FoundationModelsTopicReviewRepository: TopicReviewRepository {
    /// Resolves the language on every call, as TopicsEditor does today.
    func review(_ text: String, for group: AgeGroup) async throws -> TopicReviewOutcome {
        try await TopicValidator(language: .current()).review(text, for: group)
    }
}
```

**`ModelAvailabilityProvider`**

```swift
protocol ModelAvailabilityProvider {
    var availability: ModelAvailability { get }
}

struct SystemModelAvailabilityProvider: ModelAvailabilityProvider {
    /// Read on every access, never cached: `SystemLanguageModel` is `Observable`, so
    /// a view that reads this re-renders when the model becomes available.
    var availability: ModelAvailability { ModelAvailability(SystemLanguageModel.default.availability) }
}
```

`ModelAvailability.init(_: SystemLanguageModel.Availability)` lives in the Data layer, so it can be unit tested. `@unknown default` maps to `.other`.

### 5.3 ViewModels

**`RootViewModel`** (`@Observable`)

```swift
init(preferences: any PreferencesRepository,
     availability: any ModelAvailabilityProvider,
     topicReviews: any TopicReviewRepository,
     quiz: QuizViewModel)

private(set) var preferences: ReaderPreferences?   // loaded in init
var availability: ModelAvailability { get }         // forwards to the provider, never cached
let quiz: QuizViewModel
var isShowingSettings = false

func save(_ preferences: ReaderPreferences)          // does nothing when equal; else persists and sets
func preferencesDidChange()                          // configures quiz with preferences?.roundSettings
func makeOnboardingEditor() -> PreferencesEditorViewModel
func makeSettingsEditor() -> PreferencesEditorViewModel?   // nil before onboarding
```

- `RootView` keeps `.task(id: viewModel.preferences?.roundSettings) { viewModel.preferencesDidChange() }`, so unchanged settings still keep the round that's already prepared.
- The editors' `onSave` closures capture `[weak self]`.

**`QuizViewModel`** (renamed from `QuizModel`)

- Its init no longer has a default value: `init(makeRepository: @escaping (RoundSettings) -> any ExerciseRepository)`. `MyApp` supplies `{ FoundationModelsExerciseRepository(ageGroup: $0.ageGroup) }`.
- New presentation API, moved out of `ExerciseView`:
  - `enum OptionState { case idle, correct, incorrect, dimmed }` (was the private `OptionButton.State`).
  - `func optionState(at index: Int) -> OptionState`
  - `var isAnswerCorrect: Bool?`: `nil` before answering.
- `ExerciseView` and `OptionButton` use these. `ExerciseView(quiz:exercise:)` keeps its shape. Only the type name changes.

**`PreferencesEditorViewModel`** (`@Observable`)

```swift
init(draft: ReaderPreferences,
     topicReviews: any TopicReviewRepository,
     onSave: @escaping (ReaderPreferences) -> Void)

var draft: ReaderPreferences          // a change of draft.ageGroup cancels a pending review
var newTopic: String                  // editing it clears `message`
private(set) var message: String?
var isReviewing: Bool { get }
var canAdd: Bool { get }              // trimmed text not empty and not reviewing

// Read by TopicsEditor for draft.ageGroup
var suggestedTopics: [DefaultTopic] { get }
var customTopics: [CustomTopic] { get }
var isAtMinimum: Bool { get }
var canResetSuggestedTopics: Bool { get }
func isEnabled(_ topic: DefaultTopic) -> Bool
func isToggleDisabled(_ topic: DefaultTopic) -> Bool   // isOn && isAtMinimum

func setEnabled(_ isOn: Bool, _ topic: DefaultTopic)
func resetSuggestedTopics()
func removeCustomTopics(atOffsets: IndexSet)
func add()                            // local checks, then a review if needed
func cancelReview()
func save()                           // calls onSave(draft)
```

- `add()` maps `NewTopicCheck` to today's messages, unchanged and still localized: "That topic is already on your list.", "Topics must be between 2 and 60 characters.", "You can have up to 20 of your own topics.". A review failure shows "We couldn't check that topic. Please try again.".
- The review `Task` captures **`[weak self]`**. The ViewModel cancels the task in `isolated deinit`, replacing the private `Review` class. The `onDisappear` caveat in the current `Review` comment still applies: don't cancel the task from `onDisappear`.
- The review uses the age group from the moment `add()` was called, as today.

### 5.4 Views

| View | Change |
|---|---|
| `MyApp` | Builds the repositories, `QuizViewModel` and `RootViewModel` in a `@State`, then `RootView(viewModel:)`. Keeps the `--leo-running-tests` guard. No `.environment(store)`. |
| `RootView` | `RootView(viewModel: RootViewModel)`. Switches on `viewModel.availability` instead of `SystemLanguageModel`. No longer imports FoundationModels. Presents `SettingsView(viewModel: root.makeSettingsEditor()!)` and `OnboardingView(viewModel: root.makeOnboardingEditor())`. |
| `UnavailableView` | Takes `ModelUnavailableReason`. Same strings. `.other` uses the current `@unknown default` text. |
| `OnboardingView` | `init(viewModel:)` stored in `@State`. Keeps `selection` and `isShowingTopics` as view state. Continue sets `viewModel.draft.ageGroup`. Done calls `viewModel.save()`. |
| `SettingsView` | `init(viewModel:)` stored in `@State`. Picker binds `$viewModel.draft.ageGroup`. Done calls `viewModel.save()` then `dismiss()`. Cancel only dismisses. |
| `TopicsEditor` | `@Bindable var viewModel: PreferencesEditorViewModel`. No logic left beyond layout and bindings. |
| `ExerciseView` | Uses `quiz.optionState(at:)` and `quiz.isAnswerCorrect`. |
| `WelcomeView`, `LoadingView`, `ResultView` | Unchanged. |

Previews build the real implementations, using `UserDefaults(suiteName: "preview")` for preferences, as today. No preview fakes in the app target.

## 6. Pull requests

Each pull request builds, passes SwiftLint, SwiftFormat and the `Leo` test plan, and leaves `LeoTestsSnapshots/` untouched apart from the two new references in PR 4. Every PR includes its tests: a PR without tests for its new logic is not done.

### PR 1: Folder structure and renames, no logic changes

Changes:

- Create `App/`, `Domain/`, `Data/`, `Features/` and move the files as in section 4.
- Split `ComprehensionSkill` and `RoundSettings` into their own files.
- Move `GeneratedExercise`, `Exercise.init?(generated:…)` and the prompt prose to `Data/FoundationModels/`, using `nonisolated extension`.
- Rename `QuizModel` → `QuizViewModel`.
- Move the test files into `Domain/`, `Data/` and `Features/`. Rename `QuizModelTests` → `QuizViewModelTests`. Snapshot test files keep their names (section 3).
- Update the README's "Project structure" section and its source links (`ExerciseGenerator`, `GeneratedExercise`, `ContentLanguage`, `TopicValidator`).

Tests:

- Only renames and moves. No test logic changes.

Acceptance:

- `git diff --stat main -- LeoTestsSnapshots` is empty.
- The same number of tests run and pass as on `main`.
- `grep -l "import FoundationModels\|import SwiftUI" Leo/Domain` finds nothing.

### PR 2: ExerciseRepository and option state in QuizViewModel

Changes:

- `ExerciseGenerating` → `ExerciseRepository`, plus `FoundationModelsExerciseRepository`.
- `QuizViewModel(makeRepository:)` with no default value. `MyApp` (or `RootView` until PR 3) supplies the live factory.
- Add `OptionState`, `optionState(at:)` and `isAnswerCorrect`, and use them in `ExerciseView`.

Tests:

- `Support/StubGenerator.swift` → `Support/StubExerciseRepository.swift` (`StubExerciseRepository`, `ExerciseRepositoryFactorySpy`). The behavior doesn't change.
- Update `QuizViewModelTests` and `ExerciseViewSnapshotTests` for the new names. The starting-state tests pass `{ _ in StubExerciseRepository() }`.
- New in `QuizViewModelTests`:
  - `optionStatesBeforeAnswering`: all options `.idle`, `isAnswerCorrect == nil`.
  - `optionStatesAfterCorrectAnswer`: the correct option is `.correct`, the others `.dimmed`, `isAnswerCorrect == true`.
  - `optionStatesAfterWrongAnswer`: the picked option is `.incorrect`, the correct one `.correct`, the rest `.dimmed`, `isAnswerCorrect == false`.
  - `optionStatesResetOnNext`: back to `.idle` after `next()`.
- New `Data/FoundationModelsExerciseRepositoryTests`:
  - `usesRoundAgeGroupAndLanguage`: `FoundationModelsExerciseRepository(ageGroup: .nine, language: .english)` builds a generator with `.nine` and English.

Acceptance:

- The `ExerciseView` snapshot references are unchanged.

### PR 3: PreferencesRepository, RootViewModel and model availability

Changes:

- Add `PreferencesRepository` and `UserDefaultsPreferencesRepository`, and delete `PreferencesStore`.
- Add `ModelAvailability`, `ModelAvailabilityProvider` and `SystemModelAvailabilityProvider`. `UnavailableView` takes `ModelUnavailableReason`.
- Add `RootViewModel` (without the editor factories yet), and make `MyApp` the composition root.
- Interim step: `OnboardingView` and `SettingsView` get an `onSave: (ReaderPreferences) -> Void` parameter instead of reading the store from the environment. PR 4 replaces it with the editor ViewModel.

Tests:

- `Data/UserDefaultsPreferencesRepositoryTests`, ported from `PreferencesStoreTests` using `TestDefaults`:
  - `emptySuiteLoadsNil`
  - `savesAndLoads`: round trip with disabled and custom topics.
  - `corruptDataLoadsNil`
  - `loadsVersion1Data`: `{"ageGroup":"12-14"}`.
  - `usesReaderPreferencesKey`: the key is still `readerPreferences`, so existing installs keep their settings.
- New `Support/PreferencesRepositorySpy`: in-memory, records each save.
- New `Support/StubModelAvailabilityProvider`: a settable `availability`.
- New `Features/RootViewModelTests`:
  - `loadsPreferencesAtInit`: `nil` and non-`nil` cases.
  - `saveSetsAndPersists`
  - `savingEqualPreferencesDoesNotPersist`: replaces `PreferencesStoreTests.equalValueIsNotRewritten`.
  - `preferencesDidChangeConfiguresQuiz`: the factory spy receives `preferences.roundSettings`.
  - `preferencesDidChangeWithoutPreferencesDoesNothing`
  - `preferencesDidChangeWithSameSettingsKeepsRound`: the factory is called once.
  - `availabilityFollowsProvider`: changing the stub changes the ViewModel's value.
- New `Data/ModelAvailabilityTests`:
  - Each `SystemLanguageModel.Availability` case maps to its `ModelAvailability` case.
- Update `OnboardingSnapshotTests`, `SettingsViewSnapshotTests` and `UnavailableViewSnapshotTests` constructors. They no longer need `PreferencesStore` in the environment.

Acceptance:

- The snapshot references are unchanged.
- Settings and onboarding still save, and a fresh launch still skips onboarding: checked by hand on the simulator.

### PR 4: Topic editing rules, TopicReviewRepository and PreferencesEditorViewModel

Changes:

- Add the `ReaderPreferences` topic editing rules (section 5.1).
- Add `TopicReviewOutcome`, `TopicReviewRepository` and `FoundationModelsTopicReviewRepository`. `TopicValidator.review` returns `TopicReviewOutcome`.
- Add `PreferencesEditorViewModel`, and the editor factories on `RootViewModel`.
- `TopicsEditor`, `SettingsView` and `OnboardingView` use the ViewModel. Delete the private `Review` class and the interim `onSave` parameters.

Tests:

- New `Domain/ReaderPreferencesTopicEditingTests`:
  - `enabledTopicCount`: counts enabled suggested topics plus custom topics, for the given group only.
  - `isAtMinimum`: true at exactly 3 enabled, false at 4. Custom topics count.
  - `matchIgnoresCaseAndAccents`: for example "DINOSAURS" and "dinosaurs" in `.six` match the suggested topic. A custom "Música" matches "musica".
  - `matchReportsDisabledSuggestedTopic`: returns `.disabledDefault(id:)`.
  - `checkOrder`: an invalid length wins over a duplicate, a duplicate over re-enabling, and re-enabling over the custom-topic limit (at 20 custom topics, a disabled suggested topic can still be re-enabled).
  - `checkLengthBoundaries`: 1 and 61 characters are `.invalidLength`, 2 and 60 are not.
  - `checkTooManyCustomTopics`: 20 custom topics gives `.tooManyCustomTopics`.
  - `insertTopicAppendsCustom`, `insertTopicReEnablesSuggested`, `insertTopicRejectsEnabledDuplicate`
  - `resetSuggestedTopicsOnlyAffectsGroup`
  - `removeCustomTopicsAtOffsets`
  - `setEnabled`: turns off and back on, and turning on an already enabled topic is a no-op.
- New `Support/StubTopicReviewRepository`: same pattern as `StubExerciseRepository`. It records `(text, group)` calls, answers scripted results or waits until resumed, counts cancellations, and has an `ignoresCancellation` option.
- New `Features/PreferencesEditorViewModelTests`:
  - `startingState`: the draft is as given, with an empty field, no message and no review.
  - `addEmptyDoesNothing`: whitespace only, no review call, no message.
  - `addTrimsBeforeReview`: the stub receives the trimmed text.
  - `addInvalidLengthShowsMessage`: no review call.
  - `addEnabledDuplicateShowsMessage`: no review call. Covers a suggested topic and a custom topic.
  - `addDisabledSuggestedReEnablesWithoutReview`: the field is cleared.
  - `addOverCustomLimitShowsMessage`: no review call.
  - `acceptedReviewAddsPhrase`: the cleaned phrase is added under the right group, the field is cleared and there's no message.
  - `acceptedPhraseAlreadyOnListShowsMessage`: for example "dinos" becomes "Dinosaurs". The field is kept.
  - `acceptedPhraseReEnablesSuggested`
  - `rejectedReviewShowsReason`: the field and the topics are unchanged.
  - `failedReviewShowsGenericMessage`
  - `isReviewingWhilePending` and `addWhileReviewingIsIgnored`: the stub is called once.
  - `changingAgeGroupCancelsReview`: the stub counts one cancellation, no topic is added to either group, no message is shown and `isReviewing` is false.
  - `lateResultAfterCancelIsDropped`: uses the `ignoresCancellation` stub.
  - `reviewUsesGroupAtTimeOfAdd`
  - `editingFieldClearsMessage`
  - `deinitCancelsReview`: the ViewModel is released while a review is pending, and the stub counts one cancellation. This guards the `[weak self]` capture.
  - `toggleDisabledAtMinimum`, `resetSuggestedTopics`, `removeCustomTopics`: these delegate to the domain rules.
  - `saveCallsOnSaveWithDraft`: called exactly once.
- Additions to `RootViewModelTests`:
  - `settingsEditorStartsFromCurrentPreferences`
  - `settingsEditorSaveGoesThroughRoot`: the value is persisted once.
  - `onboardingEditorSaveEndsOnboarding`: `preferences` becomes non-`nil`.
  - `settingsEditorIsNilBeforeOnboarding`
- Update `TopicValidatorTests` to use `TopicReviewOutcome`. The live tests compile unchanged, apart from the outcome type.
- Update `TopicsEditorSnapshotTests`, `SettingsViewSnapshotTests` and `OnboardingSnapshotTests` to build `PreferencesEditorViewModel` with a stub, using a `Support` fixture. The existing references stay unchanged.
- New snapshot cases in `TopicsEditorSnapshotTests`, recorded once in this PR:
  - `withMessage`: after a rejected review, the red message is visible.
  - `reviewing`: a pending review shows the progress indicator and a disabled field. If the spinner makes the image flaky, drop this case and rely on `isReviewingWhilePending`.

Acceptance:

- The existing snapshot references are unchanged. The only new files under `LeoTestsSnapshots/` are the two new references.
- Checked by hand on the simulator: adding a topic, rejection, a duplicate, changing the age group during a review, and closing Settings during a review.

### PR 5: Guard the boundaries and update the docs

Changes:

- Add a SwiftLint `custom_rules` entry that forbids `import SwiftUI`, `import UIKit` and `import FoundationModels` in `Leo/Domain/`, and one that forbids `import FoundationModels` in `Leo/Features/`.
- README: describe the architecture in "Project structure", with one line per layer.
- `.github/workflows/claude-review.yml`: add one sentence about the layers to the review prompt, so reviews flag views that call repositories directly.

Tests:

- None new. The lint rules run in CI and in the build phase.

## 7. Test doubles summary

| Double | Replaces | Used by |
|---|---|---|
| `StubExerciseRepository` | `StubGenerator` | `QuizViewModelTests`, `RootViewModelTests`, `ExerciseViewSnapshotTests` |
| `ExerciseRepositoryFactorySpy` | `GeneratorFactorySpy` | same |
| `StubTopicReviewRepository` | new | `PreferencesEditorViewModelTests`, `RootViewModelTests`, preference snapshots |
| `PreferencesRepositorySpy` | `TestDefaults` + `PreferencesStore` in VM tests | `RootViewModelTests` |
| `StubModelAvailabilityProvider` | new | `RootViewModelTests` |

`TestDefaults` stays for `UserDefaultsPreferencesRepositoryTests`. As today, every test suite that touches app types is `@MainActor`, and async ViewModel tests use `waitUntil` and `settle`.

## 8. Behavior

### 8.1 Behavior to preserve, each with a test that guards it

| Behavior | Guarded by |
|---|---|
| A round is generated before the reader taps Start | `QuizViewModelTests.generatesWholeRoundBeforeStart` |
| Saving unchanged settings keeps the prepared round | `RootViewModelTests.preferencesDidChangeWithSameSettingsKeepsRound`, `QuizViewModelTests.configureWithSameSettingsKeepsRound` |
| A newer round or a retry cancels the old generation, and its late results are ignored | `QuizViewModelTests.lateResultOfEarlierRoundIsNotShown` |
| The device language is picked once per round | `FoundationModelsExerciseRepositoryTests`, and the factory spy getting one call per round |
| A topic review is cancelled when the age group changes or the editor goes away | `changingAgeGroupCancelsReview`, `deinitCancelsReview` |
| Nothing in Settings is saved until Done | `saveCallsOnSaveWithDraft` (only `save()` calls `onSave`) |
| Saved preferences keep their key and format | `usesReaderPreferencesKey`, `ReaderPreferencesTests.savedFormat` |
| The UI looks the same | every existing snapshot reference, unchanged |

### 8.2 Intentional change

- `PreferencesStore` removed the saved data when encoding failed. `UserDefaultsPreferencesRepository` logs the failure and keeps the existing data. Encoding `ReaderPreferences` can't fail in practice. Setting preferences to `nil`, which only the tests used, is no longer supported.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Availability updates stop reaching `RootView` | The provider reads `SystemLanguageModel.default.availability` on every access and never caches it (section 5.2). Check by hand by turning Apple Intelligence off and on while the app runs. |
| A retain cycle keeps `PreferencesEditorViewModel` alive, so the review isn't cancelled | `[weak self]` in the review task, guarded by `deinitCancelsReview`. |
| Members moved to another file become main-actor isolated | Use `nonisolated extension` (section 3). The compiler flags misuse from `nonisolated` code. |
| Snapshot references move or change | Don't rename snapshot test files. Each PR checks `git diff --stat main -- LeoTestsSnapshots`. |
| `@State` holding a ViewModel built in `init` is rebuilt on every parent update | ViewModel inits have no side effects, and SwiftUI keeps the first instance. Nothing starts until a method is called. |
| Large diffs hide behavior changes | Five PRs, the first with moves and renames only. |
