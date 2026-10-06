# Leo Redesign (Option 2a): Implementation Plan

## 1. Scope

Apply the Broadsheet redesign, Option **2a**, to the existing screens, with its dark mode taken from Option **3a** (3a is "2a in dark mode").

Source: the Claude Design handoff bundle for project `1e172d62-03d4-4e36-9c0f-3990ed41f1c9`, file `Leo Redesign.dc.html`, sections `#2a` (screens) and `#3a` (dark values). The Broadsheet tokens and component styles are in `_ds/broadsheet-*/styles.css` in the same bundle.

Constraints:

- Business logic stays untouched, except for the read-only additions listed per screen in phase 3, each agreed before it's made.
- No new dependencies.
- Existing previews keep working. There are no accessibility identifiers in the app or tests today, so there are none to break. Any added later must stay stable.
- Where the design conflicts with how the app works, the app's behavior wins. Screens may differ from the design when that's the better choice; each difference is noted in its phase 3 PR.

## 2. Decisions

| Area | Decision |
|---|---|
| Typeface | Apple's built-in **New York** serif (`design: .serif`) instead of Source Serif 4. No font files, no Info.plist change, full Dynamic Type. |
| Dark mode | The 3a values below. |
| Icons | SF Symbols with `.symbolRenderingMode(.hierarchical)` in place of Phosphor duotone. |
| System chrome | Navigation bars, toolbars and sheets stay system (iOS 26 glass), tinted with the theme. |
| Conflicts | Settled screen by screen in phase 3, not up front. See section 6. |

## 3. Screen map

| 2a screen | Existing view | New inputs it needs |
|---|---|---|
| Onboarding · age | `AgeGroupPicker` in `Leo/Views/Onboarding/OnboardingView.swift` | A description line per age group (new copy) |
| Onboarding · topics | `OnboardingView.topics` + `Leo/Views/Settings/TopicsEditor.swift` | None |
| Welcome | `Leo/Views/WelcomeView.swift`; the gear is in `Leo/Views/RootView.swift` | The enabled topics |
| Loading | `Leo/Views/LoadingView.swift` | The topic being written, the age group |
| Exercise + feedback | `Leo/Views/ExerciseView.swift` (`OptionButton`, `ShakeEffect`) | The age group, for passage sizing |
| Results | `Leo/Views/ResultView.swift` | The age group, and each text's title and outcome |
| Settings (sheet) | `Leo/Views/Settings/SettingsView.swift` + `TopicsEditor` | None |
| Not designed | `.failed` state in `RootView`, `UnavailableView` | None. These are restyled with tokens only. |

`QuizModel` is the only model; `ReaderPreferences` and `PreferencesStore` hold the settings. There is no separate ViewModel layer.

## 4. Design tokens

### Colors

Color sets go in `Leo/Assets.xcassets/Theme/`, each with Any and Dark appearances. Only the ramp steps the screens use are added, not the full 100–900 ramps.

