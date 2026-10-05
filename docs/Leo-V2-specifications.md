# Leo V2 Specification: Age Groups, Topic Management, Onboarding

## 1. Scope

Leo V1 generates reading comprehension rounds with the on-device Foundation Model for readers aged 15–18, from a fixed English topic list. V2 adds:

1. Five age groups that control passage length and language complexity.
2. Per-age-group default topics the reader can toggle, plus validated custom topics.
3. First-launch onboarding (age group, then topics) before any generation.
4. Persistence of these choices so later launches generate immediately, as V1 does.
5. A settings screen to change age group and topics, which regenerates the round.

Out of scope for V2: per-age-group changes to exercise count, option count or question skills; settings access mid-round; any storage other than UserDefaults.

## 2. Agreed decisions

| Area | Decision |
|---|---|
| Age groups | 6–8, 9–11, 12–14, 15–17, 18+ |
| What varies per group | Passage word range and language complexity only. Round shape is unchanged: 6 exercises, 3–4 options, all five skills. |
| Custom topic validation | Local checks, then an on-device model review that returns a verdict and a cleaned-up phrase. The cleaned phrase is what gets stored and displayed. |
| Custom topic scope | Stored under the age group they were added in. |
| Minimum enabled topics | 3 per age group (enabled defaults + custom topics). |
| Custom topic limits | Max 20 per age group, 2–60 characters each. |
| Settings entry points | Toolbar gear on the welcome and results screens only. |
| Copy tone | Addressed to the reader: "How old are you?", "What do you like reading about?" |
| Persistence | One Codable `ReaderPreferences` as JSON in `UserDefaults`, key `readerPreferences`. Disabled defaults are stored (not enabled ones) so defaults added later appear enabled. |
| Localization | Every new string gets Spanish (`es`) and Brazilian Portuguese (`pt-BR`) translations in `Leo/Localizable.xcstrings`. |

## 3. Project facts relevant to implementation

- iOS 27.0 SDK, deployment target 26.6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`.
- `knownRegions`: en, es, pt-BR.
- No test target exists.
- Simulators: the "iPhone 17" family runs iOS 26.4/26.5, below the deployment target. Use an iOS 27 simulator such as "iPhone 18 Pro".
- Existing files: `Leo/MyApp.swift`, `Leo/Models/Exercise.swift`, `Leo/Models/Topics.swift`, `Leo/Services/ContentLanguage.swift`, `Leo/Services/ExerciseGenerator.swift`, `Leo/Services/QuizModel.swift`, `Leo/Views/{RootView,WelcomeView,LoadingView,ExerciseView,ResultView}.swift`.

## 4. Architecture

```
ReaderPreferences (Codable)          PreferencesStore (@Observable, UserDefaults)
  ageGroup                            ├─ preferences: ReaderPreferences?   (nil → onboarding)
  disabledDefaultTopics[group]        └─ injected with .environment from MyApp
  customTopics[group]

AgeGroup (enum)                      DefaultTopics (per group: id + LocalizedStringResource name + English prompt)
  displayName, promptAudience,
  passageWordRange, passageSentenceRange,
  acceptedWordCount, styleGuidance

RoundSettings (ageGroup + [topic prompts])  ──►  QuizModel.configure(_:)
                                                   └─ ExerciseGenerator(language:, ageGroup:)

