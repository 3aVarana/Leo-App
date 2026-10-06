# Leo Redesign Plan: Broadsheet 2a (light) and 3a (dark)

## 1. Scope and sources

This plan compares the Claude Design redesign with the current SwiftUI app. For each screen it lists what can be built, what has to change in the views and in the business logic, what isn't doable or isn't recommended, and suggestions.

| Source | Where |
|---|---|
| Redesign | Claude Design project "Application UI/UX improvements", file `Leo Redesign.dc.html`. Local export: `~/Downloads/application-ui-ux-improvements/project/` |
| Chosen options | **2a**, light mode (turn 2: "1a screens with parts from 1b", no reading tip, Review on the missed row). **3a**, dark mode (turn 3: same screens on a warm-ink ground with flipped ramps). Options 1a/1b in turn 1 are only used where 2a refers to them. |
| Design system | Broadsheet (`_ds/broadsheet-…/styles.css`, `readme.md`) |
| Current app | `main` at `f9ea638` (MVVM + Repository, PRs #9–#13) |

The redesign has 10 screens: Onboarding age, Onboarding topics, Welcome, Loading, Generation failed, Exercise, Feedback, Results, Review (new) and Settings.

### 1.1 Decisions taken

| # | Question | Decision |
|---|---|---|
| D1 | Typeface | Bundle **Source Serif 4** (regular, italic, semibold) and scale it with Dynamic Type. |
| D2 | Passage after answering | **Keep the passage** and scroll to the feedback, as today. The mock's passage-less feedback screen isn't copied. |
| D3 | Generation-failed buttons | **Two buttons with different logic.** "Try again" retries the same topics. "Try a different topic" picks new ones. |
| D4 | Review of several misses | **Page between misses** with an "N of M missed" counter. |
| D5 | Progress dots after moving on | **Neutral.** A dot turns cyan or magenta only while its feedback is on screen, then plain ink. |
| D6 | Loading headline topic | **The topic actually being tried**, updated live when the generator falls back to a spare topic. |
| D7 | Welcome topic sample | **This round's planned topics.** |
| D8 | States missing from the mock | **Specified here by extrapolation**, each marked *(extrapolated)*. |

---

## 2. Summary

| Screen | Can be built | Logic changes | Main caveats |
|---|---|---|---|
| Onboarding · age | Yes | `AgeGroup.summary` | The empty radio ring needs a darker token in light mode |
| Onboarding · topics | Yes | Enabled-topic count, remove a custom topic by id | Needs a flow layout. The Done button moves from the toolbar to the bottom |
| Welcome | Yes | Planned topic names on `QuizViewModel` | Fixed 120pt top offset and 48pt headline become flexible and Dynamic Type aware |
| Loading | Yes | Live attempted topic through `ExerciseRepository` | The skeleton pulse respects Reduce Motion |
| Generation failed | Yes | Split `retry()` into two actions; copy depends on the index | The mock's copy is only right for text 2 |
| Exercise | Mostly | Typed topic names (`RoundTopic`), state for each progress dot | **Drop cap not recommended**. No `text-wrap`/`hyphens` equivalents |
| Feedback | Yes | None beyond the above | Passage kept (D2) |
| Results | Yes | Round answer history kept after a settings change | Dotted leaders fall back to a stacked layout at large sizes |
| Review (new) | Yes | Same history, list of misses, paging | The faded, cut-off passage isn't recommended. Show it in full |
| Settings | Yes | `AgeGroup.shortName` and `summary`, counts, remove by id | The 5-segment control needs a fallback at accessibility sizes |
| Unavailable | *(extrapolated)* | None | Not in the mock |

---

## 3. Design foundations

### 3.1 Color tokens

Add these as color sets in `Assets.xcassets/Colors/`, each with an Any (2a) and a Dark (3a) appearance. Expose them as `Color` statics in a new `Leo/Features/Theme/Theme.swift` (for example `Color.leoBackground`). Views never use `.red`, `.green` or `.secondary` for meaning again.

| Token (asset name) | 2a light | 3a dark | Used for |
|---|---|---|---|
| `Background` | `#f3f2f2` | `#1c1b1a` | Screen and sheet ground, primary button label |
| `Surface` | `#eae9e9` | `#2a2828` | Answer rows, text field fill |
| `Ink` (text) | `#201e1d` | `#efeded` | All text. Secondary text is Ink at 78% (body) or 70% (kickers, captions) |
| `Divider` | Ink 16% | Ink 18% | Hairlines on dots, chips, secondary buttons and the segmented control |
| `Accent` (cyan) | `#0088b0` | `#38a6cf` | Primary button, selected segment, current-dot ring |
| `Accent100` | `#e9f8ff` | `#0a303e` | "On" chip fill, correct-answer row fill |
| `Accent700` | `#006786` | `#62c5ee` | Accent text: kickers, option letters, "Correct", selected age label |
| `Accent800` | `#004961` | `#cbeeff` | Text on "on" chips |
| `Accent900` | `#0a303e` | `#e9f8ff` | Text on the correct-answer row |
| `Magenta` (accent-2) | `#d6006c` | `#ff458e` | Wrong-answer dot fill, failed-dot ring |
| `Magenta100` | `#fff1f4` | `#4b1528` | Wrong-answer row fill |
| `Magenta600` | `#d82071` | `#ff90b1` | Wrong icon, warning icon |
| `Magenta700` | `#aa0b56` | `#ff90b1` | Magenta text: "Not quite", "Your answer", review kicker, error copy |
| `Magenta900` | `#4b1528` | `#fff1f4` | Text on the wrong-answer row |
| `Neutral300` | `#d7d3d3` | `#3d3a3a` | Loading skeleton bars |
| `Neutral600` | `#7d7979` | `#bab6b6` | Empty age radio ring *(replaces neutral-400, see 3.6)* |
| `Neutral700` | `#605d5d` | `#d7d3d3` | "Off" chip text, upcoming-dot numbers *(replaces neutral-600 in light, see 3.6)* |

Also:

- Change `AccentColor` from today's coral to `Accent` so system controls (text field caret, toggles, alerts) follow.
- Add **Increase Contrast** variants for the light-mode pairs flagged in 3.6.
- Use `.preferredColorScheme` nowhere. The app follows the system appearance.

### 3.2 Typography

**Font files.** Bundle `SourceSerif4-Regular`, `SourceSerif4-It` and `SourceSerif4-Semibold` (static TTF/OTF, SIL OFL 1.1). Put them in `Leo/Resources/Fonts/` with `OFL.txt`, and register them through `UIAppFonts` in a small `Info.plist` that Xcode merges with the generated one.

**Fallback.** Glyphs Source Serif 4 lacks, such as CJK in passages written in Japanese or Chinese, fall back to the system font automatically. That's acceptable.

**Helper.** Add one helper so every size scales with Dynamic Type:

```swift
extension Font {
    static func leo(_ size: CGFloat, _ weight: LeoWeight = .regular, relativeTo style: Font.TextStyle) -> Font
}
```

Mapping of the mock's sizes to text styles:

| Role | Mock (size / line height, weight) | `relativeTo` | Notes |
|---|---|---|---|
| Kicker | 12, uppercase, tracking 0.08em | `.caption` | `.textCase(.uppercase)`, `.tracking(0.96)` |
| Display headline | 48 / 1.04 (Welcome); 40 / 1.08 (Loading, Error); 38 (Age); 34 (Topics) | `.largeTitle` | Semibold, tracking −0.02em (−0.025em at 48) |
| Score | 64 / 1.0 semibold | `.largeTitle` | Results only |
| Text title | 30 / 1.1 semibold | `.title` | Exercise, Review |
| Question | 20 / 1.3 semibold (19 in Review) | `.title3` | |
| Age row label | 22 / 1.2 semibold | `.title2` | |
| Body large | 17 / 27 (Welcome), 19 / 29 (Results message) | `.body` | |
| Body | 16 / 24 | `.callout` | |
| Body small | 15 / 22 | `.subheadline` | Topics subtitle, chips |
| Caption | 14 | `.subheadline` | Age description, settings caption, counters |
| Explanation | 18 / 28 *italic* (17 / 26 in Review) | `.body` | True italic file, not synthesized |
| Answer option | 17 / 24 | `.body` | |
| Button | 17 semibold (primary); 15 and 14 (secondary/ghost) | `.headline` / `.subheadline` | |
| Dot number | 13 semibold (15 on Welcome) | `.footnote` | |
| Passage | Varies by age, see below | `.body` | `lineSpacing` = line height − size |

Passage size by age group. The view layer owns this, in `AgeGroup+Typography.swift` under `Features`, because the Domain layer can't import SwiftUI:

| Group | Size / line height | Source |
|---|---|---|
| 6–8 | 21 / 34 | Mock |
| 9–11 | 18 / 29 | Mock |
| 12–14 | 18 / 29 | *(extrapolated)* |
| 15–17 | 17 / 27 | *(extrapolated)* |
| 18+ | 17 / 27 | Mock |

**System chrome.** The navigation bar, keyboard, alerts and context menus stay in SF Pro, so the design-system rule "no sans-serif for UI chrome" can only be followed partly (see 10.4). Give custom serif titles to the toolbars we own with `ToolbarItem(placement: .principal)`.

### 3.3 Spacing, shape and layout

- **Gutters.** 24pt horizontal padding on every screen.
- **Readable width.** On iPad and in landscape, cap content at about 600pt and center the column. Content stays left-aligned inside it. *(extrapolated)*
- **Radius.** 2pt on buttons, chips, answer rows, fields and the segmented control. 4pt is the large radius and isn't used on these screens. These square corners are deliberate (newsprint) and contrast with iOS 26's rounded Liquid Glass look.
- **No cards, no dividers between sections.** Whitespace sets the hierarchy. The passage loses today's rounded `.fill.quaternary` box.
- **Fixed offsets become flexible.** The mock's 120pt (Welcome) and 140pt (Loading, Error) top offsets become `Spacer(minLength:)` inside a `ScrollView`, so content fits small screens, landscape and accessibility sizes.
- **Bottom buttons.** Primary actions sit in `.safeAreaInset(edge: .bottom)` with 16pt top padding. The mock's 34pt bottom padding is the home-indicator safe area, which SwiftUI already adds.
- **Scaled sizes.** Use `@ScaledMetric` for dot diameters (28 and 36), icon sizes and minimum button heights (52 primary, 48 ghost, 44 field and Add).

### 3.4 Icons

The mock uses Phosphor duotone. Use **SF Symbols** with `.symbolRenderingMode(.hierarchical)`, which gives a similar two-tone look (see 10.3).

| Phosphor | SF Symbol |
|---|---|
| `check-circle` | `checkmark.circle.fill` |
| `x-circle` | `xmark.circle.fill` |
| `warning-circle` | `exclamationmark.circle` |
| `gear-six` | `gearshape` |
| `check` | `checkmark` |
| `plus` | `plus` |
| `x` | `xmark` |
| `arrow-clockwise` | `arrow.clockwise` |
| `arrow-right` | `arrow.right` |
| `caret-left` | System back button |

### 3.5 Shared components

New files go in `Leo/Features/Theme/`, or `Leo/Features/Components/` for components:

| Component | Spec |
|---|---|
| `LeoButtonStyle(.primary)` | Full width, min height 52, `Accent` fill, `Background` label, 17 semibold serif, 2pt radius. Pressed: `Accent700` in light, accent-400 `#1186ac` in dark. Disabled: 45% opacity |
| `LeoButtonStyle(.secondary)` | 1pt `Divider` border, transparent fill, Ink label. Pressed: Ink 14% fill |
| `LeoButtonStyle(.ghost)` | No border. Label is `Accent` in dark and **`Accent700` in light** (see 3.6). Pressed: accent 18% fill |
| `Kicker` | Uppercase 12pt label with a color parameter (Ink 70%, `Accent700` or `Magenta700`) |
| `ProgressDots` | Six circles, 28pt (36pt on Welcome), 8pt gap, centered. Each dot has a state (see 5.3). VoiceOver reads it as one element: "Text 2 of 6" |
| `TopicChip` | Padding 7×12, 2pt radius, 15pt. **On:** `Accent100` fill, `Accent800` text, `checkmark` 14pt. **Off:** 1pt `Divider` border, `Neutral700` text, `plus` 14pt. **Custom:** like On, with a trailing `xmark` that removes the topic. Shows the selected trait and is a toggle for VoiceOver |
| `FlowLayout` | A `Layout` that wraps chips with an 8pt gap in both directions |
| `AnswerRow` | Padding 14×16, 2pt radius, baseline-aligned. Letter in 15 semibold, then text in 17/24, then an optional trailing 22pt icon. Styles: `idle`, `correct`, `incorrect` (with a "Your answer" sublabel), `dimmed`. Also used in Review, labelled "You" and "Answer" |
| `AgeRow` | 12pt vertical padding. Label 22 semibold (`Accent700` when selected), description 14 at Ink 70%. Trailing: 28pt `checkmark.circle.fill` in `Accent`, or a 24pt ring (1.5pt stroke) |
| `AgeSegmentedControl` | Five equal segments, 1pt `Divider` border and separators, 2pt radius, 14pt, 9pt vertical padding. Selected segment: `Accent` fill, `Background` text. Falls back to a `Menu` picker when it doesn't fit (`ViewThatFits`) |
| `SkeletonLines` | Six bars, 9pt high, widths 100/96/100/88/100/72%, 12pt gap, `Neutral300`, 1pt radius. Opacity pulses 0.35↔1 over 1.8s, staggered 0.15s. Static at 0.6 opacity with Reduce Motion |
| `DottedLeader` | A 1pt dotted `Line` at Ink 45%, aligned to the first text baseline |

### 3.6 Contrast fixes to the mock (light mode)

WCAG contrast for the 2a token pairs. Dark mode (3a) passes every check.

| Pair in the mock | Ratio | Requirement | Change |
|---|---|---|---|
| Ghost buttons ("Back", "Reset", "Cancel", "Done", "Try a different topic"): accent on bg | 3.65 | 4.5 (14–16pt regular text) | Use `Accent700` (5.72) |
| Upcoming-dot numbers: neutral-600 on bg | 3.85 | 4.5 (13pt) | Use `Neutral700` (5.83) |
| Unselected age ring: neutral-400 on bg | 1.80 | 3.0 (non-text) | Use `Neutral600` (3.85) |
| Dimmed answers at 55% opacity | ≈3.7 | 4.5 (they're still content) | Use 70% opacity (≈5.8) |
| Primary button label: bg on accent | 3.65 | 3.0 (17pt semibold counts as large text) | Passes. With Increase Contrast, fill with `Accent700` (5.72) |

Correct and incorrect answers never rely on color alone. Every state also has an icon, and the wrong pick has the "Your answer" label.

---

## 4. Screen-by-screen

Each screen below has the same parts: the current state, the redesign, the UI updates that can be built, the view changes, the business-logic changes, and anything not doable or not recommended.

### 4.1 Onboarding · age

**Current.** `OnboardingView` → `AgeGroupPicker` is an inset-grouped `List` with the "How old are you?" header, five plain rows with a checkmark, and a Continue button (disabled until a row is picked).

**Redesign (2a/3a).** From the top:

- Kicker "Welcome to Leo".
- H1 38pt "How old are you?".
- Subtitle "Every text is written for your age — its length, its words, its questions."
- Five open rows, each with the age label and a description, for example "Everyday words · 80–120 words". The trailing indicator is a check-circle or an empty ring.
- A primary Continue button.

**Doable UI updates.** All of it.

**View changes**
- Replace the `List` with a `ScrollView` + `VStack` of `AgeRow`s.
- Add the kicker and subtitle. The headline becomes a plain `Text` with `.accessibilityAddTraits(.isHeader)`. The `OnboardingTitle` list-header workaround is no longer needed.
- Continue uses `LeoButtonStyle(.primary)` in a bottom safe-area inset, and stays disabled until a row is picked. The mock shows 9–11 preselected, but that's only demo state. Keep no default selection.
- Hide the navigation bar on this screen. It has no title in the mock.

**Business logic**
- `AgeGroup.summary: String` (new, Domain, localized). It's the description line, built from `passageWordRange` with localized number formatting so the figures can't drift from the prompt ranges:

| Group | Copy |
|---|---|
| 6–8 | Short stories · 50–80 words |
| 9–11 | Everyday words · 80–120 words |
| 12–14 | Some new vocabulary · 100–150 words |
| 15–17 | Richer vocabulary · 120–180 words |
| 18+ | Nuance and inference · 160–230 words |

**Not doable / not recommended.** None. Use the darker ring token from 3.6.

### 4.2 Onboarding · topics

**Current.** A pushed `List`:

- The large header "What do you like reading about?".
- `TopicsEditor`: a "Suggested" section of `Toggle` rows, a "Your topics" section with swipe-to-delete rows and a field + Add, and a "Keep at least 3 topics on." footer.
- A toolbar Done button.

**Redesign.** From the top:

- A back button.
- Kicker "Welcome to Leo".
- H1 34pt.
- Subtitle "{n} topics on · keep at least 3. Leo picks one for each text."
- Kicker "Suggested for 9 to 11", then wrapping chips.
- Kicker "Your topics", then a field + secondary Add button.
- A primary Done button at the bottom.

**Doable UI updates.** All of it.

**View changes**
- `TopicsEditor` stops being `List`/`Form` sections. It becomes a plain `VStack` that onboarding and Settings both use: the chip `FlowLayout`, the custom chips, the field and Add.
- Custom topics show as `TopicChip(.custom)` with a remove ✕ *(extrapolated: the mock's onboarding shows no custom topics yet; use the Settings design)*. This replaces swipe-to-delete, which is hidden and needs a `List`.
- At the minimum, an "on" chip can't be turned off. The mock just ignores the tap. Spec:
  - The chip stays enabled-looking.
  - A tap shows the existing "Keep at least 3 topics on." line under the subtitle in `Magenta700` and plays a light haptic.
  - VoiceOver hint: "At least 3 topics must stay on."
  - The ✕ on custom chips is hidden at the minimum.
- Topic-review progress: the Add button shows a `ProgressView` while reviewing, as today.
- Messages (rejections and errors) show under the field in `Magenta700` 13pt, replacing today's `.red`.
- Done moves from the toolbar to the bottom primary button.
- Keep the **system back button** (see 10.5). The mock's "‹ Back" text button isn't copied.
- The 15–17 group has 25 suggested topics, so the screen scrolls. Done stays pinned.

**Business logic**
- `PreferencesEditorViewModel.enabledTopicCount: Int`, forwarding `draft.enabledTopicCount(in:)` (already in Domain).
- `PreferencesEditorViewModel.removeCustomTopic(_ topic: CustomTopic)` and Domain `ReaderPreferences.removeCustomTopic(id:in:)`. The ✕ removes one topic by id. The offset-based `removeCustomTopics(atOffsets:)` exists only for `List.onDelete` and can go.
- `canRemoveCustomTopics` is the same as `!isAtMinimum` (exists).

**Not doable / not recommended.** The custom "Back" button. Use the native one (10.5).

### 4.3 Welcome

**Current.** A centered `book.pages` icon, "Leo", and "Six short texts for readers aged {age}, about the topics you chose.", then Start. The Settings gear is a toolbar item that `RootView` adds.

**Redesign (from 1b).**

- Header row with the "Leo" wordmark (20 semibold) and a ghost gear button.
- About 120pt of space.
- Kicker (Accent700) "Today's round · readers 9 to 11".
- H1 48pt "Six short texts, written for you."
- Six 36pt numbered outline dots.
- Body "Drawn from {A, B, C} and {N} more of your topics. One question after each."
- Primary Start button.

**Doable UI updates.** All of it.

**View changes**
- Hide the navigation bar. The wordmark and gear are drawn in the content as the mock shows. The gear keeps the accessibility label "Settings" and sets `isShowingSettings`.
- Spell out "Six" from `QuizViewModel.exerciseCount` with `NumberFormatter` `.spellOut` in the UI locale, rather than hard-coding it.
- Topic sentence (D7):
  - Up to three planned topic names, joined with `ListFormatter`, plus "and {N} more of your topics" when N > 0.
  - While the plan is empty (before `configure`), show "Drawn from your topics. One question after each."
- The dots are `ProgressDots(style: .large)`, all in the `upcoming` style with Ink numbers. They're decorative and hidden from VoiceOver.

**Business logic**
- `QuizViewModel.plannedTopicNames: [String]` gives the distinct primary topics of the prepared round, in plan order. `makePlan` already picks them; they only need names (see 5.1 `RoundTopic`).
- The view shows the first three names, and N = `plannedTopicNames.count − 3`.
- The age label comes from `RoundSettings.ageGroup`, which is already available.

**Not doable / not recommended.** `text-wrap: balance` on the headline has no SwiftUI equivalent. The system's line breaking is acceptable (10.2).

### 4.4 Loading

**Current.** A centered spinner, "Writing text {n} of 6…" and "This can take a few seconds."

**Redesign.**

- Progress dots: done (Ink fill), current (cyan ring), upcoming (outline).
- About 140pt of space.
- Kicker "Now writing".
- H1 40pt with the topic name.
- "A {n}-word text for readers {age}. Usually ready in a few seconds."
- Six pulsing skeleton lines.

**Doable UI updates.** All of it.

**View changes**
- New layout with `ProgressDots`, the kicker, the topic headline, the subtitle and `SkeletonLines`.
- **Accessibility.** The skeleton is hidden from VoiceOver. The screen reads as "Writing text 2 of 6, about {topic}" in one element and announces the change when the topic changes.
- The `{n}` in the subtitle is the midpoint of `passageWordRange`, which is the length the prompt asks for ("about 100 words").

**Business logic (D6)**
- `ExerciseRepository.exercise(topics:skill:onAttempt:)` gains a callback that `ExerciseGenerator.generate` calls before each topic it tries.
- `QuizViewModel.writingTopicName: String?`:
  - It's set to the plan item's primary topic when each generation step starts.
  - It's updated from `onAttempt` when the generator falls back.
  - Loading only shows while `exercises.count == currentIndex`, so the topic in progress is always the one for the current text.
- Update `StubExerciseRepository` and the prompt and generator tests.

**Not doable / not recommended.** None.

### 4.5 Generation failed

**Current.** `ContentUnavailableView` with "Something went wrong", the error's `localizedDescription` and a bordered "Try again" button.

**Redesign.**

- Progress dots with the failed one as a magenta ring.
- Warning icon (Magenta600, 40pt).
- Kicker (Magenta700) "Text 2 didn't print".
- H1 40pt "We couldn't write this one."
- Body "Something went wrong while writing your text about {topic}. Your answer to text 1 is saved — nothing is lost."
- Primary "Try again" with ↻.
- Ghost "Try a different topic".

**Doable UI updates.** All of it, with corrected copy.

**View changes**
- New `GenerationFailedView` replacing the `ContentUnavailableView` in `RootView`.
- Copy depends on the index. The mock's sentence is only right for text 2:

| Index | Second sentence |
|---|---|
| Text 1, or before Start | Omitted |
| Text 2 | "Your answer to text 1 is saved — nothing is lost." |
| Text 3–6 | "Your answers so far are saved — nothing is lost." |

- The `{topic}` is the plan item's primary topic name.
- The `Phase.failed(String)` message is no longer shown. Keep it for logging, or drop the payload.

**Business logic (D3)**
- `retry()` reuses `plan[index]` unchanged. It's temperature-sampled, so a second try often succeeds.
- `retryWithDifferentTopics()` is today's behavior: three random topics. Improve it to **exclude the topics that just failed** when there are enough others.
- Tests for both in `QuizViewModelTests`.

**Not doable / not recommended.** The mock's fixed "text 1 is saved" copy (see above). The print metaphor, "didn't print", needs careful translation in es and pt-BR.

### 4.6 Exercise (unanswered)

**Current.** Navigation title "Exercise {n}", then:

- A `ProgressView` bar with "{n} of 6".
- Title and passage in a rounded gray box.
- Skill caption and question.
- Outlined, rounded option buttons.

**Redesign.**

- Progress dots.
- Kicker with the topic name (Ink 70%).
- H2 30pt title.
- The passage with a 3.2em **drop cap**, at the age-dependent size.
- Kicker with the skill (Accent700).
- Question 20pt semibold.
- Answer rows on a `Surface` fill with letters A–D.

**Doable UI updates.** Everything except the drop cap.

**View changes**
- Remove the navigation title and the bar. Use `ProgressDots` instead.
- Remove the passage box. Add the topic kicker.
- Passage typography from the table in 3.2.
- `OptionButton` becomes `AnswerRow`:
  - Letters A–D are hidden from VoiceOver, which reads the option text and state.
  - Keep the haptics, the shake on a wrong pick (it already respects Reduce Motion) and `allowsHitTesting`.

**Business logic**
- `Exercise.topic` becomes a `RoundTopic` so the kicker shows the reader-facing, localized name. Today it shows nothing, and the stored value is the English prompt phrase, for example "a short story about a mystery at school", which isn't suitable for display. See 5.1.
- `QuizViewModel.dotState(at:)` (5.3).

**Not doable / not recommended**
- **Drop cap.** Not recommended (10.1). The passage starts with a normal first letter.
- `hyphens: auto` and `text-wrap: pretty` have no SwiftUI `Text` equivalent (10.2).

### 4.7 Feedback (after answering)

**Current.** The same scroll view. The answered option is filled green or red with a border, the others are dimmed, and then:

- A "Correct!" (green) or "Not quite" (red) label.
- The explanation, centered and secondary, only on a wrong pick.
- A bordered-prominent "Next" or "See results" button. The view auto-scrolls to it.

**Redesign.**

- Current dot filled magenta.
- Wrong row: Magenta100 fill, ✕ icon and a "Your answer" sublabel.
- Correct row: Accent100 fill and ✓ icon.
- Other rows dimmed.
- Verdict "✕ Not quite" (Magenta700, 20pt).
- Explanation in **italic** 18/28, left-aligned and in Ink.
- Primary "Next text" at the bottom.

**Doable UI updates.** All of it, keeping the passage (D2).

**View changes**
- The passage stays. After answering, scroll to the verdict as today.
- Answer rows use the `AnswerRow` states.
- The verdict row and the italic explanation follow the mock.
- After answering, the button sits in a **bottom safe-area inset**, matching the mock's bottom placement and always reachable. It's labelled "Next text", or "See results" on the last text (that state isn't in the mock).
- **Correct state** *(extrapolated)*:
  - Current dot filled `Accent` with a `Background` number.
  - Verdict "✓ Correct!" in `Accent700`, 20pt semibold.
  - No explanation, as today. Section 11 suggests showing it.
- **Wrong, without an explanation** (the model left it empty) *(extrapolated)*: only the verdict.

**Business logic.** The dot state (5.3). Nothing else.

**Not doable / not recommended.** The mock's passage-less layout is replaced by D2.

### 4.8 Results

**Current.** Centered star, thumbs-up or book icon, "{n} of 6 correct", a message, and "Practice again". The gear is in the toolbar.

**Redesign.**

- Secondary gear icon button at the top right.
- Kicker "Round complete · readers 9 to 11".
- Score "5 of 6" (64pt).
- Message (19/29).
- Six rows: number, title, dotted leader, then "Correct" (Accent700) or a secondary **"Review →"** button (Magenta700).
- Primary "Practice again".

**Doable UI updates.** All of it.

**View changes**
- Remove the icon. Hide the navigation bar and draw the gear in the content.
- Make the whole row the tap target (≥44pt) for missed texts, not just the small Review button, which is about 26pt tall in the mock. The row reads to VoiceOver as "Text 1, The Sleeping Mountain, missed. Review", with a button trait.
- Long titles (es, pt-BR, 18+) wrap: the leader takes the remaining width of the last line, with a 20pt minimum. At accessibility sizes `ViewThatFits` stacks the title above the status and drops the leader.
- **6/6** *(extrapolated)*: no Review buttons, message "Perfect score!…".
- **0/6** *(extrapolated)*: six Review rows.
- Tapping Review pushes `ReviewView` (4.9) on the existing `NavigationStack`.

**Business logic**
- The round's history: each exercise with the option picked (5.2).
- `correctCount` is derived from it.
- The history and the round's `ageGroup` must **outlive a settings change**. Saving settings from Results calls `configure` → `prepareRound`, which today clears `exercises`, and the kicker must show the round's age group, not the new one.

**Not doable / not recommended.** None.

### 4.9 Review (new screen)

**Current.** Doesn't exist.

**Redesign.**

- Header: "‹ Results" and "1 of 1 missed".
- Kicker (Magenta700) "Text 1 · Key detail".
- H2 title and the question.
- A "You" row in the wrong style and an "Answer" row in the correct style.
- Italic explanation.
- Kicker "From the text", then the passage cut off with a fade.
- Primary "Back to results".

**Doable UI updates.** All of it, except that the passage is shown in full.

**View changes**
- New `ReviewView(misses:startIndex:)`, pushed from Results with `navigationDestination(item:)`.
- **Paging (D4).** `TabView` with `.page(indexDisplayMode: .never)` over the missed texts, which supports swipes and VoiceOver's three-finger scroll. The header counter reads "{i} of {M} missed".
- Bottom button:

| Position | Button |
|---|---|
| Not the last miss | Primary "Next missed text" |
| Last miss | "Back to results" |

- Navigation title "Results" is set on the Results screen, so the native back button gets it as the label where the system shows one.
- **The passage is shown in full**, scrolling with the page, rather than cut off with a gradient (10.6).
- Without an explanation, the italic paragraph is omitted *(extrapolated)*.

**Business logic**
- `QuizViewModel.misses: [RoundAnswer]`, filtered from the history in 5.2.
- No new Data-layer calls: everything Review needs is already in `Exercise`.

**Not doable / not recommended.** The cut-off passage (10.6) and a custom back button (10.5).

### 4.10 Settings (sheet)

**Current.** A `Form` with a navigation-link age picker and the `TopicsEditor` sections (toggles, Reset, custom rows, field). The toolbar has Cancel and Done.

**Redesign.**

- Sheet header: Cancel, "Settings", Done.
- Kicker "Age group", then a **5-segment control** (6–8 … 18+).
- Caption "80–120 words, everyday vocabulary."
- "Suggested · {n} on" and a ghost "Reset".
- Chips.
- "Your topics" with removable chips, then the field + Add.

**Doable UI updates.** All of it.

**View changes**
- Replace `Form` with a `ScrollView` and `.presentationBackground(Color.leoBackground)`.
- Keep the native toolbar (`.cancellationAction` and `.confirmationAction`) with a serif principal title (10.5).
- `AgeSegmentedControl` bound to `draft.ageGroup`:
  - Segment labels use `AgeGroup.shortName`.
  - The accessibility label is `displayName` ("9 to 11") and the selected trait is set.
  - At accessibility sizes it falls back to a `Menu` picker.
- Caption below the control: `AgeGroup.summary`. One string is shared with onboarding; the mock uses two different phrasings for the same thing.
- "Reset" only shows when `canResetSuggestedTopics`.
- **Deviation.** The mock's "Suggested · {n} on" counts custom topics too, which is wrong under a "Suggested" header. Show the number of enabled *suggested* topics here. The total stays in the onboarding subtitle.
- Shared `TopicsEditor` as in 4.2.

**Business logic**
- `AgeGroup.shortName` (new, localized: "6–8", "9–11", "12–14", "15–17", "18+").
- `PreferencesEditorViewModel.enabledSuggestedCount`.
- `removeCustomTopic(_:)` (4.2).
- Changing the age group still cancels a pending topic review (`draft.didSet`, unchanged).

**Not doable / not recommended.** Serif text inside the system toolbar buttons (10.4).

### 4.11 Unavailable *(extrapolated)*

**Current.** `ContentUnavailableView` with the Apple Intelligence symbol.

**Spec.**

- Left-aligned, like Loading and Error.
- Kicker "Leo".
- H1 40pt "Apple Intelligence needed".
- The existing reason message at Ink 78%.
- `apple.intelligence` symbol at 40pt in `Accent700` above the kicker.
- No button. iOS can't deep-link to the Apple Intelligence settings page.

### 4.12 RootView and navigation

- Settings entry points move from `RootView`'s toolbar into the content of Welcome and Results. `canShowSettings` is unchanged.
- The navigation bar is hidden on Welcome, Loading, Failed, Exercise and Results. It's visible on Review (system back).
- The phase cross-fade (`.animation(.default, value: quiz.phase)`) stays.

---

## 5. Business-logic changes

### 5.1 Reader-facing topic names: `RoundTopic` (Domain)

Today `RoundSettings.topics` and `Exercise.topic` are English prompt phrases, but Welcome, Loading, Error and Exercise all display topic names. Add a type that carries both:

```swift
nonisolated struct RoundTopic: Hashable, Sendable {
    let prompt: String   // English phrase for the model (unchanged)
    let name: String     // Shown to the reader: the localized DefaultTopic name, or the CustomTopic name
}
```

- `ReaderPreferences.enabledTopics(for:) -> [RoundTopic]` replaces `enabledTopicPrompts(for:)`, with the same stable order.
- `RoundSettings.topics: [RoundTopic]`.
- `QuizViewModel.PlanItem.topics: [RoundTopic]`.
- `ExerciseRepository.exercise(topics: [RoundTopic], skill:, onAttempt: (RoundTopic) -> Void)`. The generator builds prompts from `.prompt` only, so the prompt snapshots don't change.
- `Exercise.topic: RoundTopic`.

Because `RoundSettings` now contains names, a UI-language change also counts as a settings change. That only happens at relaunch and leads to a fresh round, which is fine.

### 5.2 Round history: `RoundAnswer` (QuizViewModel)

```swift
struct RoundAnswer: Identifiable {
    let index: Int            // 0-based position in the round
    let exercise: Exercise
    let selectedOption: Int
    var isCorrect: Bool { selectedOption == exercise.correctIndex }
}
private(set) var answers: [RoundAnswer] = []
private(set) var roundAgeGroup: AgeGroup?
var correctCount: Int { answers.count(where: \.isCorrect) }
var misses: [RoundAnswer] { answers.filter { !$0.isCorrect } }
```

- `select(_:)` appends an answer.
- `start()` resets `answers` and records `roundAgeGroup`.
- `prepareRound()` **doesn't** touch `answers`, so Results and Review survive a settings save.

### 5.3 Progress dot state (QuizViewModel)

```swift
enum DotState { case done, current, currentCorrect, currentMissed, failed, upcoming }
func dotState(at index: Int) -> DotState
```

How the states are drawn:

| State | Look |
|---|---|
| `done` | Ink fill, `Background` number |
| `current` | 1.5pt `Accent` ring, `Accent700` number |
| `currentCorrect` | `Accent` fill |
| `currentMissed` | `Magenta` fill |
| `failed` | 1.5pt `Magenta` ring, `Magenta700` number |
| `upcoming` | 1pt `Divider` ring, `Neutral700` number |

When each state applies:

- Indices below `currentIndex` are `done`, which is neutral (D5).
- The current index is `failed` in `.failed`. While answering, it's `currentCorrect` or `currentMissed` once an answer is picked, and `current` otherwise.

Keeping this in the ViewModel makes the rules testable without snapshots.

### 5.4 Retry split (QuizViewModel)

- `retry()` keeps `plan[index]` and regenerates.
- `retryWithDifferentTopics()` replaces `plan[index].topics` with up to three topics, preferring ones not in the failed item, and regenerates.

### 5.5 Live topic and planned topics (QuizViewModel)

- `writingTopicName: String?` (4.4).
- `plannedTopicNames: [String]` (4.3).

### 5.6 Preferences

- Domain:
  - `AgeGroup.shortName` and `AgeGroup.summary`.
  - `ReaderPreferences.removeCustomTopic(id:in:)`.
  - `enabledSuggestedTopicCount(in:)`.
- `PreferencesEditorViewModel`:
  - `enabledTopicCount` and `enabledSuggestedCount`.
  - `removeCustomTopic(_:)`.
  - Drop `removeCustomTopics(atOffsets:)`.

### 5.7 Unchanged

- `RootViewModel` and preference persistence (the stored JSON format is unchanged; the `savedFormat` snapshot guards it).
- `TopicValidator`, model availability.
- `ExerciseGenerator` prompts. Only the attempt callback is added.

---

## 6. Localization

Every new string gets `es` and `pt-BR` translations in `Leo/Localizable.xcstrings` (V2 rule). New or changed strings:

- **Onboarding:**
  - "Welcome to Leo"
  - "Every text is written for your age — its length, its words, its questions."
  - "%lld topics on · keep at least 3. Leo picks one for each text."
  - "Suggested for %@"
- **AgeGroup:**
  - Five `shortName` values.
  - Five `summary` templates, for example "Everyday words · %1$lld–%2$lld words".
- **Welcome:**
  - "Today's round · readers %@"
  - "%@ short texts, written for you." (spelled-out number)
  - "Drawn from %@ and %lld more of your topics. One question after each." (with plural variants)
  - "Drawn from %@. One question after each."
  - "Drawn from your topics. One question after each."
- **Loading:**
  - "Now writing"
  - "A %lld-word text for readers %@. Usually ready in a few seconds."
  - "Writing text %lld of %lld, about %@" (VoiceOver)
- **Failed:**
  - "Text %lld didn't print"
  - "We couldn't write this one."
  - "Something went wrong while writing your text about %@."
  - "Your answer to text 1 is saved — nothing is lost."
  - "Your answers so far are saved — nothing is lost."
  - "Try a different topic"
- **Exercise and Feedback:**
  - "Your answer"
  - "Next text"
  - "Text %lld of %lld" (dots, VoiceOver)
- **Results:**
  - "Round complete · readers %@"
  - "%lld of %lld" (score)
  - "Correct"
  - "Review"
  - Accessibility row labels
- **Review:**
  - "%lld of %lld missed"
  - "Text %lld · %@"
  - "You"
  - "Answer"
  - "From the text"
  - "Next missed text"
  - "Back to results"
- **Settings:**
  - "Suggested · %lld on"
  - "Reset" (replaces "Reset suggested topics")
  - "At least 3 topics must stay on." (hint)
- **Unavailable:** "Leo" kicker. Existing messages are reused.

Strings that go away: "Writing text %lld of %lld…", "This can take a few seconds.", "%lld of %lld correct", "Exercise %lld", "Something went wrong", "Reset suggested topics", and the Welcome sentence.

---

## 7. Testing

- **Unit tests (Swift Testing):**
  - `QuizViewModelTests` for the history (and that it survives `configure`), `dotState`, both retries, `writingTopicName` across a fallback, and `plannedTopicNames`.
  - `ReaderPreferencesTests` for `enabledTopics(for:)` names, `removeCustomTopic(id:)` and the suggested count.
  - `AgeGroupTests` for `summary` figures matching `passageWordRange`.
  - `PreferencesEditorViewModelTests` for the new counts and removal.
- **Snapshot tests:** re-record every PNG in `LeoTestsSnapshots/` (light and dark, accessibility size). Add:
  - Review (one miss; paging, second of three; no explanation).
  - Generation failed (text 1 and text 3).
  - Feedback correct, and wrong on the last text.
  - Results 6/6 and 0/6.
  - Settings at 6–8 and 15–17 (25 chips).
  - Topics at the minimum.
  - Unavailable.
  - One `es` snapshot each for Results and Welcome, to catch long titles and strings.
- **Fonts in tests:** the snapshot host must register Source Serif 4. `UIAppFonts` does it for the hosted app. Confirm that a snapshot doesn't silently fall back to New York or SF.
- **README:** update the four screenshots once the snapshots are re-recorded.
- **Hand check:** on the iPhone 18 Pro simulator, which has the on-device model, check the live topic fallback and a real generation failure.

---

## 8. Implementation order (stacked PRs)

1. **Foundations.** Fonts and registration, color sets, `Theme.swift`, the components in 3.5 with previews, and the `AccentColor` change. No screen changes yet; the AccentColor snapshot changes are re-recorded here.
2. **Domain and ViewModels.**
   - `RoundTopic` through the repository and generator.
   - `RoundAnswer` history, `dotState`, the retry split, `writingTopicName` and `plannedTopicNames`.
   - The `AgeGroup` and `ReaderPreferences` additions and the editor ViewModel changes.
   - Unit tests and new strings.
   - Views get only the minimal edits needed to compile.
3. **Onboarding and Settings.** The shared chip `TopicsEditor`, age rows and the segmented control.
4. **Welcome, Loading, Generation failed.**
5. **Exercise and Feedback.**
6. **Results and Review.**
7. **Polish.** Unavailable, iPad and landscape checks, README screenshots and a translation review.

Each PR re-records the snapshots of the screens it changes, so CI stays green on every branch of the stack.

---

## 9. Extrapolated items (for design review)

All of these are specified above and marked *(extrapolated)*. They're collected here so they can go back to Claude Design if wanted:

- Feedback "Correct!" state.
- The "See results" label on the last text.
- Wrong answer without an explanation.
- Results 6/6 and 0/6.
- Review paging controls and counter.
- Custom chips in onboarding.
- The minimum-topics message.
- The Unavailable screen.
- Passage sizes for 12–14 and 15–17.
- iPad and landscape readable width.
- Accessibility-size fallbacks: Results rows, the segmented control, and the flexible offsets.

---

## 10. Not doable or not recommended

| # | Mock element | Verdict | Reason | Instead |
|---|---|---|---|---|
| 10.1 | **Drop cap** on the passage (3.2em floated first letter) | Not recommended | SwiftUI `Text` can't wrap text around a floated glyph. It would need a TextKit `UITextView` with exclusion paths, which breaks or complicates several things: Dynamic Type relayout, VoiceOver (it reads "M… ount Rainier" as two parts), text selection and native `Text` styling. Passages can also start with "¿", "«" or quotes in es and pt-BR, and with CJK characters, where a drop cap reads wrong. A lot of cost for decoration. | Plain first letter. Could come back later as an option for Latin-script passages only |
| 10.2 | `text-wrap: balance / pretty`, `hyphens: auto` | Not doable natively | SwiftUI `Text` has no balanced wrapping, orphan control or hyphenation setting. | Accept system line breaking. Headline line breaks look fine at these sizes |
| 10.3 | Phosphor duotone icons | Not recommended | It's a third-party dependency (the app has none), it wouldn't match the SF Symbols the system draws in toolbars, sheets and the keyboard, and SF Symbols already scale with Dynamic Type and have accessibility labels. | SF Symbols with hierarchical rendering (3.4) |
| 10.4 | Serif everywhere, including UI chrome | Partly not doable | System-owned UI (navigation bar buttons, keyboard, alerts, the context menu on the text field, the share sheet) always uses SF Pro on iOS 26. | Serif in all content and custom controls, including our own segmented control and the principal toolbar title |
| 10.5 | Custom "‹ Back" and "‹ Results" text buttons | Not recommended | Hiding the system back button turns off the interactive swipe-back gesture and loses the standard VoiceOver escape behavior. On iOS 26 the system back button is a glass chevron, so it won't look exactly like the mock. | Native back button and toolbar (Settings Cancel and Done stay native too) |
| 10.6 | Review passage cut off with a fade | Not recommended | The point of Review is checking the answer against the text. Hiding the end of the passage can hide the evidence, and it's only reachable at all if it scrolls. | Full passage, scrolling with the page |
| 10.7 | Fixed pixel sizes and offsets (48pt headline, 120/140pt gaps, 28/36pt dots, a 26pt-tall Review button) | Not doable as-is | The README promises Dynamic Type up to accessibility sizes. Fixed offsets also overflow in landscape and look odd on iPad. | Text styles with `relativeTo:`, `@ScaledMetric`, flexible spacers, full-row tap targets |
| 10.8 | Light-mode contrast of ghost buttons, upcoming dots, the empty ring and dimmed rows | Adjust | Below WCAG minimums (3.6). | Darker ramp steps, 70% dimming, Increase Contrast variants |
| 10.9 | Fixed copy "Text 2 didn't print… Your answer to text 1 is saved" | Adjust | Only correct for the second text. | Copy by index (4.5) |
| 10.10 | Mixed counts ("Suggested · {n} on" includes custom topics) | Adjust | The number contradicts its label. | Suggested-only count in Settings (4.10) |
| 10.11 | 9–11 preselected on the age screen | Not copied | It's demo state in the mock. Preselecting would let readers skip a meaningful choice. | No default; Continue stays disabled |
| 10.12 | Feedback screen without the passage | Replaced | Decision D2. | Passage kept, scroll to feedback |

---

## 11. Suggestions

1. **Show the explanation after correct answers too.** Today it only shows after a miss. Confirming *why* an answer is right reinforces the skill, and the data is already there.
2. **Evidence highlighting in Review.** Ask the model for an `evidence` sentence in `GeneratedExercise`, check it's a substring of the passage, and highlight it under "From the text". This changes the prompts, so evaluate it with the live-model test plan first.
3. **A "Quit round" affordance.** Neither the mock nor the app has a way out of a round in progress. A small toolbar ✕ with a confirmation would help on long rounds.
4. **Keep the last round across launches.** Results and Review live in memory today. Persisting the last `RoundAnswer`s would let a reader come back to Review later. Out of scope here.
5. **iPad regular width.** Show the passage and the question side by side in two columns on iPad landscape, instead of one capped column.
6. **App icon and launch screen** in the Broadsheet palette, so the first frame matches the new ground color instead of flashing white or black.
7. **Enforce the theme with SwiftLint.** A custom rule in `Leo/Features` that flags `Color.red`, `.green`, `.foregroundStyle(.secondary)` and system `.font(.headline)`-style fonts outside `Theme/`, so new views don't drift back to system styling. This is like the existing layer-boundary rules.
8. **Ask Claude Design for the extrapolated states** in section 9 before PRs 5–7, especially Feedback correct and Results 6/6, which most readers will see.
