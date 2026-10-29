# Leo Round History Plan

**Status (2026-10-29):** shipped. PR 1 is #40, PR 2 is #41, followed by #45 (History previews only in Debug) and #46 (section headers line up with the reading column). H1–H8 hold as written. Notes marked *Update 2026-10-29* below record where the code differs from this plan: changes from the #41 review, and #52, which lets a round have 3 to 9 texts (6 by default) instead of always 6. #52 changed no stored type, so the schema is still `RoundHistorySchemaV1`.

## 1. Scope and sources

Today a round lives only in memory: `QuizViewModel.answers` feeds Results and Review, and is gone after "Practice again" or a relaunch. This plan saves every finished round on the device, so the reader can come back to it later, review the texts they missed, and see how they're doing over time. It's the first part of the README's "Progress tracking" roadmap item, and the Redesign plan's suggestion 4 ("Keep the last round across launches").

Design source: the Claude Design project "Application UI/UX improvements", file `Leo Redesign.dc.html`, options **2a** (light) and **3a** (dark, same screens). The local export is `~/Downloads/application-ui-ux-improvements/project/`. The screens this plan adds:

| Mock screen | `data-screen-label` | Today |
|---|---|---|
| Welcome, header | `2a Welcome` | Gear only. The mock adds a History button left of it |
| Results, header | `2a Results` | Gear only. The mock adds a History button left of it |
| History · all rounds | `2a History` | New |
| History · one round | `2a Round` | New |
| Review (from a past round) | `2a Review` | Exists; reused |