TopicValidator (Foundation Models)   ──►  used by TopicsEditor when adding a custom topic
```

App flow in `RootView`:

1. Model unavailable → existing `UnavailableView`.
2. `store.preferences == nil` → `OnboardingView`. Done saves; view switches to welcome.
3. Otherwise → existing phase switch. Generation is driven by `.task(id: store.preferences?.roundSettings) { if let s = store.preferences?.roundSettings { quiz.configure(s) } }` attached to the phase-branch subtree. It fires after onboarding, on every launch, and whenever settings are saved.
4. Gear on welcome/results presents `SettingsView` in a sheet. `configure` is a no-op for unchanged settings.

## 5. New files

### `Leo/Models/AgeGroup.swift`

```swift
nonisolated enum AgeGroup: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case six = "6-8", nine = "9-11", twelve = "12-14", fifteen = "15-17", adult = "18+"
    var displayName: String              // localized: "6 to 8" … "18 or older"
    var promptAudience: String           // English: "children aged 6 to 8" … "adult readers"
    var passageWordRange: ClosedRange<Int>
    var passageSentenceRange: ClosedRange<Int>?   // sentence count asked for with the word range, or nil
    var acceptedWordCount: ClosedRange<Int>       // 60% of lower bound ... 150% of upper bound
    var styleGuidance: String            // English prose for the instructions
}
```

`CodingKeyRepresentable` makes the `[AgeGroup: …]` dictionaries in `ReaderPreferences` encode as JSON objects keyed by the raw value rather than as flat arrays.

| Group | Word range | Sentences asked for | Style guidance (gist) |
|---|---|---|---|
| 6–8 | 50–80 | 10–13 | Short sentences, familiar words, warm tone, concrete question and answers |
| 9–11 | 80–120 | 10–13 | Simple sentences, everyday vocabulary, concrete ideas |
| 12–14 | 100–150 | 10–13 | Clear paragraphs, some new vocabulary, light inference |
| 15–17 | 120–180 | — | Current V1 level |
| 18+ | 160–230 | — | Varied sentence structure, precise vocabulary, questions may require nuance |

Why the sentence counts: given only a word range, the model wrote passages well under it for the younger groups (6–8 averaged ~40 words), because their style guidance asks for short sentences. Adding a sentence count brings them into range. For 15–17 and 18+ a sentence count made passages run on without stopping, so those groups get the word target only.

`acceptedWordCount` is the range `Exercise` accepts. It is wider than the requested range because the model doesn't count words precisely, but it rejects passages that were cut off or never stopped.

### `Leo/Models/Topic.swift` (replaces `Topics.swift`, which is deleted)

```swift
nonisolated struct DefaultTopic: Identifiable, Sendable {
    let id: String                       // stable key, e.g. "space-exploration"; persisted
    let name: LocalizedStringResource    // picker label, extracted into xcstrings
    let prompt: String                   // English phrase for the model
}
nonisolated struct CustomTopic: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String                     // model's cleaned phrase, reader's language; display and prompt
}
nonisolated enum DefaultTopics {
    static func topics(for group: AgeGroup) -> [DefaultTopic]   // ~15 per group
}
```

Freeze `DefaultTopic.id` values before any build is distributed, since they are persisted.

Default topic lists (names refined during implementation, ids frozen):

- **6–8:** pets and farm animals, dinosaurs, the seasons, a day at school, friendly dragons and fairies, the beach, insects and bugs, helping at home, birthday parties, a lost toy that finds its way home, trains and trucks, the moon and stars, baking cookies, playground games, a kind robot.
- **9–11:** wild animals, volcanoes, the solar system, pirates and treasure, inventors, rainforests, dinosaurs and fossils, sports heroes, a mystery at school, the ocean floor, ancient Egypt, how machines work, video games, recycling, a magical adventure.
- **12–14:** space exploration, climate and weather, ancient civilizations, the human body, famous explorers, inventions, animal behavior, mythology, a short story about friendship, coding and robots, music history, survival stories, natural disasters, world cultures, mysteries of history.
- **15–17:** the current `Topics.all` list, unchanged.
- **18+:** history's turning points, psychology and habits, economics in daily life, science breakthroughs, philosophy and ethics, architecture, world literature, nutrition and health, personal finance, technology and society, a short literary fiction piece, travel and geography, the history of language, art movements, the science of sleep.

### `Leo/Models/ReaderPreferences.swift`

```swift
nonisolated struct ReaderPreferences: Codable, Equatable, Sendable {
    var ageGroup: AgeGroup
    var disabledDefaultTopics: [AgeGroup: Set<String>] = [:]
    var customTopics: [AgeGroup: [CustomTopic]] = [:]

    static let minimumEnabledTopics = 3
    static let maximumCustomTopics = 20

    func enabledTopicPrompts(for group: AgeGroup) -> [String]
    var roundSettings: RoundSettings
}
nonisolated struct RoundSettings: Equatable, Hashable, Sendable {
    let ageGroup: AgeGroup
    let topics: [String]
}
```

Rules:
- `enabledTopicPrompts` returns a deterministic order: defaults in list order, then custom topics in insertion order. Never shuffled before storage, or the equality checks regenerate on every save.
- If the result is empty (stale ids), fall back to all default prompts for the group.
- Custom `init(from:)` using `decodeIfPresent` with defaults for both dictionaries, so adding fields later never breaks old data.

### `Leo/Services/PreferencesStore.swift`

`@Observable final class PreferencesStore`. `init(defaults: UserDefaults = .standard)` loads and decodes; `preferences: ReaderPreferences?` has a `didSet` that encodes and writes. Injected from `MyApp` with `.environment`. The `defaults` parameter lets previews use `UserDefaults(suiteName:)`.

### `Leo/Services/TopicValidator.swift`

```swift
@Generable nonisolated struct TopicReview {
    @Guide(description: "Whether the topic is safe and suitable for reading texts for the given reader age")
    var isSuitable: Bool
    @Guide(description: "If suitable, the reader's topic tidied up as a short phrase of at most 6 words: fix spelling and capitalization, keep the reader's own words and meaning, in the same language the reader typed it in; otherwise empty")
    var topic: String
    @Guide(description: "If not suitable, one short friendly sentence for the reader explaining why, in the language the instructions ask for; otherwise empty")
    var reason: String
}
struct TopicValidator {
    enum Outcome { case accepted(String), rejected(String) }
    let language: ContentLanguage
    func review(_ text: String, for group: AgeGroup) async throws -> Outcome
}
```

- Keep property order `isSuitable`, `topic`, `reason`: guided generation fills in declaration order.
- Fresh `LanguageModelSession` per call, `GenerationOptions(temperature: 0.2)`.
- Instructions: "You review topics a reader wants to practice reading about. Each topic becomes short reading texts written for `promptAudience`, at their level: a story, or an explanation of facts. So everyday, school, real-world and imaginative topics all work, and a topic doesn't need to be realistic. Accept a topic if it is appropriate reading material for `promptAudience`. Write the topic phrase and the reason in `language.name`." Do not enumerate unsafe categories; that raises guardrail false positives on benign topics.
- Prompt: "Topic: `text`" followed by "Write the reason in `language.name`." Without the repeated line, model-written reasons came back in English for Spanish and Portuguese readers.
- Why the instructions describe what the texts are: with only "Accept a topic only if it is appropriate reading material", the model rejected "dinosaurs that play soccer" as unrealistic, the suggested topic "pirates and treasure" as dangerous, and "the history of basketball" as too complex.
- Why the `topic` guide asks to keep the reader's words: "rewritten as a short, clear phrase" let the model paraphrase freely ("volcanoes" became "Lava mountains").
- Error mapping: guardrail hit or refusal → `.rejected` with a generic localized reason. Anything else is thrown and shown as "We couldn't check that topic. Please try again." Catch both the deprecated and the iOS 27 error types:

```swift
catch LanguageModelSession.GenerationError.guardrailViolation,
      LanguageModelSession.GenerationError.refusal { return .rejected(generic) }
