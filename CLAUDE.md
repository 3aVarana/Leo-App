# Leo

A SwiftUI app for iPhone and iPad that builds reading comprehension with exercises written on the device by Apple's Foundation Models. What it does and why: [README.md](README.md). The plans behind each larger change: `docs/`.

## Toolchain and project

- Xcode 27.0 (pinned in `.xcode-version`), Swift 6 language mode. Deployment target iOS / iPadOS 26.5: an API newer than that needs an `@available` check and a fallback.
- The app target defaults to `MainActor` isolation with approachable concurrency. The `LeoTests` target does not, so test helpers that touch views or ViewModels are marked `@MainActor`.
- Files reach their target through Xcode's file-system synchronized folders: a new file in `Leo/` belongs to the app, one in `LeoTests/` to the tests. Never edit `project.pbxproj` to add a file.
- The only package is [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing), linked to `LeoTests` only. Adding a dependency is a decision for the user, not a task.
- No network code, accounts or analytics, and none may be added (see Privacy in the README).

## Build and test

Run everything from the repo root, on the iPhone 18 Pro simulator with iOS 27.0. Snapshot tests fail on any other device or OS.

Build:

```bash
set -o pipefail && xcodebuild build -project Leo.xcodeproj -scheme Leo -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' | xcbeautify
```

Test, with the `Leo` test plan (unit and snapshot tests; it skips the `liveModel` tests and passes `--leo-running-tests`, so the test host shows nothing and uses an in-memory history store):

```bash
set -o pipefail && xcodebuild test -project Leo.xcodeproj -scheme Leo -testPlan Leo -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' | xcbeautify
```

Always pass `-testPlan Leo`. Don't replace it with `-only-testing:LeoTests` alone: the live-model tests are in the same target and only the test plan's tag filter leaves them out. `-only-testing:LeoTests/<Suite>` on top of `-testPlan Leo` is fine for a quick run.

To verify the way CI does, add `SNAPSHOT_TESTING_RECORD=never`: a missing reference image then fails instead of being recorded.

The `LeoLiveModel` test plan runs exercise generation and topic review against the real on-device model. Run it (`-testPlan LeoLiveModel`) when anything in `Leo/Data/FoundationModels/` changes. Its tests skip themselves when the model isn't available, and the iPhone 18 Pro simulator on this Mac has it.

## Lint and format

- SwiftLint runs `--strict` as a build phase over the whole repo, so any violation fails the build. Config: `.swiftlint.yml`.
- SwiftFormat is checked in CI (`swiftformat --lint .`) and applied by the pre-commit hook in `.githooks/`. Run `swiftformat <files>` on the files you changed before handing them off, so the hook doesn't change code after it was reviewed.
- Blanket `swiftlint:disable` fails the build: disable a rule with a matching `enable`, or with `disable:next`.
- Don't rename a snapshot test function: reference images are named after it (that's why SwiftFormat's `swiftTestingTestCaseNames` rule is off).

## Architecture

MVVM with repositories, one layer per folder ([plan](docs/Leo-MVVM-Repository-Plan.md)):

- `Leo/Domain/`: plain value types and rules. Foundation only: a SwiftLint rule rejects `import SwiftUI`, `UIKit` or `FoundationModels` here.
- `Leo/Data/`: `Repositories/` holds the protocols the ViewModels depend on and their implementations (UserDefaults, SwiftData, the on-device model). `FoundationModels/` holds the generator, the `@Generable` types, the repair rules and the prompts. `SwiftData/` holds the round history schema.
- `Leo/Features/`: one folder per feature with its `@Observable` ViewModel and views, plus `Theme/` (colors, type, layout) and `Components/` (shared Broadsheet controls). A SwiftLint rule rejects `import FoundationModels` here.
- `Leo/App/MyApp.swift` is the composition root: it builds the real repositories and ViewModels and injects them.

Rules:

- Views only lay out their ViewModel's state. A view never calls a repository, a data source or FoundationModels; logic goes in the ViewModel or in Domain.
- ViewModels depend on repository protocols, never on implementations. Tests inject the hand-written fakes in `LeoTests/Support/` (`Stub…`, `…Spy`); add a new fake there rather than a mocking library.
- The view that owns a ViewModel keeps it in `@State`. That includes a view handed a new one built for it in its parent's body, as `SettingsView` and `OnboardingView` are (`makeSettingsEditor()`, `makeOnboardingEditor()`): `@State` keeps the first instance when the parent re-renders. A view handed a ViewModel that someone else owns receives it as a plain property, or `@Bindable` when it needs bindings.
- Navigation uses `NavigationStack` with `navigationDestination`.
- Log failures with `Logger(subsystem: "Leo", category: "<TypeName>")`, never `print`.
- Match the Broadsheet design: colors and text styles come from `Leo/Features/Theme/`, and shared controls from `Components/`. Reuse them before adding a new one.

## Persistence

- Reader preferences: `UserDefaults`, under the `readerPreferences` key, through `PreferencesRepository`.
- Finished rounds: SwiftData, through `RoundHistoryRepository`. The schema has shipped in a TestFlight build, so any change to a stored type needs a new `RoundHistorySchemaV<n>` and a migration stage, with tests in `RoundHistorySchemaTests`.

## The on-device model

- A change to the prompts, the `@Generable` schema or the repair rules changes the prompt text snapshots in `LeoTestsSnapshots/ExerciseGeneratorPromptTests/`: re-record them on purpose and read the diff.
- The same change must land with a before/after table from the evaluation harness ([scripts/exercise-eval](scripts/exercise-eval/README.md)). It needs Apple Intelligence on this Mac and about 8 minutes, so it's a step for the user to run when it isn't possible in the session.
- Generated text isn't deterministic. Unit tests use the stubs; behavior that depends on real output is checked with the `LeoLiveModel` plan or by hand.

## Tests

- Swift Testing (`import Testing`, `@Test`, `#expect`) for everything. There is no UI test target.
- `LeoTests/` mirrors the app's folders: `Domain/`, `Data/`, `Features/`, `Snapshots/`, `LiveModel/` and `Support/`.
- View snapshots use `assertViewSnapshot` (`LeoTests/Support/SnapshotHelpers.swift`), which records light and dark mode and adds the language to the name. Cover an accessibility text size too, as the existing suites do. References live in `LeoTestsSnapshots/<Suite>/`.
- Recording: with `SNAPSHOT_TESTING_RECORD` unset, a missing reference is recorded and its test fails once, then passes. Re-record existing ones on purpose with `SNAPSHOT_TESTING_RECORD=all`. Open every new or changed image before keeping it: a recorded image is what the test will defend. Don't re-record to make a failing snapshot pass without saying so.
- Details and the reasons behind them: [docs/Leo-Test-Coverage-Plan.md](docs/Leo-Test-Coverage-Plan.md).

## Localization

- The interface is in English, Spanish and Brazilian Portuguese, in `Leo/Localizable.xcstrings`. `Text("…")` and `String(localized:)` literals are keys in that catalog.
- Every new or changed user-facing string needs its `es` and `pt-BR` translations in the catalog in the same change. Check the catalog after building; don't assume a key was added.
- Exercise content is written in the reader's language (see `ContentLanguage`), but prompts stay in English.

## Accessibility and layout

- Every screen supports Dynamic Type up to the accessibility sizes, Dark Mode, Increase Contrast and VoiceOver, on iPhone and iPad, in portrait and landscape.
- Icon-only controls need an accessibility label. Respect Reduce Motion for any animation.

## Checking by hand in the simulator

- The iPhone 18 Pro simulator (iOS 27.0) has the on-device model, so onboarding, topic reviews and exercise generation work end to end. A topic review or an exercise takes about 10 to 30 seconds.
- Bundle id `com.victorarana.leo`. For a fresh onboarding, `xcrun simctl uninstall booted com.victorarana.leo` before installing.
- Launch with `-AppleLanguages '(es)'` or `'(pt-BR)'` to see another language without changing the simulator.
- Screenshots lag behind taps: take a second one before acting on what a screenshot shows.
- The app opens with a short launch intro; wait for it to finish before tapping.

## Documentation and delivery

- A user-visible change updates the Features section of the README, and a structural one its Project structure section.
- Larger features get a plan in `docs/Leo-<Name>-Plan.md` and ship as several pull requests against `main`, one at a time, because CI only runs on pull requests to `main` and `main` is squash-merged.
- CI on every pull request: SwiftLint, SwiftFormat and the `Leo` test plan (required), plus an advisory Claude review.
- The user confirms commits, pushes, pull requests and merges.