| Asset | Broadsheet token | Light | Dark | Used for |
|---|---|---|---|---|
| `AccentColor` (update) | accent | #0088B0 | #38A6CF | Primary buttons, selection, system tint |
| `Paper` | bg | #F3F2F2 | #1C1B1A | Screen background, text on primary buttons |
| `Surface` | surface | #EAE9E9 | #2A2828 | Idle answer rows |
| `Ink` | text | #201E1D | #EFEDED | Body text. Secondary text is Ink at 78% (body) or 70% (captions, eyebrows) opacity. |
| `Divider` | divider | #201E1D at 16% | #EFEDED at 18% | Chip, input and secondary borders; upcoming strip circles |
| `AccentTint` | accent-100 | #E9F8FF | #0A303E | Selected chip, correct row background |
| `AccentInk` | accent-700 | #006786 | #62C5EE | Eyebrows, option letters, "Correct", current strip numeral |
| `AccentStrong` | accent-800 | #004961 | #CBEEFF | Selected chip text |
| `AccentDeep` | accent-900 | #0A303E | #E9F8FF | Correct row text |
| `Miss` | accent-2 | #D6006C | #FF458E | Missed strip circle |
| `MissTint` | accent-2-100 | #FFF1F4 | #4B1528 | Wrong row background |
| `MissIcon` | accent-2-600 | #D82071 | #FF90B1 | Wrong-answer icon |
| `MissInk` | accent-2-700 | #AA0B56 | #FF90B1 | "Not quite", "Your answer", "Review" |
| `MissDeep` | accent-2-900 | #4B1528 | #FFF1F4 | Wrong row text |
| `Skeleton` | neutral-300 | #D7D3D3 | #3D3A3A | Loading bars |
| `Muted` | neutral-600 | #7D7979 | #BAB6B6 | Upcoming strip numerals |
| `Subdued` | neutral-700 | #605D5D | #D7D3D3 | Unselected chip text |
| `RadioRing` | neutral-400 | #BAB6B6 | #7D7979 | Unselected age radio |

`AccentColor` was never registered as the app's accent (the target had no `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`), so the app used the system blue. Phase 1 registers it, which changes every system tint (buttons, progress views, text field carets, navigation bar buttons, alerts).

### Theme file

`Leo/Views/DesignSystem/Theme.swift` is the single place for typed colors, fonts, spacing, radii and sizes. The shared components (phase 2) sit next to it, one file each.

### Type (New York)

Sizes are the design's px values at the default text size. Each scales with Dynamic Type: use `Font.system(_:design: .serif)` text styles where a style is close, and `@ScaledMetric` or `Font.system(size:weight:design:)` with a scaled size otherwise.

| Size / line height | Weight | Use |
|---|---|---|
| 64 / 1.0, tracking −3% | Semibold | Results score |
| 48 / 1.04, tracking −2.5% | Semibold | Welcome heading |
| 40 / 1.08 | Semibold | Loading topic |
| 38 / 1.08 | Semibold | Age title |
| 34 / 1.08 | Semibold | Topics title |
| 30 / 1.1, tracking −2% | Semibold | Exercise title |
| 22 / 1.2 | Semibold | Age row label |
| 20 / 1.3 | Semibold | Question, "Leo" wordmark, feedback heading |
| 19 / 29 | Regular | Results message |
| 17 | Regular | Buttons, answer options, welcome body |
| 16 / 24 | Regular | Body copy |
| 15 | Regular / Semibold | Chips / option letters, strip numerals |
| 14 | Regular | Captions, descriptions |
| 13 | Regular | "Your answer" |
| 12, uppercase, tracking +8% | Regular | Eyebrows |
| Italic 18 / 28 | Regular | Feedback explanation |

The passage size depends on the age group:

| Age group | Size / line height |
|---|---|
| 6–8 | 21 / 34 |
| 9–11 | 18 / 29 |
| 12–14, 15–17 | Not designed. Interpolate, settled in the Exercise PR. |
| 18+ | 17 / 27 |

### Spacing

- The screen gutter is 24.
- Gaps inside a block are 2, 8, 10, 12 and 14.
- Gaps between sections are 22, 24 and 28.
- The mockups' device-frame padding (54 top, 34 bottom) comes from the safe area, not from fixed values.

### Radii

- 2 for buttons, chips, answer rows, inputs and the segmented control.
- 4 for large surfaces.
- Full circles for the round strip and the radio.

Today's views use 12 and 16, so this is a noticeably squarer look.

### Sizes and states

| Element | Size |
|---|---|
| Primary button | 52 high |
| Input, secondary button | 44 high |
| Round-strip circles | 28 (in a round), 36 (welcome) |
| Gear button | 40 |
| Radio | 24, with a 1.5 stroke |
| Age check-circle | 28 |

Pressed states use accent-600/700 and disabled controls drop to 45% opacity.