Every other screen of 2a/3a is already implemented (`docs/Leo-Redesign-Plan.md`, PRs #15–#21). Its settled decisions still hold here, in particular 10.3 (SF Symbols, not Phosphor), 10.5 (native back buttons, not the mock's "‹ Leo" / "‹ History" text buttons), 10.6 (full passage in Review) and 10.7 (Dynamic Type instead of fixed sizes).

Current app: `main` at `a69bab7`.

### 1.1 Decisions taken

| # | Question | Decision |
|---|---|---|
| H1 | Storage | **SwiftData**, behind a `RoundHistoryRepository` in `Leo/Data`, mapped to plain Domain structs. In-memory container in tests and previews. |
| H2 | Which rounds | **Finished rounds only.** A round is saved when the reader reaches Results. A round left halfway is not kept. |
| H3 | Deleting | **Swipe to delete a round** on the History list, no confirmation. No other deletion, no limit on how many rounds are kept. |
| H4 | Progress scope | **The mock's summary only:** the History header ("14 rounds read · 81% answered right") and each round's score and dots. Every answer stores its skill, so results per skill can come later from the same data. |
| H5 | Entry button | **As in the mock:** a clock icon beside the gear on Welcome and Results; for 6–8 readers a "Past rounds" text button instead. |
| H6 | Before the first round | **The button is hidden** until there is a saved round to show (see H7), so History is never empty. |
| H7 | Age groups | **Current age group only.** History lists, and totals, the rounds read at the age group in the current preferences. Changing the age group in Settings switches the list. Rounds of other age groups are kept, not deleted. |
| H8 | Delivery | **Plan doc, then 2 stacked PRs:** storage and saving (no visible change), then the screens. |

### 1.2 Extrapolated (not in the mock)

As in the Redesign plan, states the mock leaves out are extrapolated here. Each can be changed before PR 2.

- **Section titles past this month:** the mock shows "This week", "Last week" and "Earlier in October". Older rounds are grouped by month, "September", with the year when it isn't the current one, "September 2025". A section with no rounds is left out. "Last week" wins over "Earlier in October" when they overlap.
- **A round with no misses:** the round page shows no bottom button (the mock's "Review 2 missed" needs a miss).
- **Review's last button from History:** "Back to round" instead of "Back to results".
- **Deleting the last round** of the age group closes History and goes back to the screen it came from, where the button is now hidden (H6).
- **Results after an age-group change:** Results keeps showing the round just read, but its History button follows H6/H7 for the new age group, so it can be hidden.
- **The list's bottom fade** in the mock (`histFade`) is left to iOS 26's own scroll edge effect.

---

## 2. Data

### 2.1 Domain

All in `Leo/Domain`, Foundation only (the `domain_imports` lint rule).

- **Move `RoundAnswer`** from `Leo/Features/Quiz` to `Leo/Domain`, unchanged. Results, Review and history all use it.
- **New `RoundRecord`:** a finished round.

  ```swift
  nonisolated struct RoundRecord: Identifiable, Sendable {
      let id: UUID
      let finishedAt: Date
      let ageGroup: AgeGroup
      let answers: [RoundAnswer]   // in round order, `index` 0...5
      var correctCount: Int { get }
      var misses: [RoundAnswer] { get }
  }
  ```

  > *Update 2026-10-29:* `index` runs from 0 to the round's text count minus 1, up to 0...8 since #52. `RoundRecord` is also `Hashable` by `id`, so it can drive `navigationDestination(item:)` (#41 review).

- **New `RoundSummary`:** what a History row needs, without the texts.

  ```swift
  nonisolated struct RoundSummary: Identifiable, Equatable, Sendable {
      let id: UUID
      let finishedAt: Date
      /// Whether each answer was right, in round order. Drives the score and the dots.
      let results: [Bool]
      var correctCount: Int { get }
  }
  ```

- **`TopicKind` gets `String` raw values** (`story`, `informative`, `open`), so it can be stored. Like `DefaultTopic.id`, the raw values of `AgeGroup`, `ComprehensionSkill` and `TopicKind` are now persisted and must never change. Each enum gets a doc comment saying so.
- **`Exercise.id`** becomes an `init` parameter with a `UUID()` default, so a restored exercise keeps a stable identity across reads. Nothing else in `Exercise` changes.

### 2.2 SwiftData schema

New folder `Leo/Data/SwiftData/`.

`RoundHistorySchemaV1: VersionedSchema` (version 1.0.0) with two models, plus a `RoundHistoryMigrationPlan: SchemaMigrationPlan` with that one schema and no stages yet, so a later version (for example per-skill stats) migrates instead of starting over.

| Model | Attributes |
|---|---|
| `StoredRound` | `@Attribute(.unique) id: UUID`, `finishedAt: Date`, `ageGroup: String` (`AgeGroup.rawValue`), `results: [Bool]`, `@Relationship(deleteRule: .cascade) answers: [StoredAnswer]` |
| `StoredAnswer` | `index: Int`, `exerciseID: UUID`, `topicPrompt`, `topicName`, `topicKind` (raw), `skill` (raw), `title`, `passage`, `question`, `options: [String]`, `correctIndex: Int`, `selectedOption: Int`, `explanation`, `round: StoredRound?` (inverse) |

- `results` duplicates what the answers say, on purpose: the History list fetches rounds and reads `results` without faulting in six passages per row (up to nine since #52). It's written once, at save, from the same answers.
- SwiftData relationship arrays aren't ordered, so answers are sorted by `index` when read.
- Stored text is what the reader saw: localized topic names, the passage and options in the language of the round. Nothing is re-localized later.
- The store file is named `RoundHistory.store` in Application Support (a named `ModelConfiguration`, not SwiftData's `default.store`). It's local only: no CloudKit. It's in the device backup like any app data.
- Default actor isolation is `MainActor` in this target. If `@Model` classes conflict with it, mark them `nonisolated` like the Domain types; check this first in PR 1.

### 2.3 `RoundHistoryRepository`

New `Leo/Data/Repositories/RoundHistoryRepository.swift`, same shape as the other repositories:

```swift
protocol RoundHistoryRepository {
    func save(_ round: RoundRecord) throws
    /// Rounds read at `ageGroup`, newest first.
    func summaries(for ageGroup: AgeGroup) throws -> [RoundSummary]
    /// `nil` when it was deleted or can't be read.
    func round(id: UUID) throws -> RoundRecord?
    func delete(id: UUID) throws
}
```

`SwiftDataRoundHistoryRepository` implements it on a `ModelContainer`'s `mainContext`:

- `summaries(for:)` uses a `FetchDescriptor` with `#Predicate { $0.ageGroup == raw }` sorted by `finishedAt` descending.
- `save` inserts and calls `context.save()` right away, so a crash or kill after Results keeps the round.
- **Unreadable data is skipped, never fatal.** A stored answer whose `correctIndex` or `selectedOption` is out of range, or whose raw values are unknown, makes `round(id:)` return `nil` and its summary is left out, with a log line. `Exercise.init`'s `precondition` is never reached with stored data.
- `static func live() -> SwiftDataRoundHistoryRepository`: the on-disk container. **If it can't be created** (full disk, damaged store), it logs and falls back to an in-memory container, so the app still runs; history just isn't kept that launch.
- `static func inMemory()`: for tests and previews.

Errors from `save` and `delete` are logged by the caller; the reader never sees an error for history. Results still shows the round when saving fails.

`MyApp` builds the live repository. The test host (`--leo-running-tests`) gets the in-memory one, so the test runs never touch the on-disk store.

---

## 3. Saving a finished round

`QuizViewModel` gains two init parameters, both with defaults so existing tests and previews keep compiling:

```swift
init(
    makeRepository: @escaping (RoundSettings) -> any ExerciseRepository,
    now: @escaping () -> Date = Date.init,
    onRoundFinished: @escaping (RoundRecord) -> Void = { _ in },
)
```

- In `next()`, when `isLastExercise`, before `phase = .finished`: build `RoundRecord(id: UUID(), finishedAt: now(), ageGroup: roundAgeGroup, answers: answers)` and call `onRoundFinished` once.
- Nothing else changes: `answers` and `roundAgeGroup` still feed Results and Review in memory, as today. A round left before Results (the app closed mid-round) is never reported (H2).

`RootViewModel` owns the history:

- New init parameter `history: RoundHistoryViewModel`, kept as `let history`.
- `MyApp` passes `onRoundFinished: { history.record($0) }` when it builds the quiz, so the composition stays in one place.
- `preferencesDidChange()` also sets `history.ageGroup = preferences.ageGroup` (H7).

---

## 4. `RoundHistoryViewModel`

New `Leo/Features/History/RoundHistoryViewModel.swift`, `@Observable`.

| Member | Meaning |
|---|---|
| `init(repository:calendar:now:)` | `calendar` and `now` default to `.autoupdatingCurrent` and `Date.init`; tests pass fixed ones |
| `var ageGroup: AgeGroup?` | Setting it reloads `summaries` |
| `private(set) var summaries: [RoundSummary]` | The current age group's rounds, newest first |
| `var hasRounds: Bool` | Drives the entry button (H6) |
| `var roundCount: Int`, `var correctShare: Double` | The header: rounds and the share of all answers that were right (`81%` = 0.81, formatted with `.percent`, no decimals) |
| `var sections: [HistorySection]` | `summaries` grouped as in 1.2. `HistorySection` has a `kind` (`.thisWeek`, `.lastWeek`, `.earlierThisMonth(Date)`, `.month(Date)`) and its rounds; the view turns the kind into a title. *Update 2026-10-29:* the code has `.month(Date, showsYear: Bool)`, and the ViewModel's `monthName(_:showingYear:)` writes the title |
| `func record(_ round: RoundRecord)` | Saves; reloads when the round's age group is the current one |
| `func round(id: UUID) -> RoundRecord?` | For the round page |
| `func delete(id: UUID)` | Deletes and reloads |

Weeks follow `calendar` (its locale's first weekday), using `calendar.dateInterval(of: .weekOfYear, for:)`.

---

## 5. Screens

New views in `Leo/Features/History/`. Sizes are the mock's, as `LeoTextStyle`s with `relativeTo:` (decision 10.7).

### 5.1 The entry button (Welcome and Results)

- New component `Leo/Features/Components/HistoryButton.swift`: for `.six`, a text button "Past rounds" with the `clock.arrow.circlepath` symbol (mock: ghost button, 16pt, 20pt icon); for every other age group the symbol alone (24pt, like the gear), with the accessibility label "Past rounds". Hierarchical rendering, 44pt minimum target.
- `WelcomeView` and `ResultView` get `onHistory: (() -> Void)?`; `nil` hides the button (H6). It sits left of the gear with 4pt between them.
- **Results' gear loses its outline** (the `RoundedRectangle` `strokeBorder` overlay in `ResultView`), so it matches the History button and Welcome's gear, as in the mock's ghost icon buttons. Size, symbol and 44pt target stay.
- The age group that picks the variant is the one in the current preferences.
- `WelcomeView` gets `.navigationTitle(Text(verbatim: "Leo"))` (its bar stays hidden), so History's native back button reads "Leo" as in the mock. Results already sets "Results".

  > *Update 2026-10-29:* not implemented. `WelcomeView` sets no navigation title, so History's back button from Welcome doesn't read "Leo". Still open.

### 5.2 History · all rounds (`HistoryView`)

Pushed on the root `NavigationStack` from Welcome or Results, native back button, inline empty title.

- Heading "Your rounds" (`.display(40)`, header trait), 20pt below the bar.
- The summary line under it (17/26, `leoInkSoft`): "\(n) rounds read · \(percent) answered right", with a plural variant for one round in the string catalog.
- 28pt below, the sections. A section title is a `Kicker` (header trait), 20pt above each section after the first.
- A row (12pt vertical padding), one button: the date ("22 Oct", 17 semibold) and the time ("9:12", 15, `leoInkSoft`) on the left; on the right the score ("5 of 6", 17 semibold) over the round's dots; then a `chevron.right` (`leoInkSoft`). Date and time use the reader's locale (`Date.FormatStyle`, day and abbreviated month; hour and minute).
- **Round dots:** new component `RoundResultDots`: one 8pt dot per answer, 4pt apart. Right: filled `leoInk`. Missed: a 1.5pt `leoMagenta` ring. Scaled with `@ScaledMetric`, capped like `ProgressDots`.
- **Swipe to delete (H3)** needs a `List`: `.listStyle(.plain)`, no separators, no row backgrounds, `leoBackground` behind it, rows inset to the readable column. `.swipeActions` with a destructive "Delete".
- At accessibility sizes the row stacks: date and time, then score and dots.
- VoiceOver reads a row as one button: "22 October, 9:12, 5 of 6 right", hint "Shows the round". The dots are hidden from it.

### 5.3 History · one round (`RoundView`)

Loads the `RoundRecord` by id. If it's gone (deleted, unreadable) the view pops back.

> *Update 2026-10-29:* as built (#41), `HistoryView` loads the round before pushing, and `RoundView(round:)` takes the loaded `RoundRecord`. A round that can't be loaded isn't pushed.

- `Kicker` "20 Oct, 16:45 · readers \(ageGroup.displayName)", 28pt below the bar.
- The score "4 of 6" (`.score`, header trait), then `RoundResultDots` 14pt below.
- 24pt below, a row per text (10pt vertical padding): the number (15 semibold, top-aligned), then the title (17/24) over "\(topic name) · \(skill)" (14, `leoInkSoft`); trailing "Correct" (14 semibold, `leoAccent700`) or the Review label. Missed rows are buttons that open Review at that miss, like Results.
- **Shared Review label:** Results' private status chip moves to `Leo/Features/Components/ReviewLabel.swift` and is used by both screens, so they match. It **drops the `arrow.right` symbol**: just "Review", magenta, bordered, as in the mock. This changes the missed rows on Results too.
- Bottom bar: "Review \(n) missed" as `.leo(.secondary)`, opening Review at the first miss. Hidden when nothing was missed (1.2).
- VoiceOver: same row labels as Results ("Text 3, Why bread rises, missed", hint "Review"), plus the topic and skill.

### 5.4 Review from History

`ReviewView` gets a `backTitle: LocalizedStringResource` parameter (default "Back to results"); `RoundView` passes "Back to round" (1.2). Nothing else changes.

### 5.5 Navigation

`RootView` holds the History route: Welcome and Results call `onHistory`, which pushes `HistoryView`; `HistoryView` pushes `RoundView(id:)` with `navigationDestination(item:)` (*as built:* `navigationDestination(item: $selectedRound)` and `RoundView(round:)`, see 5.3); `RoundView` pushes `ReviewView` the way `ResultView` does today. Starting a round or saving settings from Welcome never happens while History is on screen, so the round flow is untouched.

---

## 6. Tests

All in the `Leo` test plan, Swift Testing, hand-written fakes.

### 6.1 PR 1

- `Support/RoundHistoryRepositorySpy`: in-memory, records saves and deletes, can be told to throw.
- `Support/Fixtures`: `RoundRecord.fixture(ageGroup:finishedAt:results:)` building six exercises (*as built:* one per entry in `results`).
- `Data/SwiftDataRoundHistoryRepositoryTests` (in-memory container unless noted):
  - `saveThenRoundRestoresEveryField`: all exercise fields, order, topic kind, skill, `Exercise.id`.
  - `summariesAreNewestFirstAndPerAgeGroup`
  - `summaryResultsMatchAnswers`
  - `deleteRemovesTheRoundAndItsAnswers`
  - `unreadableRoundIsSkipped`: an out-of-range `selectedOption` and an unknown skill raw value.
  - `roundsSurviveANewContainer`: on-disk store in a temporary directory, reopened.
- `Data/RoundHistorySchemaTests`: the V1 entity and attribute names, so renaming a stored property without a migration fails (the role `savedFormat` plays for preferences).
- `Domain/RoundRecordTests`: `correctCount`, `misses`; `RoundSummary.correctCount`.
- `Features/QuizViewModelRoundTests`:
  - `finishingARoundReportsItOnce`: answers, age group, `now()`.
  - `unfinishedRoundIsNotReported`
  - `practiceAgainReportsANewRound`: a second round gets a new id.
- `Features/RoundHistoryViewModelTests` (fixed calendar, locale and `now`):
  - `hasRoundsFollowsTheAgeGroup`, `ageGroupChangeReloads`
  - `totals` (count and share across rounds, no rounds)
  - `sectionsGroupByWeekThenMonth`: this week, last week, earlier this month, an older month, last year; a week across a month boundary; an empty section left out.
  - `recordForAnotherAgeGroupDoesNotShow`, `deleteReloads`, `saveFailureKeepsTheList`
- `Features/RootViewModelTests`: `finishedRoundReachesHistory`, `preferencesDidChangeSetsHistoryAgeGroup`.

### 6.2 PR 2

- New snapshot suites, light and dark, plus an accessibility size: `HistoryViewSnapshotTests` (three sections; one round), `RoundViewSnapshotTests` (2 missed; 6 of 6), `ComponentsSnapshotTests` gains `RoundResultDots` and `HistoryButton` (icon and "Past rounds").
- Re-recorded: Welcome and Results (the new button), for 9–11 and 6–8. Results also changes for the gear without its outline and the Review label without its arrow. Each re-recorded image is checked by eye against the mock.
- `ReviewViewSnapshotTests`: the "Back to round" variant.

### 6.3 Hand checks (iPhone 18 Pro simulator, on-device model)

1. Finish a round: the clock appears on Results; History lists it with the right time, score and dots.
2. Quit and relaunch: the round is still there; open it, review a miss, "Back to round".
3. Swipe to delete a round; delete the last one: History closes and the button hides.
4. Switch the age group in Settings: the list and totals switch; switch back: the old rounds return.
5. 6–8: "Past rounds" text button on Welcome and Results.
6. VoiceOver through History and the round page; the largest accessibility size; iPad portrait and iPhone landscape (the readable column holds).
7. Close the app mid-round: nothing is saved.

---

## 7. Docs and privacy

- README: the roadmap's "Progress tracking" item becomes "results per comprehension skill" (history and scores are done), and the feature list mentions History.
- `PrivacyInfo.xcprivacy`: no change expected. The history never leaves the device, so nothing is "collected", and SwiftData isn't a required-reason API. Confirm against Apple's current list in PR 1.
- New strings go into `Localizable.xcstrings` in the repo's compact `"key": value` form.

---

## 8. Delivery

Stacked PRs, one at a time against `main` (CI runs only on PRs to `main`), using the rebase procedure from the MVVM plan:

| PR | Contents | Visible change |
|---|---|---|
| 0 | This plan | None |
| 1. Save finished rounds | 2.1–2.3, 3, 4, `TopicKind` raw values, `Exercise.id` parameter, `RoundAnswer` move, tests 6.1 | None: rounds are saved, nothing shows them yet |
| 2. History screens | 5.1–5.5, `ReviewLabel` extraction, strings, snapshots 6.2, README, hand checks 6.3 | The History button, History, the round page, Review from History; on Results, a plain gear and "Review" without the arrow |

PR 1 freezes the stored format. Once a TestFlight build with it ships, any change to the schema needs a `RoundHistorySchemaV2` and a migration stage.

> *Update 2026-10-29:* that build has shipped, so the rule applies (see CLAUDE.md, Persistence). Snapshot tests for History and the round page still use 6-text rounds only; nothing checks a 9-dot row at large text sizes yet. The 6.3 hand checks were done before #52.

---

## 9. Later

- **Results per skill** (H4): a breakdown from the stored `skill` of each answer, once Claude Design has a screen for it.
- **Adaptive difficulty** can read the same history.
- **Sharing a device:** history follows the age group (H7), not a person; profiles would be a separate feature.
