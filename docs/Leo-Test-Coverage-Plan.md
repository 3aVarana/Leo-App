# Leo Test Coverage Plan: Unit and Snapshot Tests

## 1. Scope

Leo has zero test coverage. Before adding features, this plan adds:

1. Unit tests (Swift Testing) for the models, services and round logic.
2. Snapshot tests (Swift Testing + swift-snapshot-testing) for the views, in light/dark mode and at an accessibility text size, in English.
3. An opt-in suite that exercises the real on-device model, for prompt tuning.
4. A small set of approved code changes that make the round logic and the remaining views testable, and keep the test host app from running its UI.

Out of scope: UI tests (XCUITest), `RootView` snapshots, the CI workflow itself (its requirements are in section 12), coverage gates. Testing the app's Spanish and Brazilian Portuguese localizations is deferred (section 11).

## 2. Agreed decisions

| Area | Decision |
|---|---|
| Unit test framework | Swift Testing only (`import Testing`). No XCTest test cases. |
| Snapshot framework | Point-Free's [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing), 1.17.0 or later, linked to the `LeoTests` target only. Used from `@Test` functions. The record mode comes from `SNAPSHOT_TESTING_RECORD`, not from a trait (section 4.2). |
| Approved code changes | **A** QuizModel generator seam, **B** pure round-plan function, **C** TopicValidator outcome mapping, **D** internal prompt building in ExerciseGenerator, **E** test-host guard in `MyApp`, **F** non-random `Exercise` init, **G** internal `UnavailableView`. See section 6. |
| Live model suite | Included, opt-in only: tagged `.liveModel`, runs only when the model is available, excluded from the default test plan, never blocks a merge. |
| Questionable current behavior | Lock the current behavior in tests, no app changes: `Exercise` accepts an empty title; `ContentLanguage.name` returns "Unknown language" for identifiers like `und`. |
| Languages tested | **English only.** The test plans have a single configuration with Application Language English and Region United States. Spanish and Brazilian Portuguese UI testing is deferred (section 11). |
| Non-English exercise content | The language the model writes in is still covered where it is pure logic: `ContentLanguage.name` for non-English locales, and the check that prompts include `language.name` (with English and Spanish). Live generation in Spanish is deferred. |
| Snapshot device | One pinned simulator: iPhone 18 Pro, iOS 27.0. Images differ across devices and OS versions. |
| Actor isolation in tests | Annotate suites that touch app types with `@MainActor` (the app target defaults to `MainActor`, the test target does not). No build-setting change. |

## 3. Project facts relevant to implementation

- Xcode 27.0. App deployment target 26.6, project default 27.0 (the test target inherits 27.0).
- App target: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_VERSION = 5.0`.
- Test target `LeoTests` (bundle id `com.aranasoft.LeoTests`): hosted by `Leo.app` (`TEST_HOST` / `BUNDLE_LOADER`), no default actor isolation, `ENABLE_TESTABILITY = YES` in Debug. Import the app with `@testable import Leo`.
- Both `Leo/` and `LeoTests/` are **file-system synchronized groups**: any file added to `LeoTests/` is compiled or bundled automatically.
- The `Leo` scheme has no test plan (`shouldAutocreateTestPlan = YES`) and **code coverage is off**.
- Only one test file exists: the `LeoTests/LeoTests.swift` placeholder (to be deleted).
- Localizations: en (source), es, pt-BR in `Leo/Localizable.xcstrings`. This plan tests English only.
- Simulator: iPhone 18 Pro on iOS 27.0. The iPhone 17 family runs iOS 26.4/26.5. On this Mac, `SystemLanguageModel.default.availability` is `.available` in the simulator.

### 3.1 Verified with a probe test (deleted after the analysis)

- `GeneratedExercise` keeps its memberwise init despite `@Generable`, so tests can build model output directly:
  `GeneratedExercise(title:passage:question:correctAnswer:incorrectAnswers:explanation:)`.
- `TopicReview` can be built with `try TopicReview(GeneratedContent(properties: ["isSuitable": true, "topic": "Dinos!", "reason": ""]))`. It likely also has a memberwise init (not verified).
- Setting `LocalizedStringResource.locale` returns translations: `DefaultTopics.topics(for: .six)[0].name` gives "Mascotas y animales de granja" (es) and "Animais de estimação e da fazenda" (pt-BR). `Bundle.main.localizations` is `["es", "pt-BR", "en"]`.
- `ContentLanguage(locale:).name` returns:

  | Identifier | Name |
  |---|---|
  | `en_US` | English |
  | `es_BO` | Spanish |
  | `pt_BR` | Portuguese |
  | `zh-Hans-CN` | Chinese |
  | `zh-Hant-TW`, `zh_TW` | Chinese, Traditional |
  | `sr-Latn-RS` | Serbian (Latin) |
  | `sr-Cyrl` | Serbian |
  | `ja_JP` | Japanese |
  | `""` | English |
  | `und` | Unknown language |

- `String.wordCount` returns:

  | Input | Count |
  |---|---|
  | `""` | 0 |
  | `"Hello world."` | 2 |
  | `"Don't stop, it's 3:45 p.m."` | 6 |
  | `"  a\n\nb  "` | 2 |
  | `"猫が好きです。犬も好きです。"` | 8 (depends on the OS's word breaking; assert a lower bound) |
  | `"e-mail well-known"` | 4 (hyphens split words) |

- `QuizModel()` starts in `.welcome` with `isLastExercise == false`.

## 4. Test infrastructure (configuration, no app code)

### 4.1 Swift package

Add `https://github.com/pointfreeco/swift-snapshot-testing`, "Up to Next Major" from `1.17.0`. Link the `SnapshotTesting` product to **LeoTests only**, never to `Leo`.