### Icons

| Phosphor | SF Symbol |
|---|---|
| check-circle | `checkmark.circle.fill` |
| x-circle | `xmark.circle.fill` |
| gear-six | `gearshape` |
| caret-left | `chevron.left` |
| plus | `plus` |
| check | `checkmark` |
| x | `xmark` |
| arrow-right | `arrow.right` |

## 5. Order of changes

One branch, one PR per phase (phase 3 can be one PR per screen). Each PR re-records the snapshot references it changes, so the visual diff can be reviewed. CI fails until a PR's snapshots are re-recorded.

### Phase 1: Tokens

1. Add the color sets and update `AccentColor`.
2. Add `Theme.swift`: colors, New York type scale, spacing, radii and sizes.
3. Apply the paper background, tint and serif design at app level.

### Phase 2: Shared components

Each component gets its own `#Preview`.

| Component | What it is |
|---|---|
| `PrimaryButtonStyle` | Full-width, 52 high, accent fill, paper text |
| `SecondaryButtonStyle` | Divider border |
| Ghost button style | Accent text, no fill |
| `Eyebrow` | 12pt uppercase label |
| `RoundStrip` | Six numbered circles in upcoming, current, done and missed states. Needs an accessibility label such as "Text 2 of 6". |
| `AgeRow` | Age row with its radio indicator |
| `TopicChip` | On, off and removable chip |
| `FlowLayout` | Chip wrapping, built on SwiftUI's `Layout` |
| Themed text field | 44 high input with a divider border |
| Age segmented control | With a fallback for large text sizes |
| `AnswerRow` | Replaces `OptionButton`. Keeps the shake, haptics and accessibility values. |
| `SkeletonLines` | Pulsing bars; respects Reduce Motion |
| Results index row | Title, dotted leader, then the outcome |

### Phase 3: Screens

Apply the screens in this order:

1. Welcome
2. Loading
3. Exercise + feedback
4. Results
5. `TopicsEditor`
6. Onboarding age
7. Onboarding topics
8. Settings
9. Failed and Unavailable states

For each screen, the redesign PR also addresses that screen's conflicts and risks, and any logic, navigation and architecture changes it needs (section 6). Where the design and the app disagree, the PR picks a solution, possibly different from the design, and says why. Any change outside the views is limited to read-only additions agreed in advance.

## 6. Phase 3: Per-screen conflicts and risks

Each item names the conflict and a suggested approach. The final call is made when the screen is implemented.

### All screens

- **Localization.** New copy needs `es` and `pt-BR` translations in `Leo/Localizable.xcstrings`, with plural variants where counts appear.
- **Snapshot tests.** Every reference image changes: light, dark and accessibility sizes. Tests that construct views directly must be updated when a view's initializer changes. That's test code, not logic. The views are `WelcomeView`, `LoadingView`, `ResultView` and `ExerciseView`.
- **Color meaning.** Correct and wrong change from green and red to cyan and magenta. Keep the icons so meaning isn't carried by color alone.
- **Safe areas.** Device chrome comes from safe areas, not fixed padding.

### Welcome

- **Gear placement.** The design puts the gear inside the page, as a ghost button here but a bordered one on Results, which is inconsistent. Today it's a `RootView` toolbar item shown only on Welcome and Results. Suggested: keep the toolbar item and add a "Leo" wordmark as a toolbar item.
- **"Drawn from X, Y, Z and N more of your topics".** This needs the enabled topics. Pass them from `preferences.roundSettings` in `RootView`. Handle fewer than four topics, and pluralize.
- **"Six short texts".** Derive the number from `QuizModel.exerciseCount` instead of hard-coding six.

### Loading

- **"Now writing {topic}".** The topic for the current index is only in `QuizModel`'s private `plan`. This needs a read-only accessor, or the screen leaves the topic out.
- **"A {n}-word text".** The real word count isn't known before generation. Suggested: show the age group's `passageWordRange`.
- **Round strip.** It replaces the `ProgressView` and "Writing text N of 6". It needs `currentIndex` and an accessibility label.