catch {
    if #available(iOS 27, *), case LanguageModelError.guardrailViolation = error { return .rejected(generic) }
    if #available(iOS 27, *), case LanguageModelError.refusal = error { return .rejected(generic) }
    throw error
}
```

### `Leo/Views/Onboarding/OnboardingView.swift`

`NavigationStack` with two steps:
1. `AgeGroupPicker`: title "How old are you?", `List` of `AgeGroup.allCases` rows with checkmark selection, prominent "Continue" disabled until a group is picked.
2. Topics step: title "What do you like reading about?", a `List` containing the `TopicsEditor` sections, toolbar "Done". Done builds `ReaderPreferences` from the draft and sets `store.preferences`.

Both titles are a private `OnboardingTitle` view used as a section header: the header of the age rows' section, and of an empty section above the topic sections. It uses `.largeTitle.bold()`, `Color.primary` (a header draws in a secondary style, which `.primary` would follow), `.textCase(nil)`, zero leading inset so it lines up with the card edge, and the header accessibility trait. Not a navigation title, because a navigation large title doesn't wrap and truncates long translations ("Quantos anos você te…"). Not a list row, because the row's rounded card corners clip the large text.

### `Leo/Views/Settings/SettingsView.swift`

Sheet content wrapped in its own `NavigationStack` (a sheet does not inherit the presenter's). Inside: `Form` with section "Age group" (`Picker` with `.navigationLink` style over `displayName`) followed by `TopicsEditor` sections for the selected group. Works on `@State var draft: ReaderPreferences`. Toolbar "Done" writes `store.preferences = draft` and dismisses. "Cancel" discards the draft.

### `Leo/Views/Settings/TopicsEditor.swift`

A `@ViewBuilder` returning `Section`s (never its own `List`/`Form`). Bound to a `ReaderPreferences` draft and an `AgeGroup`.

- Section "Suggested": `Toggle` per `DefaultTopic` with `Text(topic.name)`.
- Section "Your topics": `ForEach` of custom topics with `.onDelete`, then `TextField("Add a topic")` and "Add". While reviewing: inline `ProgressView`, field disabled. Local-check or rejection message under the field in red `.footnote`.
- Review runs in a `Task` held by a private `@Observable` `Review` object in `@State`. The task is cancelled when the object is deinitialized (the editor goes away) and when the age group changes. Not `.onDisappear`: inside a `List` it also fires when the section scrolls out of view, or when settings pushes the age group picker.
- The message under the field clears as soon as the text changes.
- `enabledCount` = enabled defaults + custom topics for the group. When `enabledCount <= 3`: enabled toggles are `.disabled`, custom rows get `.deleteDisabled(true)`, footer "Keep at least 3 topics on."
- "Reset suggested topics" restores all defaults for the group.
- All edits go to the draft; nothing persists until Done.

Add-topic sequence. Matching a name ignores case and accents, and compares against `String(localized: default.name)` and the custom names for the group.
1. Local checks on trimmed input, in order, all without calling the model:
   1. Not 2–60 characters → "Topics must be between 2 and 60 characters."
   2. Matches an enabled default or a custom topic → "That topic is already on your list."
   3. Matches a disabled default → re-enable that default and clear the field.
   4. Already 20 custom topics → "You can have up to 20 of your own topics."
2. `TopicValidator.review`.
3. On `.accepted(phrase)`, repeat the matching on the phrase. If it matches a disabled default, re-enable that default instead of adding. If it matches an enabled topic, show the duplicate message. Otherwise append a `CustomTopic`. The field is cleared unless the duplicate message is shown. On `.rejected(reason)`, show the reason. If the review throws, show "We couldn't check that topic. Please try again."

## 6. Modified files

### `Leo/Models/Exercise.swift`
- `GeneratedExercise.passage` guide becomes age-neutral: "An original, self-contained reading passage, with the length and reading level requested in the instructions". Other guides unchanged.
- `Exercise.init?(generated:topic:skill:acceptedWordCount:)` replaces the hard-coded `wordCount >= 60`. The passage's word count must be inside `acceptedWordCount`.
- The linguistic word count (`enumerateSubstrings(.byWords)`, so languages without spaces work) moves into a `String.wordCount` extension, shared with `ExerciseGenerator`.
- `ComprehensionSkill` unchanged.

### `Leo/Services/ExerciseGenerator.swift`
- Add `let ageGroup: AgeGroup`.
- Word range phrase: "between X and Y words long, about M words", where M is the midpoint, plus " in A to B sentences" when `passageSentenceRange` isn't nil. For example, 6–8 gives "between 50 and 80 words long, about 65 words in 10 to 13 sentences".
- Instructions start with: "You create reading comprehension exercises for `promptAudience`. The passage must be `word range phrase`. `styleGuidance`", then the existing rules unchanged.
- The per-exercise prompt in `generate(topics:skill:)` repeats the word range phrase.
- Pass `ageGroup.acceptedWordCount` to `Exercise.init?`.
- Generate with `streamResponse` instead of `respond`. On each snapshot, if the partial passage is longer than `acceptedWordCount.upperBound` words, throw a private `RunawayPassage` error. The attempt loop logs it and tries the next topic. When the stream finishes, build `GeneratedExercise` from the last snapshot's `rawContent`.
- `GenerationOptions(temperature: 0.8, maximumResponseTokens: 1200)`, as a backstop for a runaway outside the passage. A complete exercise takes well under 800 tokens even for long passages in Spanish or Portuguese.
- Why: the model sometimes keeps writing the passage and never stops. Without these limits an attempt ran until the 8,192-token context was full, about 3 minutes, before the next topic was tried; two in a row kept an exercise loading for 5 minutes. With them, a runaway attempt is abandoned after about 6 seconds.

### `Leo/Services/ContentLanguage.swift`
- `name` returns the language only ("English", "Spanish", "Portuguese"), not the region. It keeps the script when it isn't the language's default ("Chinese, Traditional").
- Why: with the region, prompts said "in English (Bolivia)" and the model wrote about Bolivia, e.g. "trains around the world" became "Trains in Bolivia".

### `Leo/Services/QuizModel.swift`
- `private var settings: RoundSettings?`. `prepareRound()` and `retry()` begin with `guard let settings else { return }`; `start()` is a no-op without settings.
- Replace `prepare()` with `func configure(_ s: RoundSettings) { guard plan.isEmpty || s != settings else { return }; settings = s; prepareRound() }`. `prepareRound()` already cancels the in-flight task, clears `exercises`, and resets `isRoundStarted`, so phase stays `.welcome` or `.finished` and the next `start()` uses the new round.
- Replace `Topics.all` in `prepareRound()` and `retry()` with `settings.topics`.
- Topic planning: `shuffled = topics.shuffled()`; `primary[i] = shuffled[(i + i / count) % count]`; spares for exercise i = `shuffled` minus `primary[i]`, shuffled, first 2. With 3 topics each exercise still gets 3 attempts, matching `ExerciseGenerator.maxAttempts`. `retry()` keeps `settings.topics.shuffled().prefix(3)`.
- `generator = ExerciseGenerator(language: .current(), ageGroup: settings.ageGroup)` in `prepareRound()`.

### `Leo/Views/RootView.swift`
- Read `PreferencesStore` from the environment; add the onboarding branch before the phase switch.
- Replace `.task { quiz.prepare() }` with the `.task(id:)` from section 4, attached to the phase-branch subtree, not the outer switch.
- `@State private var isShowingSettings`; toolbar gear shown only when phase is `.welcome` or `.finished`; presents `SettingsView`.
- Preview: `RootView().environment(PreferencesStore(defaults: UserDefaults(suiteName: "preview")!))`. Every new view reading the store needs the same in its preview.

### `Leo/Views/WelcomeView.swift`
- Takes `ageGroup`. Subtitle: "Six short texts for readers aged %@, about the topics you chose." Check es and pt-BR read naturally with all five `displayName` values. Update preview.

### `Leo/MyApp.swift`
- `@State private var store = PreferencesStore()`, injected with `.environment(store)`.

### `Leo/Localizable.xcstrings`
- Build first so Xcode extracts new keys (including `LocalizedStringResource` literals from `DefaultTopics`), then add `es` and `pt-BR` for: age group names, onboarding titles, "Continue", "Done", "Cancel", "Settings", "Suggested", "Your topics", "Add a topic", "Add", "Keep at least 3 topics on.", "Reset suggested topics", "That topic is already on your list.", "Topics must be between 2 and 60 characters.", "You can have up to 20 of your own topics.", "We couldn't check that topic. Please try again.", the generic rejection reason, the welcome subtitle, and ~75 default topic names.

## 7. Implementation order

1. Models: `AgeGroup`, `Topic`/`DefaultTopics`, `ReaderPreferences`, `RoundSettings`; delete `Topics.swift`.
2. `PreferencesStore` and injection in `MyApp`.
3. `Exercise`, `ExerciseGenerator`, `QuizModel` changes. The app should build and run end to end with a hard-coded 15–17 preference before any UI exists.
4. `TopicValidator`.
5. `TopicsEditor`, `AgeGroupPicker`, `OnboardingView`, `SettingsView`, `RootView` and `WelcomeView` wiring.
6. Localization pass (es, pt-BR), then on-device verification.

## 8. Verification

Build:

```
xcodebuild -scheme Leo -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
```

Foundation Models runs in the simulator on a Mac with Apple Intelligence enabled; otherwise verify on a device. The Mac runs the same model, so prompt changes can be measured faster with a command-line Swift harness that compiles `AgeGroup`, `Exercise`, `Topic`, `ContentLanguage`, `ExerciseGenerator` and `TopicValidator` and calls them directly.

Manual checks:

1. Fresh install: onboarding appears; Continue disabled until an age is picked; topics step shows that group's defaults all on.
2. Turn off topics until 3 remain: remaining enabled toggles disable and the footer appears.
3. Custom topics: "dinosaurs that play soccer" accepted and shown as a cleaned phrase that keeps its meaning; a duplicate shows a local error with no model call; an obviously unsafe topic is rejected with a reason; 61 characters shows a local error; "pirates and treasure" and "volcanoes" are accepted; typing a disabled default's name re-enables that default instead of adding a duplicate. Run with a device region other than the US (e.g. en-BO) to catch the region leaking into phrases.
4. Done → welcome shows the age group; a round generates immediately and no exercise takes more than a few seconds; passage lengths roughly match the group's range. Expect 18+ to come in around 150–160 words, at or just under its 160 lower bound: no prompt wording tried got this model longer without passages running on.
5. Kill and relaunch: welcome appears directly, no onboarding; Start works.
6. Change age group from the welcome gear → Done → Start: passages visibly change. Cancel after edits, or Done with no edits → no regeneration (temporary debug log in `prepareRound()`).
7. Open settings while generation is in flight, change a topic, Done → old generation cancelled, new round uses the new topic list.
8. From results, change topics → Practice again → new round uses the new topics.
9. Simulator in Spanish and in Portuguese: all new UI strings and default topic names are translated, and long titles wrap instead of truncating; a custom topic typed in that language gets a cleaned phrase and passages in that language; a rejected topic's reason is in that language.
10. With exactly 3 topics enabled, confirm `retry()` still produces an exercise.