### 4.2 Snapshot reference images

- References are stored in `LeoTestsSnapshots/<TestFile>/` at the repo root, outside `LeoTests/`. Commit them to git.
- By default swift-snapshot-testing writes them to `__Snapshots__/<TestFile>/` next to the test file. Inside `LeoTests/`, a synchronized folder, Xcode would add them to the test target and copy them into the test bundle. That bundle is installed on every test run, and the tests never read those copies; they read the references from the source tree. Copying also drops the `<TestFile>` folder, so two files with the same name would cause "Multiple commands produce" build errors.
- Excluding the folders from the target instead turned out to be fragile in Xcode 27. A membership exception on a plain folder doesn't apply to the files inside it, so each folder had to be listed in both `explicitFolders` and the membership exceptions. Xcode also drops those entries while the folder doesn't exist yet. A folder outside `LeoTests/` needs no project entries.
- **Every snapshot test calls `assertReferenceSnapshot` or `assertViewSnapshot` (section 5.3), never `assertSnapshot` directly.** Both pass `snapshotDirectory:` so references land in `LeoTestsSnapshots/`.
- No suite sets a `.snapshots(record:)` trait: a trait overrides `SNAPSHOT_TESTING_RECORD`, so the variable would stop working. The default mode is `missing`: missing images are recorded and the test fails once, then passes.
- `Leo.xctestplan` passes `SNAPSHOT_TESTING_RECORD=$(SNAPSHOT_TESTING_RECORD)` to the tests, so the mode is set from the command line as a build setting: `xcodebuild test … SNAPSHOT_TESTING_RECORD=all` re-records every image, and `=never` (for CI) fails on a missing reference without writing it. Unset, the default applies. (`SIMCTL_CHILD_SNAPSHOT_TESTING_RECORD` doesn't reach the hosted tests.)
- The references are found from `#filePath`, which is fixed when the tests are compiled. Build and run the tests on the same machine, from the same checkout: don't split `build-for-testing` and `test-without-building` across machines. `assertReferenceSnapshot` fails with a clear message when `LeoTestsSnapshots/` isn't found.
- `.gitattributes` marks `LeoTestsSnapshots/**` as `binary linguist-generated`, so git doesn't try to merge the images and GitHub collapses them in diffs.
- `SnapshotLayoutTests` fails when two test files share a name, because they would share a reference folder.

### 4.3 Test plans and coverage

Create two test plans in the project root and attach both to the `Leo` scheme. `Leo` is the default.

Both plans use a single configuration, **English**: Application Language English, Region United States. Both pass the launch argument `--leo-running-tests` ("Arguments Passed On Launch"), which turns on change **E** (section 6).

**`Leo.xctestplan`** (default)
- Target: `LeoTests`.
- Code coverage: on, gathered for the `Leo` target only.
- Exclude tag: `liveModel`.

**`LeoLiveModel.xctestplan`** (opt-in)
- Target: `LeoTests`.
- Include tag: `liveModel`.
- Code coverage: off.
- Execution time allowance on.

Rules that keep adding Spanish and Portuguese later cheap (section 11):

- Where a unit test checks a localized value, compare it against a `String(localized:)` lookup rather than an English literal.
- Snapshot names include the app language (`Bundle.main.preferredLocalizations.first`, always `en` for now). Adding configurations later then doesn't rename or overwrite existing references.

**Verify on first use:** test-plan tag include/exclude for Swift Testing. If Xcode 27 doesn't apply it, fall back to `-skip-testing:LeoTests/<LiveSuite>` in the default plan and `-only-testing:` in the live plan.

### 4.4 Test host app launch (change E)

Hosted tests launch the full app (`MyApp`) before running. Without **E**, two things would go wrong:

1. **Real generation during tests.** `RootView` reads `UserDefaults.standard`. If the simulator has finished onboarding, it calls `quiz.configure(...)` and starts generating exercises with the on-device model while tests run. This makes tests slower and makes live-model tests compete for the model.
2. **Inflated coverage.** `RootView` and `OnboardingView` would run at launch and show coverage without any checks.

With **E**, `MyApp` shows an empty window when it receives `--leo-running-tests`, so neither happens. Any simulator can be used, onboarded or not.

Tests must still **never** read or write `UserDefaults.standard`. Every store under test uses its own suite (section 5.1).

### 4.5 File layout

Delete `LeoTests/LeoTests.swift`. Create:

```
LeoTests/
  Support/
    Tags.swift                 // extension Tag { @Tag static var liveModel, snapshot }
    TestEnvironment.swift      // appLanguage, isModelAvailable
    TestDefaults.swift         // isolated UserDefaults suite + cleanup
    Fixtures.swift             // GeneratedExercise / Exercise / ReaderPreferences builders
    SplitMix64.swift           // seeded RandomNumberGenerator (for B)
    StubGenerator.swift        // ExerciseGenerating fake + factory spy (for A)
    WaitUntil.swift            // await a condition on the main actor with a timeout
    SnapshotHelpers.swift      // assertReferenceSnapshot(...), assertViewSnapshot(...)
    SnapshotLayoutTests.swift  // test file names are unique (one reference folder per file)
  Models/
    AgeGroupTests.swift
    ExerciseTests.swift
    WordCountTests.swift
    ReaderPreferencesTests.swift
    DefaultTopicsTests.swift
  Services/
    ContentLanguageTests.swift
    PreferencesStoreTests.swift
    QuizModelTests.swift          // guards first; full state machine after A
    QuizPlanTests.swift           // after B
    TopicValidatorTests.swift     // after C
    ExerciseGeneratorPromptTests.swift  // after D
  Snapshots/
    ResultViewSnapshotTests.swift
    WelcomeViewSnapshotTests.swift
    LoadingViewSnapshotTests.swift
    OnboardingSnapshotTests.swift
    TopicsEditorSnapshotTests.swift
    SettingsViewSnapshotTests.swift
    UnavailableViewSnapshotTests.swift  // after G
    ExerciseViewSnapshotTests.swift     // after A + F
  LiveModel/
    ExerciseGeneratorLiveTests.swift
    TopicValidatorLiveTests.swift
LeoTestsSnapshots/             // reference snapshots, one folder per test file (section 4.2)
```

## 5. Support code (test target only)

### 5.1 `TestDefaults`

```swift
/// A UserDefaults suite of its own, removed when the test ends.
struct TestDefaults: ~Copyable {
    let suiteName = "LeoTests.\(UUID().uuidString)"
    var defaults: UserDefaults { UserDefaults(suiteName: suiteName)! }
    deinit { UserDefaults().removePersistentDomain(forName: suiteName) }
}
```

Any equivalent works, as long as each test has a unique suite (Swift Testing runs tests in parallel) and the suite is removed.

### 5.2 `Fixtures`

- `GeneratedExercise.fixture(title:passage:question:correctAnswer:incorrectAnswers:explanation:)` with valid defaults. The default passage has a word count inside `AgeGroup.six.acceptedWordCount` (for example, 60 words).
- `String.words(_ n: Int)`: a passage of exactly `n` words, used for the word-count limit tests.
- `Exercise.fixture(...)`: built with the non-random init from **F**, with fixed options and `correctIndex`.

### 5.3 `SnapshotHelpers`

`assertReferenceSnapshot(of:as:named:fileID:filePath:testName:line:column:)`:

- Calls `verifySnapshot` with `snapshotDirectory` set to `LeoTestsSnapshots/<TestFile>/`. The repo root is found from the helper's own `#filePath`.
- Records a failure with `Issue.record` at the caller's source location. Record mode comes from `SNAPSHOT_TESTING_RECORD` (section 4.2).
- Used directly by the text snapshots (`.lines`, `.json`).

`assertViewSnapshot(of view: some View, named: String, colorScheme: UIUserInterfaceStyle = .light, sizeCategory: UIContentSizeCategory = .large, fileID:filePath:testName:line:column:)`:

- Fails with one clear message, without comparing, when it doesn't run on the iPhone 18 Pro simulator (`iPhone19,2`) with iOS 27.0, the environment the references were recorded on.
- Wraps the view in `UIHostingController`. `ImageRenderer` can't be used, because it doesn't draw `List`, `Form`, `NavigationStack` or `ProgressView`.
- Calls `assertReferenceSnapshot(of:as: .image(on: .iPhone13Pro, precision: 0.99, perceptualPrecision: 0.98, traits: …))`. Any fixed `ViewImageConfig` is fine; keep one for every test.
- Adds the app language to the snapshot name: `"\(named)-\(TestEnvironment.appLanguage)"` (always `en` for now; see section 4.3).
- Passes through `fileID`/`filePath`/`testName`/`line`/`column`, so references are filed under the calling test's file and failures point at the calling line.
- Views that read `@Environment(PreferencesStore.self)` get `.environment(PreferencesStore(defaults: testDefaults.defaults))`.

### 5.4 `WaitUntil` (for A)

```swift
@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool,
               sourceLocation: SourceLocation = #_sourceLocation) async
```

Repeats `await Task.yield()` until the condition holds. If the timeout passes first, it records an `Issue`. `QuizModel` generates in an unstructured `Task`, so tests need this to observe its state changes.

### 5.5 `StubGenerator` (for A)

- `@MainActor final class StubGenerator: ExerciseGenerating` that records each call's `(topics, skill)`.
- Two modes:
  - **Scripted:** a queue of `Result<Exercise, Error>` returned immediately, in order.
  - **Controlled:** each call suspends on a `CheckedContinuation` that the test resumes. Needed for the "start before the exercise is ready" and "cancelled generation" tests.
- Cancellation: when the calling task is cancelled, the call throws `CancellationError` (use `withTaskCancellationHandler`), so tests can confirm a new round cancelled the old one.
- `GeneratorFactorySpy` records the `RoundSettings` of every factory call and hands out the stubs.

## 6. Approved code changes

Make each change in its own commit, with its tests in the same commit. App behavior must not change.

### A. `QuizModel` generator seam — `Leo/Services/QuizModel.swift`, `Leo/Services/ExerciseGenerator.swift`

```swift
/// Generates one exercise. `ExerciseGenerator` is the real implementation.
protocol ExerciseGenerating {
    func generate(topics: [String], skill: ComprehensionSkill) async throws -> Exercise
}

extension ExerciseGenerator: ExerciseGenerating {}
```

In `QuizModel`:

- `init(makeGenerator: @escaping (RoundSettings) -> any ExerciseGenerating = { ExerciseGenerator(language: .current(), ageGroup: $0.ageGroup) })`. The default keeps today's behavior: language picked per round in `prepareRound()`.
- Replace `private var generator = ExerciseGenerator(language: .english, ageGroup: .fifteen)` with `private var generator: (any ExerciseGenerating)?`, set in `prepareRound()` from `makeGenerator(settings)`.
- `RootView` keeps `QuizModel()` unchanged.
- The protocol and `QuizModel` keep the default `MainActor` isolation, as `ExerciseGenerator` has today. No `Sendable` requirement.

### B. Pure round plan — `Leo/Services/QuizModel.swift`

- Replace the tuple `(topics: [String], skill: ComprehensionSkill)` with `struct PlanItem: Equatable { var topics: [String]; var skill: ComprehensionSkill }`.
- Move the body of `prepareRound()` that builds the plan into:

```swift
/// The topics and skill for each exercise of a round. See the rules in `prepareRound()`.
static func makePlan(topics: [String], using rng: inout some RandomNumberGenerator) -> [PlanItem]
```

- `prepareRound()` calls it with a `SystemRandomNumberGenerator`.
- All randomness in it (topic shuffle, skill shuffles, spare picks) uses `rng`, so a seeded generator in tests gives a repeatable plan.
- `retry()` is unchanged apart from using `PlanItem`.

### C. TopicValidator outcome mapping — `Leo/Services/TopicValidator.swift`

```swift
/// Turns the model's review into what the reader sees.
static func outcome(for review: TopicReview) -> Outcome
```

Holds the existing logic: trim whitespace and punctuation from `topic`, return `.rejected` with the trimmed reason or `genericRejection` when not suitable or the topic is empty, otherwise `.accepted`. `review(_:for:)` calls it. The error mapping (guardrail/refusal → generic rejection) stays in `review`.

### D. Internal prompt building — `Leo/Services/ExerciseGenerator.swift`

- `wordRange` and `instructions`: `private` → internal.
- Extract the inline prompt from `generate` into `func prompt(topic: String, skill: ComprehensionSkill) -> String`, used by `generate`.
- `maxAttempts`, `maxResponseTokens`, `respond` and `RunawayPassage` stay private.

### E. Test-host guard — `Leo/MyApp.swift`

```swift
@main struct MyApp: App {
    @State private var store = PreferencesStore()

    /// Passed by the test plans, so the test host doesn't show the app or start generating exercises.
    private let isRunningTests = ProcessInfo.processInfo.arguments.contains("--leo-running-tests")

    var body: some Scene {
        WindowGroup {
            if isRunningTests {
                EmptyView()
            } else {
                RootView()
                    .environment(store)
            }
        }
    }
}
```

- A launch argument, not `XCTestConfigurationFilePath` or a check for loaded XCTest classes, so the switch is explicit and only set by the test plans.
- Use `--` (two dashes). With a single dash, `NSArgumentDomain` treats the argument as a `UserDefaults` key.
- `PreferencesStore()` is still created. It only reads `UserDefaults.standard`, which is harmless, and tests never use that store.
- Production behavior is unchanged: the argument is never passed outside the test plans.

### F. Non-random `Exercise` init — `Leo/Models/Exercise.swift`

```swift
/// Builds an exercise as given, without validation or shuffling. For tests and previews;
/// model output goes through `init?(generated:topic:skill:acceptedWordCount:)`.
init(topic: String, skill: ComprehensionSkill, title: String, passage: String,
     question: String, options: [String], correctIndex: Int, explanation: String)
```

With `precondition(options.indices.contains(correctIndex))`. `init?(generated:)` may delegate to it after validating and shuffling.

### G. Internal `UnavailableView` — `Leo/Views/RootView.swift`

`private struct UnavailableView` → `struct UnavailableView`. No other change.

## 7. Test catalog

Every suite that touches app types is `@MainActor`. Use parameterized `@Test(arguments:)` wherever a test checks a list of cases.

### 7.1 Phase 1 — unit tests that need no app code changes

**`AgeGroupTests`**
- Raw values are exactly `["6-8", "9-11", "12-14", "15-17", "18+"]`, in `allCases` order. They are dictionary keys in saved preferences.
- For every case, `acceptedWordCount` contains `passageWordRange`.
- `acceptedWordCount` values: six `30...120`, nine `48...180`, twelve `60...225`, fifteen `72...270`, adult `96...345`.
- The lower and upper bounds of `passageWordRange` never decrease from one age group to the next.
- `passageSentenceRange` is `10...13` for six, nine and twelve, and `nil` for fifteen and adult.
- `displayName`, `promptAudience` and `styleGuidance` are not empty for every case.

**`ExerciseTests`** (`Exercise.init?(generated:topic:skill:acceptedWordCount:)`)
- Valid input with 2 and with 3 distractors: options are distractors + correct (count 3 or 4), `options[correctIndex] == correct`, the correct answer appears exactly once, and `topic`/`skill` are copied.
- Leading and trailing whitespace and newlines are trimmed from title, passage, question, answers and explanation.
- Empty or whitespace-only distractors are dropped.
- Duplicate distractors are dropped, ignoring case ("Paris", "paris").
- A distractor equal to the correct answer, ignoring case, is dropped. When that leaves fewer than 2, the result is `nil`.
- 4 valid distractors → `nil`. 1 distractor → `nil`.
- Empty or whitespace-only correct answer → `nil`. Empty or whitespace-only question → `nil`.
- Passage word count (parameterized on `AgeGroup.six.acceptedWordCount`): 30 and 120 accepted; 29 and 121 rejected.
- Empty explanation is accepted and stored as `""`.
- **Locked current behavior:** an empty or whitespace-only title is accepted and stored as `""`.
- Position spread: build 200 exercises with 3 distractors; the correct answer lands in each of the 4 positions at least once. This guards that the app, not the model, decides the position. The chance of a false failure is about 4 × (3/4)^200, which is negligible.

**`WordCountTests`** (`String.wordCount`)
- Exact values from section 3.1 for `""`, `"Hello world."`, `"Don't stop, it's 3:45 p.m."` and `"  a\n\nb  "`.
- `"e-mail well-known"` is at least 2 (hyphen splitting is ICU behavior).
- The Japanese sample is greater than 1, which shows that word counting doesn't rely on spaces.
- `String.words(n).wordCount == n` for a few `n`, which checks the fixture itself.

**`ReaderPreferencesTests`**
- Decoding `{"ageGroup":"9-11"}` (V1-style data) gives `.nine` with empty `disabledDefaultTopics` and `customTopics`.
- Decoding an unknown age group (`{"ageGroup":"99"}`) throws.
- Encoding and then decoding gives an equal value (`Equatable`), including custom topic ids.
- Saved format: a text snapshot of the encoded JSON (`.json` strategy, sorted keys) for a value with disabled topics and custom topics in two groups. Dictionaries encode as objects keyed by `"6-8"` and so on. Any change to the saved format must show up in review.
- `isEnabled` is true by default. It is false after the topic id is added for that group, and still true in other groups.
- `enabledTopicPrompts(for:)`:
  - Suggested topics come first in `DefaultTopics` order, then custom topics in insertion order.
  - Disabled suggested topics are excluded.
  - Other groups' custom topics are excluded.
  - Disabled ids that don't exist are ignored.
  - With every suggested topic disabled and no custom topics, it falls back to all suggested prompts.
- `roundSettings` uses the current `ageGroup`. Equal preferences give equal `RoundSettings`, and turning one topic off changes them. `QuizModel.configure` relies on this to skip work.
- `minimumEnabledTopics == 3` and `maximumCustomTopics == 20`, which lock the documented limits.

**`DefaultTopicsTests`**
- For every age group: at least `ReaderPreferences.minimumEnabledTopics` topics, and at least 3 (one main topic plus 2 backups per exercise).
- Ids are unique within a group, not empty, and match `^[a-z0-9]+(-[a-z0-9]+)*$`.
- Prompts are not empty and unique within a group.
- Saved ids: a text snapshot (`.lines`) of the ids per group. The comment on `DefaultTopic.id` says "Never change it"; renaming or removing an id must fail this test. Adding a topic means re-recording on purpose.
- `ComprehensionSkill.allCases.count == 5`. `displayName` and `promptHint` are not empty.
- `ExerciseGenerationError.failed.errorDescription` is not empty.
- `CustomTopic` encode/decode keeps `id` and `name`.

**`ContentLanguageTests`** (`name`)
- Parameterized over the table in section 3.1, excluding `und`.
- **Locked current behavior:** `ContentLanguage(locale: Locale(identifier: "und")).name == "Unknown language"`.
- `ContentLanguage.english.locale.identifier == "en_US"`.
- Not tested: `current(model:)`. It depends on the device language and the real model, and `SystemLanguageModel` can't be faked.

**`PreferencesStoreTests`** (each test uses `TestDefaults`)
- Empty suite → `preferences == nil`.
- Setting preferences saves them. A new `PreferencesStore` on the same suite reads back an equal value, as after a relaunch.
- Setting `nil` removes the `readerPreferences` key.
- Corrupt data under `readerPreferences` → `preferences == nil`, no crash.
- V1-style data (`{"ageGroup":"12-14"}`) loads.
- Equal value not rewritten: save P, overwrite the key directly with other valid data Q, assign P again. The key still holds Q, which shows the `didSet` guard skipped the write.

**`QuizModelTests`** (part 1, before A)
- Starting state: `.welcome`, `currentIndex == 0`, `currentExercise == nil`, `selectedOption == nil`, `correctCount == 0`, `isLastExercise == false`.
- These do nothing and leave the starting state: `start()` before `configure`, `select(0)` with no current exercise, `next()` with nothing selected, `retry()` before `configure`.
- Do not call `configure` before A. It would start the real model.

### 7.2 Phase 2 — snapshot tests that need no app code changes

All snapshot suites are tagged `.snapshot`, run in English. "+ dark, + AX" means two extra variants: dark mode, and `.accessibilityExtraExtraExtraLarge`.

| Suite | Snapshots |
|---|---|
| `ResultViewSnapshotTests` | `correct` 6, 5, 3 and 0 of 6. Together these cover every symbol (star, thumbs up, book) and every message. 5/6 + dark, + AX. |
| `WelcomeViewSnapshotTests` | `.six` and `.adult` (different `displayName` lengths). `.six` + dark, + AX. |
| `LoadingViewSnapshotTests` | `index` 0 and 5 of 6. |
| `OnboardingSnapshotTests` | `AgeGroupPicker` with nothing selected (Continue disabled) and with `.twelve` selected, using a `@State`-backed binding host or `.constant`. `OnboardingView()` first screen, with a store on `TestDefaults`. Picker + dark, + AX. |
| `TopicsEditorSnapshotTests` | Inside `List`, with `.constant(preferences)`: (1) `.nine` defaults; (2) `.nine` with 2 custom topics and 2 suggested topics disabled ("Reset suggested topics" visible); (3) at the minimum: every suggested topic in `.six` disabled except 3, no custom topics (footer shown, enabled toggles disabled). (1) + dark. |
| `SettingsViewSnapshotTests` | `SettingsView(preferences:)` for `.twelve` with a custom topic, with a store on `TestDefaults`. + dark. |

Not covered by snapshots: `RootView` (depends on the device's model availability), the failed state inside `RootView`, and `TopicsEditor`'s error message and "checking topic" states (private `@State`, only reachable by typing).

### 7.3 Phase 3 — tests for changes B, C, D, G

**`QuizPlanTests`** (B, `QuizModel.makePlan`, seeded with `SplitMix64`)
- Always `QuizModel.exerciseCount` (6) items.
- Every `ComprehensionSkill` appears at least once.
- With 6 or more topics, the 6 main topics (`topics[0]`) are all different.
- With 3, 4 and 5 topics, no main topic repeats in two exercises in a row.
- Each item's backup topics differ from its main topic and from each other. With 3 or more topics, each item has exactly 3 topics.
- Every topic in the plan comes from the input.
- The same seed gives the same plan.
- Run the checks over seeds `0..<100` and topic counts `3...20`.
- **Recorded finding, not tested:** with exactly 2 topics, the formula `(i + i / count) % count` repeats a main topic back to back (exercises 1 and 2). This can't happen in the app, because the editor keeps at least 3 topics on and the fallback uses all suggested topics. Tests cover counts of 3 and above only.

**`TopicValidatorTests`** (C, `TopicValidator.outcome(for:)`)
- Suitable, "Dinos!" → `.accepted("Dinos")`. Whitespace and punctuation are trimmed at both ends ("  ¿Planetas?  " → "Planetas").
- Suitable but the topic is empty, or punctuation only → `.rejected(genericRejection)`.
- Not suitable with a reason → `.rejected(trimmed reason)`.
- Not suitable with an empty or whitespace-only reason → `.rejected(genericRejection)`.
- Compare against `String(localized:)` of the generic message rather than the English literal, so the test keeps passing when more languages are added.

**`ExerciseGeneratorPromptTests`** (D)
- `wordRange` for six, nine and twelve includes "in 10 to 13 sentences". Fifteen and adult don't include "sentences".
- `wordRange` includes the bounds and the midpoint, for example "between 50 and 80 words long, about 65 words".
- `instructions` contains `ageGroup.promptAudience`, `ageGroup.styleGuidance` and `language.name`, for English and for Spanish (`ContentLanguage(locale: Locale(identifier: "es_ES"))`).
- `prompt(topic:skill:)` contains the topic, `language.name`, `wordRange` and `skill.promptHint`.
- Prompt snapshots: a `.lines` text snapshot of `instructions` + `prompt(topic: "volcanoes", skill: .inference)` for each age group, in English. Prompt changes then show up in review. When prompts are tuned on purpose, re-record.

**`UnavailableViewSnapshotTests`** (G)
- `.deviceNotEligible`, `.appleIntelligenceNotEnabled`, `.modelNotReady`.

### 7.4 Phase 4 — tests for changes A and F

**`QuizModelTests`** (part 2, with `StubGenerator` and `GeneratorFactorySpy`)

- **Configure**
  - `configure(s)` calls the factory once with `s` and starts exercise 0 using plan item 0. The first topic is from `s.topics`.
  - `configure(s)` twice → the factory is called once (the prepared round is kept).
  - `configure(s2)` after `configure(s)` → the factory is called again. The earlier generation is cancelled, and its late result is never shown.
- **Generation order**
  - Generation is sequential: call k+1 starts only after call k returns.
  - All 6 are generated ahead of time without `start()`.
- **Start**
  - `start()` before exercise 0 is ready → `.loading`. When it arrives → `.answering`, with `currentExercise` being that exercise.
  - `start()` after it's ready → `.answering` immediately.
  - `start()` on a prepared round that hasn't started doesn't regenerate (factory count unchanged).
- **Answering**
  - Selecting the correct index → `correctCount == 1`, `selectedOption` set.
  - A second `select` is ignored.
  - Selecting a wrong index → `correctCount` unchanged.
- **Next**
  - `next()` moves to the next exercise and clears `selectedOption`. If that exercise isn't ready → `.loading`, then `.answering` when it arrives.
  - `isLastExercise` is true only at index 5. `next()` there → `.finished`.
  - After 6 answers, 4 of them correct → `correctCount == 4`.
- **Failure and retry**
  - Generation of exercise k fails while the reader waits for it → `.failed(ExerciseGenerationError.failed.localizedDescription)`, and no further generator calls.
  - Generation of exercise k fails while the reader is on an earlier exercise → the phase stays `.answering` until `next()` reaches k, then `.failed(...)`.
  - `retry()` → `.loading`. It calls the generator again for exercise k with up to 3 topics from the settings, and the original skill. On success → `.answering`.
  - `retry()` when all 6 are generated does nothing.
- **Practice again**
  - `start()` from `.finished` → the factory is called again (a new round), with `currentIndex == 0` and `correctCount == 0`.

**`ExerciseViewSnapshotTests`** (A + F; `Exercise.fixture` with fixed options; the quiz is driven to the state with `StubGenerator`)
- Before answering (exercise 1 of 6) + dark, + AX.
- Correct answer selected.
- Wrong answer selected, with an explanation.
- Wrong answer selected, with an empty explanation.
- Last exercise answered (button reads "See results").

### 7.5 Phase 5 — live model suite (opt-in)

Tags: `.liveModel`. Traits: `.enabled(if: TestEnvironment.isModelAvailable)` (`SystemLanguageModel.default.availability == .available`) and `.timeLimit(.minutes(1))`. Runs only from `LeoLiveModel.xctestplan`. Results vary between runs; a failure means "look at the prompts", not "the build is broken".

**`ExerciseGeneratorLiveTests`**
- For each `AgeGroup` (parameterized), `ExerciseGenerator(language: .english, ageGroup:)` generates, from 3 suggested topics for that group, an exercise whose passage word count is within `acceptedWordCount`. The init already checks this, so the test confirms the prompts produce usable output within 3 attempts.
- English only. Generation in Spanish is deferred (section 11).

**`TopicValidatorLiveTests`**
- "dinosaurs" for `.six` → `.accepted`, with no leading or trailing punctuation.
- "space exploration" for `.adult` → `.accepted`.
- A clearly unsuitable topic for `.six` (choose one at implementation time) → `.rejected` with a non-empty reason.

## 8. Implementation order

Each step builds, passes `Leo.xctestplan` on the iPhone 18 Pro (iOS 27.0) simulator, and is committed separately.

1. **E** + infrastructure: package, test plans (with `--leo-running-tests`), coverage on, delete the placeholder, add `Support/` (everything except `StubGenerator` and `WaitUntil`).
2. **Phase 1 unit tests** (7.1).
3. **Phase 2 snapshots** (7.2): record the English references and review every image before committing.
4. **B** + `QuizPlanTests`.
5. **C** + `TopicValidatorTests`.
6. **D** + `ExerciseGeneratorPromptTests`.
7. **G** + `UnavailableViewSnapshotTests`.
8. **F**, then **A** + `StubGenerator`, `WaitUntil`, `QuizModelTests` part 2, `ExerciseViewSnapshotTests`.
9. **Live model suite** (7.5) and a single run of `LeoLiveModel.xctestplan`.

## 9. Verification

Run the default plan and print coverage:

```bash
xcodebuild test -project Leo.xcodeproj -scheme Leo -testPlan Leo -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' -resultBundlePath build/Leo-tests.xcresult
```

```bash
xcrun xccov view --report --only-targets build/Leo-tests.xcresult
```

```bash
xcrun xccov view --report --files-for-target Leo.app build/Leo-tests.xcresult
```

When a test fails, `xcodebuild` collects simulator diagnostics, which can stall for 10 minutes. Add `-collect-test-diagnostics never` to skip it.

Run the live model suite (on demand):

```bash
xcodebuild test -project Leo.xcodeproj -scheme Leo -testPlan LeoLiveModel -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
```

Expected coverage once the plan is complete. These are not gates.

| File | Covered by | Left uncovered |
|---|---|---|
| `Models/*` | Unit tests | — |
| `Services/PreferencesStore.swift` | Unit tests | — |
| `Services/ContentLanguage.swift` | Unit tests | `current(model:)` (live suite only) |
| `Services/QuizModel.swift` | Unit tests (A, B) | Default generator factory closure |
| `Services/TopicValidator.swift` | `outcome(for:)` | `review` and the error mapping (live suite only) |
| `Services/ExerciseGenerator.swift` | Prompt building (D) | `generate` and `respond` (live suite only) |
| `Views/*` except `RootView` | Snapshots | `TopicsEditor` add/review flow; `ShakeEffect` animation |
| `Views/RootView.swift` | `UnavailableView` snapshots (G) | `RootView` itself |
| `MyApp.swift` | The test branch of **E** | The `RootView` branch |

Done when:
- Steps 1–9 are merged.
- `Leo.xctestplan` passes.
- `xccov` shows coverage for `Leo.app`, and `RootView`'s own body shows no coverage. That confirms **E** keeps the app UI from running during tests.
- The reviewed snapshot references are committed.
- The live suite has been run once and its results noted in the pull request.

## 10. Open items to confirm during implementation

All confirmed during implementation:

- Test-plan tag include/exclude for Swift Testing works in Xcode 27 (`skippedTags` / `selectedTags` on the test target). No fallback needed.
- "Arguments Passed On Launch" reaches the test host app: `RootView`'s body shows 0% coverage.
- Excluding `__Snapshots__` folders from the synchronized `LeoTests` folder needs `explicitFolders` plus a membership exception, and Xcode drops both while the folder doesn't exist. References were moved to `LeoTestsSnapshots/` instead (section 4.2).
- The unsuitable topic in `TopicValidatorLiveTests` is "gory horror movies" for `.six`.

Also found:

- Snapshots are drawn in the key window (`drawHierarchyInKeyWindow: true`). Drawing only the layer leaves the navigation bar's glass buttons unstyled, black on black in dark mode. Because tests share that window, the view snapshot suites are nested in one `.serialized` suite, `ViewSnapshots`.
- `assertViewSnapshot` takes an optional `height` to capture lists taller than the screen. Above about 2700 points the image comes out blank.
- At `.accessibilityExtraExtraExtraLarge`, `WelcomeView` truncates its description ("…about the topics you ch…"). Recorded as is; not fixed.

## 11. Deferred: Spanish and Brazilian Portuguese

Not part of this plan. Kept here so the work can be picked up later.

**Test-plan configurations.** Add configurations to `Leo.xctestplan`:

| Configuration | Application Language | Region |
|---|---|---|
| Spanish | Spanish | Spain |
| Portuguese (Brazil) | Portuguese (Brazil) | Brazil |

Use the Application Language setting, not `.environment(\.locale, …)` alone. `String(localized:)` (used by `ResultView.message`, `AgeGroup.displayName`, `ComprehensionSkill.displayName`) follows the app language, not the SwiftUI environment, so images would mix languages.

**Localized snapshots.**
- Record the section 7.2–7.4 snapshots in each language. Snapshot names already include the language (section 4.3).
- Limit the dark-mode and accessibility-size variants to English with `.enabled(if: TestEnvironment.appLanguage == "en")`, so they aren't tripled.

**`LocalizationTests`** (translation completeness)
- For each language in `["es", "pt-BR"]`, open `Bundle(path: Bundle.main.path(forResource: lang, ofType: "lproj")!)`. Every key below must be present, checked with `localizedString(forKey: key, value: "__missing__", table: nil) != "__missing__"`:
  - every `DefaultTopic.name.key` across all groups
  - the keys behind `AgeGroup.displayName`
  - the keys behind `ComprehensionSkill.displayName`
- Verify that the compiled string catalog answers in this way. If it doesn't, compare `String(localized:)` of the resource with `locale` set (verified to work, section 3.1) against the English value, with an allowlist for translations spelled the same as English.

**Live generation in Spanish.** Add to `ExerciseGeneratorLiveTests`: `ExerciseGenerator(language: ContentLanguage(locale: Locale(identifier: "es_ES")), ageGroup: .nine)` generates successfully.

## 12. CI requirements

The workflow itself is the next step and isn't part of this plan. This section records what the tests need from it. Items marked *unverified* haven't been tried.

### 12.1 Environment

- **Xcode 27.0, the iOS 27.0 simulator runtime and the iPhone 18 Pro simulator.** `assertViewSnapshot` fails with a clear message on any other device or iOS version (section 5.3). Select Xcode explicitly (`xcode-select` or `DEVELOPER_DIR`) and record the version in the repo, for example in an `.xcode-version` file.
- Apple Silicon runner. *Unverified* on Intel. The precision settings (0.99 and 0.98) absorb small rendering differences, but not a different OS version.
- *Unverified:* whether the hosted runner image already has Xcode 27.0 and the iOS 27.0 runtime. If not, use a self-hosted Mac. Xcode Cloud is another option, but it hasn't been checked that its build and test steps run on the same machine (see 12.2).
- The default plan doesn't use the on-device model, so a runner without Apple Intelligence is fine. `LeoLiveModel` is never run on CI by default: run it by hand (for example `workflow_dispatch`) on a Mac with the model available.

### 12.2 One job builds and tests

References are found from `#filePath`, which is fixed at compile time (section 4.2). Run `xcodebuild test` in one job, from one checkout. Don't split `build-for-testing` and `test-without-building` across machines or checkouts.

### 12.3 Command

```bash
rm -rf build
xcodebuild test \
  -project Leo.xcodeproj -scheme Leo -testPlan Leo \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  -resultBundlePath build/Leo-tests.xcresult \
  -collect-test-diagnostics never \
  -disableAutomaticPackageResolution \
  SNAPSHOT_TESTING_RECORD=never
```

- `rm -rf build`: `-resultBundlePath` fails when the path already exists.
- `SNAPSHOT_TESTING_RECORD=never`: a missing reference fails the run and writes nothing. Without it a missing image is recorded in the CI checkout, and thrown away.
- `-disableAutomaticPackageResolution`: uses the committed `Leo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, so CI builds the pinned versions.
- `-collect-test-diagnostics never`: skips the diagnostics collection that can stall for 10 minutes after a failure.
- No `-skipMacroValidation` is needed: swift-snapshot-testing has no macro targets.

### 12.4 Failures and artifacts

- Upload `build/Leo-tests.xcresult` when the job fails (`if: failure()`). Under Xcode, swift-snapshot-testing 1.19.6 attaches the new, reference and diff images to the result bundle for Swift Testing failures.
- `SNAPSHOT_ARTIFACTS` (a folder for the failing images) isn't needed. A shell variable doesn't reach the hosted tests (`SIMCTL_CHILD_…` didn't work for `SNAPSHOT_TESTING_RECORD`), and the images are already in the result bundle. It could be passed through the test plan like the record mode. *Unverified.*
- Coverage: `xcrun xccov view --report --json build/Leo-tests.xcresult`, written to the job summary. No gate (section 9).

### 12.5 Re-recording references

A separate manual job (`workflow_dispatch`) runs the same command with `SNAPSHOT_TESTING_RECORD=all`, then uploads `LeoTestsSnapshots/` as an artifact or opens a pull request with it. Review every image before merging. Images recorded locally must come from the same Xcode and simulator, so a local re-record is fine.

### 12.6 Speed and size

- Cache the `SourcePackages` folder (`-clonedSourcePackagesDirPath`), keyed on `Package.resolved`. swift-syntax 604 is slow to build from cold.
- Use a shallow checkout (`fetch-depth: 1`). `LeoTestsSnapshots/` is about 9.5 MB in 40 files and will grow when Spanish and Portuguese are added (section 11).
- Run the workflow on pull requests that change `Leo/**`, `LeoTests/**`, `LeoTestsSnapshots/**`, the test plans or the project file.
- Git LFS isn't used. Revisit it if the folder passes about 50 MB: a checkout without LFS gives pointer files and confusing failures.

### 12.7 Open items

- Set `displayScale` to 2 in `assertViewSnapshot` (currently 3) to roughly halve the image size (an estimate: 44% of the pixels). It means re-recording every image, so do it before CI starts keeping history.
- Confirm the runner has the Xcode and runtime in 12.1.