### Exercise + feedback

- **Title and progress.** The navigation title "Exercise N" and the progress bar are replaced by the round strip. Hide the navigation bar's title, and keep the "N of 6" information available to VoiceOver.
- **Drop cap.** CSS floats the first letter, and SwiftUI `Text` can't wrap text around it. The options are:
  - skip the drop cap
  - enlarge the first letter inline
  - use a TextKit wrapper (heavy, and VoiceOver may misread the split word)
- **Passage sizing by age group.** The view needs the age group passed in. The sizes for 12–14 and 15–17 aren't designed.
- **Correct feedback.** Only "Not quite" is designed. The "Correct!" state (cyan check) needs to be defined.
- **Button copy.** The design's "Next text" replaces "Next". The last exercise keeps "See results".
- **Feedback placement.** It stays inline below the options, with the existing scroll-to-feedback, haptics and shake.

### Results

- **Index of texts.** `QuizModel` only keeps `correctCount`. Listing each text's title and outcome needs a read-only per-exercise record, or the screen keeps just the score and message.
- **"Review →" on missed texts.** It leads to a screen that isn't designed. Suggested: leave it out until there's a Review design.
- **Eyebrow.** "Round complete · readers {age}" needs the age group passed in.
- **Gear.** Same as Welcome.

### TopicsEditor (shared by onboarding and settings)

- **Structure.** Today it returns `Section`s for use inside a `List` or `Form`, with toggles, swipe-to-delete and a footer. The chip design means a plain stack inside a `ScrollView` in both places.
- **Removing custom topics.** A "×" on the custom chip replaces swipe-to-delete.
- **Behavior the design doesn't show, which must survive:**
  - The minimum of 3 topics. The prototype ignores the tap silently; the app needs a visible disabled state and "Keep at least 3 topics on."
  - Reset shown only when some suggested topic is off.
  - The spinner while a topic is reviewed.
  - All validation messages.
  - No delete at the minimum.
  - Cancelling the review on age group change and on deinit (the `Review` class).

### Onboarding · age

- **Descriptions.** The age rows add a description line per group ("Everyday words · 80–120 words"). Settings describes the same thing differently ("80–120 words, everyday vocabulary"). Pick one wording. The word ranges come from `passageWordRange`; the phrases are new copy. 12–14 and 15–17 aren't designed.
- **Navigation bar.** The design has none on this screen; the onboarding `NavigationStack` stays.

### Onboarding · topics

- **Back.** The design uses a custom "Back" ghost button. Suggested: keep the system back button, which keeps swipe-back.
- **Done.** It moves from the toolbar to a bottom primary button.
- **Subtitle.** The new subtitle "{n} topics on · keep at least 3" needs a plural.

### Settings

- **Layout.** A custom sheet layout replaces the `Form`. Suggested: keep the system Cancel and Done toolbar items.
- **Age picker.** A 5-option segmented control replaces the navigation-link picker. It won't fit at accessibility text sizes or with longer translations, so it needs a fallback (a menu or a list).
- **Topic sync.** Changing the age group keeps updating `TopicsEditor` live, as it does today.

### Failed and Unavailable

These aren't designed. Restyle with tokens only and keep `ContentUnavailableView`'s structure.

## 7. Open questions

These are decided when the screen they belong to is implemented in phase 3:

- **Loading:** add a read-only current-topic accessor to `QuizModel`, or leave the topic out?
- **Results:** add a read-only per-exercise record to `QuizModel` for the index? Should "Review" wait for a design?
- **Exercise:** skip the drop cap, or use an inline large first letter? Which passage sizes for 12–14 and 15–17? How should "Correct!" feedback look?
- **Copy:** one age description wording for onboarding and settings, and the 12–14 and 15–17 descriptions.
