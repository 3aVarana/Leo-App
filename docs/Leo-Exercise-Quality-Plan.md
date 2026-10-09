# Leo Exercise Quality Plan

## 1. Scope and sources

`ExerciseGenerator` and `GeneratedExercise` produce structurally valid exercises, but the content has repeatable defects: passages that talk about themselves, correct answers that stand out, inference questions that are really detail questions, and factual drift. This plan changes the prompts, the `@Generable` schema and the app-side validation to fix what can be measured, and adds an evaluation harness so prompt changes are measured rather than eyeballed.

Sources:

- Apple, Foundation Models documentation, in particular *Prompting an on-device foundation model*, *Generating Swift data structures with guided generation*, *Supporting languages and locales*, *Managing the context window*, *Evaluating prompts to measure performance*, *Updating prompts for new model versions* and *Improving the safety of generative model output* (iOS 27 versions, read 2026-10-09).
- Apple, code-along 205 (trip planner): `Instructions {}`/`Prompt {}` builders, one-shot example, `prewarm()`, `includeSchemaInPrompt`.
- Gamut, *10 best practices*: declare properties in generation order, keep structures flat, static trusted instructions.
- 36 exercises generated on 2026-10-09 with the app's own files on macOS 27.0.1, which runs the same on-device model: 17 with the current prompts in English, 3 in Spanish, 16 with a revised variant. The raw samples are in [Leo-Exercise-Quality-Samples.md](Leo-Exercise-Quality-Samples.md).

Current app: `main` at `9fa521d`. The generator files are unchanged on `code-review-cleanup`, so this work branches from `main`.

### 1.1 What the samples showed

Scored over the 17 English exercises from the current prompts:

| Defect | Count | Example |
|---|---|---|
| Passage refers to itself, the author or the main idea | 6 | "They included the river to show a clear before and after." (9–11, purpose) |
| Correct answer clearly the longest option | 8 | "The ground shakes before the volcano starts to erupt." next to "Rain falls heavily on the top." |
| Inference question is a detail or general-knowledge question | 4 of 4 | "What did Emma try to find after seeing the torn notebook?" |
| Vocabulary word is the topic word or is defined in the passage | 2 of 3 | "What does 'bug' mean" on a passage about bugs |
| Passage under the requested range | 4 | all at 15–17 and 18+ |
| Passage evasive because of the "don't state the answer" rule | 1 | "one mineral is vital... this substance" instead of naming it |
| Explanation cut off mid-sentence and accepted | 1 | "The mention of" |
| Markdown asterisks in the passage | 1 | "A *space shuttle* is a vehicle" |

Facts drift at all ages ("insects do not fly much", a sleep stage that "lasts roughly 45 minutes", a hallucinated term "palabra franca"). Spanish output shows the same patterns, and the 6–8 passages in both languages are lists of 5-word sentences with no story.

The causes are structural:

- Properties generate in declaration order and the skill hint sits in the prompt, so "Ask why the author wrote the passage" is read while the passage is being written.
- "The passage must not state the answer word for word" is applied to every skill, which makes detail passages evasive.
- The correct answer and the distractors have different guides ("at most 15 words" against "about as long as the correct answer"), and the correct answer is written first.
- Each skill hint is one sentence, so the model falls back to a lookup question.
- Only the passage length is validated. A response cut off by `maximumResponseTokens` is accepted from the last partial snapshot.

### 1.2 Revised variant, measured

A variant with §2.1–§2.3 applied was run on the same 16 cases:

| Check | Current | Revised |
|---|---|---|
| Passage self-reference | 6 / 17 | 0 / 16 |
| Markdown in passage | 1 | 0 |
| Correct answer clearly longest | 8 | 4 |
| Option punctuation mismatch | 2 | 0 |
| Question wording copied into the correct answer only | 1 | 0 |
| Inference questions that are real inferences | 0 / 4 | 4 / 4 |
| Passage under requested range | 4 / 17 | 8 / 16 |

The variant called the passage "a short story or a short informative text", and 18+ passages dropped from 160–200 words to 114–152. Length wording is therefore kept exactly as it is today (§2.5). Two new problems appeared and are handled below: on stories, purpose questions treat the character as the author ("Why did Lena include the part about..."), §2.1; and "Quote the word" leaked into a 6–8 question, so the vocabulary hint no longer says it that way.

### 1.3 Decisions taken

| # | Question | Decision |
|---|---|---|
| D1 | Distractor count | **Always 3.** `.count(3)` in the schema; options are always 4. |
| D2 | Defective output | **Repair where possible, reject otherwise.** Punctuation, markdown and a truncated explanation are repaired app-side. Self-reference, a standout correct answer and duplicates are rejected and cost a retry. |
| D3 | Length control | **Keep today's word-range wording.** Schema-based length control (§6) is an experiment, not part of this plan. |
| D4 | Temperature by topic kind | **Phase 2, measured first** (§2.6). |
| D5 | Evaluation | **A harness in `scripts/`**, run by hand before prompt changes land. It is not a CI step. |

---

## 2. Design

### 2.1 Instructions and prompt

Apple's prompting guide: give the model a role with "You are an expert...", keep instructions to one to three paragraphs, use MUST for the rules the model keeps breaking, and move conditionals into code instead of listing rules that don't apply. The new instructions in `ExerciseGenerator.instructions`:

```
[locale line, §2.7]
You are an expert reading teacher who writes reading comprehension exercises for \(ageGroup.promptAudience).
You MUST write the passage, title, question, answers and explanation in \(language.name).
The passage is a story or an informative text \(wordRange). \(ageGroup.styleGuidance)
Write it as it would appear in a book for these readers: original, accurate, and about the topic only. \
It must never talk about itself: no "the author", "the passage", "the text", "the main idea", "this shows", \
and no lesson spelled out at the end. Stories have a character who wants something, a problem and an ending. \
Informative texts explain real, well-known facts. Plain text only, with no markdown, asterisks or headings.
Then write one question that tests the skill the prompt asks for, one correct answer and three wrong answers. \
Only the correct answer is supported by the passage; each wrong answer is believable but wrong according to the passage. \
All four answers MUST have the same length, form and punctuation, so the correct one does not stand out. \
Do not reuse the question's wording in the correct answer only. Never give away the answer in the question.
```

Removed from the instructions: "The passage must not state the answer word for word" (it moves into the main-idea and inference hints, §2.2), "even though these instructions are in English" (replaced by the MUST line and the locale line), and the "The main idea is" example (the answer guide covers it).

`prompt(topic:skill:)` becomes:

```
Write a reading comprehension exercise in \(language.name) about \(topic).
The passage must be \(wordRange).
Skill to test: \(skill.promptHint)
```

The word range stays in both places. The spec for V2 found the repetition necessary, and Apple's guide lists "repeat key instructions" as a strategy.

### 2.2 Skill hints

Each `ComprehensionSkill.promptHint` becomes three sentences: what the question asks, what the passage must do to make the skill testable, and what the wrong answers are. This is the change that fixed inference in the measured variant.

| Skill | Hint |
|---|---|
| mainIdea | The question asks what the passage is mostly about, or what its central message is. The passage must not state its own main idea or moral in a sentence; the reader works it out from the whole text. The wrong answers are details from the passage that are true but too narrow, or ideas the passage never supports. |
| detail | The question asks about one specific, important fact or event in the passage. State that fact plainly in the passage. The question and the correct answer must rephrase it in different words. The wrong answers are other things from the passage, slightly changed so they are false. |
| inference | The question asks about something the passage never says directly but clearly implies: how a character feels, why someone did something, what will probably happen next, or what caused something described. The passage must give the clues but never state the answer. The wrong answers are conclusions the clues do not support. |
| vocabulary | Use one word or expression in the passage that is slightly above the reader's level, in a sentence whose context shows its meaning. Do not define it in the passage, do not mark it in any way, and do not pick the topic word. The question asks what that word means in the passage and repeats the word. The wrong answers are meanings that word could have in other contexts, or meanings that fit the sentence badly. |
| purpose | The question asks why the writer wrote the passage, or why the writer included a specific event, detail or example. A character in a story is never the writer. The passage itself must never mention the writer, the reader, the passage or its purpose; it simply tells or explains. The wrong answers are purposes that sound reasonable but do not match what the passage actually does. |

### 2.3 Schema

`GeneratedExercise` keeps separate correct and incorrect fields (the app still places the correct answer), with these changes:

- **Order:** `passage`, `question`, `correctAnswer`, `incorrectAnswers`, `explanation`, `title`. The title moves last so it summarizes the passage instead of steering it (Gamut: summaries last).
- **Symmetric answer guides.** Correct: "The correct answer: a short phrase or sentence, at most 12 words, in your own words rather than copied from the passage". Incorrect: "Three wrong answers that a careless reader might pick: each about the topic, the same length, grammatical form and punctuation as the correct answer, and clearly wrong according to the passage", with `.count(3)`.
- **Passage guide:** "The reading passage: a story or an informative text, written exactly as it would appear in a book. Plain text, no headings, no markdown, no commentary about the text itself".
- **Question guide:** "One question that tests the skill requested in the prompt and can only be answered by someone who understood the passage".
- Explanation and title guides unchanged apart from "passage" replacing "text".

Descriptions stay short. Apple notes every description is sent as part of the schema and costs context; the whole request (instructions, schema, prompt, 1,200-token response cap) stays well inside the 4,096-token window.

### 2.4 Repair and validation

`Exercise.init?(generated:topic:skill:acceptedWordCount:)` grows a repair step before validation. Each rule is a small pure function in a new `ExerciseRepair` enum (in `Leo/Data/FoundationModels/`) so it can be tested without the model.

Repairs, applied in this order:

| Rule | Repair |
|---|---|
| Whitespace | Trim every field, as today. |
| Markdown | Remove `*`, `_` used as emphasis, `#` at line starts and backticks from passage, question, answers, title. |
| Option punctuation | If at least half of the four answers end in `.`, `!` or `?`, add a `.` to the ones that don't; otherwise strip terminal `.` from all. Applied after the correct answer joins the list, so all four are treated alike. |
| Truncated explanation | If the explanation doesn't end in terminal punctuation (`.`, `!`, `?`, closing quote), set it to `""`. The UI already handles an empty explanation. This is the fix for the `maximumResponseTokens` cut-off, which the framework doesn't report. |

Rejections (return `nil`, the generator tries the next topic):

| Rule | Check |
|---|---|
| Passage length | `acceptedWordCount.contains(passage.wordCount)`, as today. |
| Distractors | Exactly 3 after dropping empties and case-insensitive duplicates of each other or of the correct answer. |
| Empty fields | Correct answer or question empty, as today. |
| Self-reference | The passage matches a short phrase list per supported language: English "the author", "the writer", "the passage", "the text", "the main idea", "this shows", "this passage"; Spanish "el autor", "la autora", "el texto", "el pasaje", "la idea principal"; Portuguese "o autor", "a autora", "o texto", "a passagem", "a ideia principal". Case-insensitive, whole words. Other languages get no check. |
| Standout correct answer | The correct answer's word count is more than 1.5 × the longest distractor's and at least 3 words longer. |

The thresholds for the last two rules are tuned with the harness (§3) before the PR merges: the target is a rejection rate under 10% per attempt with the new prompts. If a rule rejects more than that, it ships as a log line only and is tightened later.

Logging: each rejection reason is logged with the skill and topic, so on-device logs show which rule fires.

### 2.5 Length

The word-range wording is unchanged, including the 10–13 sentence request for 6–8, 9–11 and 12–14. The word "short" is never used next to the passage; the measured variant showed it costs 18+ around 40 words. The streamed runaway check and the 1,200-token cap stay.

### 2.6 Temperature by topic kind (phase 2)

Apple's dynamic profile example uses 0.8 for creative tasks and 0.1–0.2 for precise ones. Leo uses 0.8 for everything. Plan:

- Add `kind: TopicKind` (`.story`, `.informative`) to `DefaultTopic` and `RoundTopic`. Default topics whose prompt starts with "a story", "a short story", "a short fictional story" or "a short piece of literary fiction" are `.story`; the rest `.informative`. Custom topics are `.informative` for now.
- `GenerationOptions(temperature:)` becomes 0.8 for `.story`, 0.5 for `.informative`.
- Informative prompts add one sentence: "Use well-known facts, and avoid exact figures and dates unless they are famous."

This lands only if the harness shows fewer factual oddities at 0.5 without a drop in passage length or variety across two runs of the same topic. If passages become repetitive, try 0.6.

### 2.7 Locale

Apple's locale guide: for locales other than US English, start the instructions with the exact phrase "The person's locale is \(identifier)." which comes from the model's training and reduces multilingual hallucination, then state the output language with MUST. `ContentLanguage` gains:

```swift
/// Apple's locale phrase for non-US-English readers, empty for en_US. Goes first in instructions.
var localeInstruction: String
```

returning `"The person's locale is \(locale.identifier)."` unless `locale.language` is equivalent to `en_US`. `ExerciseGenerator.instructions` and `TopicValidator`'s instructions start with it. `TopicValidator` keeps its own prompts otherwise.

### 2.8 Unchanged

A fresh session per exercise, streaming with the runaway check, the 3-attempt loop, the English prompts with content in the reader's language, the custom-topic review, and the quiz's round plan. `includeSchemaInPrompt: false` is not adopted: it is meant for prompts that carry a full example, and Apple warns small models copy long examples, so this plan has no example exercise in the prompt.

---

## 3. Evaluation harness

Apple's evaluation guide asks for fixed scenarios, rule-based checks and a repeatable workflow. The harness used for §1.2 becomes `scripts/exercise-eval/`:

- `build.sh` copies `AgeGroup`, `Exercise`, `ComprehensionSkill`, `Topic`, `RoundTopic`, `ContentLanguage`, `ExerciseGenerator`, `GeneratedExercise`, `PromptVocabulary`, `ExerciseRepository` (and `ExerciseRepair`) into a temp directory and compiles them with `main.swift` via `swiftc -parse-as-library`. No Xcode project changes. It needs a Mac with Apple Intelligence on; the spec for V2 already relies on this.
- `main.swift` takes `<age> <skill> <topic> [count] [language]` and prints one block per exercise. A `--all` mode runs the fixed scenario list: every skill at every age group on two default topics (one story, one informative), 50 exercises, about 8 minutes.
- `score.py` parses the output and reports per file: failures, passage self-reference, markdown, standout correct answer, punctuation mismatch, question-wording leak, truncated explanation, passages under range. It is the rule set of §2.4 plus the two under-range and leak counts.
- `README.md` records the baseline table from §1.1 and §1.2 and the rule: a prompt change lands with a before/after table in its PR.

A model-as-judge check ("Can the question be answered from the passage alone, and is exactly one option correct?") in a second `LanguageModelSession` is a follow-up for the harness, not for the app.

---

## 4. Tests

### 4.1 Existing tests that change

- `ExerciseGeneratorPromptTests`: `instructions` also expects the role line and, for Spanish, the locale phrase; `prompt` expects "Skill to test:". The five prompt snapshots are re-recorded.
- `ExerciseTests`: `wrongDistractorCount` now rejects 2 distractors too; `validInput` uses 3; `.fixture` argument order follows the new property order (labels keep it source-compatible).
- `DefaultTopicsTests.comprehensionSkills`: unchanged. Add a check that every `promptHint` has at least three sentences.

### 4.2 New tests

`ExerciseRepairTests` (pure functions, no model):

- Markdown removed from passage and options; a `*` inside a word count is left alone.
- Punctuation: 3 of 4 with periods → all 4; 1 of 4 → none; questions and exclamations count as terminal.
- Truncated explanation becomes empty; a complete one is untouched; one ending in `”` is complete.
- Self-reference: rejects "The author wanted to show" and "El autor quiso", accepts "Author Street" only if whole-word matching is implemented as specified, accepts a Japanese passage (no list).
- Standout: 9-word correct vs 4-word distractors → rejected; 6 vs 4 → accepted; the "at least 3 words longer" guard keeps short answers from being rejected by ratio alone.

`ContentLanguageTests`: `localeInstruction` is empty for `en_US`, "The person's locale is es_ES." for Spanish, and non-empty for `en_GB`.

`ExerciseGeneratorLiveTests` (tag `liveModel`, results vary): extend `generatesUsableExercise` to run every skill at `.nine` and `.adult`, and `#expect` the §2.4 rules hold on the result, since the generator already applied them. Add one Spanish case.

### 4.3 Hand checks

1. Simulator, English, 9–11: a full round. Read every passage for self-reference; none expected. Count how often the correct answer is visibly the longest; expect it in no more than 1 of 6.
2. Same at 18+: passages between 150 and 230 words.
3. Simulator in Spanish, 6–8: passages read as a story, not a list, and the explanation is in Spanish and complete.
4. Inference exercises at 12–14 and 15–17: the question asks for a feeling, motive, cause or prediction, and the answer is not a sentence from the passage.
5. A purpose exercise on a story topic: the question says "the writer", never a character's name.
6. Reduce the word range temporarily to force rejections, and confirm the log names the rule and the next topic is tried.

---

## 5. Docs

- README "Writing exercises": mention that the app repairs punctuation and markdown and rejects passages that describe themselves, and that 3 distractors are fixed.
- `docs/Leo-V2-specifications.md` §"Leo/Models/Exercise.swift": note the move to 3 distractors and link here.
- `scripts/exercise-eval/README.md` as in §3.

---

## 6. Delivery

1. **PR A, prompts and schema:** §2.1, §2.2, §2.3, §2.5, §4.1, with the harness before/after table in the description.
2. **PR B, repair and validation:** §2.4 and `ExerciseRepairTests`, thresholds tuned with the harness.
3. **PR C, harness:** §3, so A and B can cite it. It can land first if preferred.
4. **PR D, locale:** §2.7 and its tests.
5. **PR E, temperature by kind:** §2.6, only with measurements.

## 7. Later: experiments

Not in this plan. Each has a hypothesis and a pass criterion for the harness.

- **Answers as one array.** `answers: [Answer]` with `Answer { text; isCorrect }` and `.count(4)`; the app checks exactly one is correct and shuffles as today. Hypothesis: one guide for all four removes the standout answer better than symmetric guides. Pass: standout rate under 10% and fewer than 5% responses with zero or several correct flags.
- **Passage as sentences.** `sentences: [String]` with `.count(8...11)` for 6–8 and 9–11 (`paragraphs` with `.count(2...3)` for 15+), joined by the app. Hypothesis: the constrained sampler enforces counts exactly, so lengths land in range without the list-like text the current sentence request produces. Pass: under-range rate under 10% and passages read as a story in hand checks.
- **Evidence field.** An `evidence: String` property between `question` and `correctAnswer` ("the sentence in the passage the answer rests on"), following Apple's advice to give the model a reasoning field before the answer. Hypothesis: fewer unsupported correct answers. Cost: about 30 more output tokens.
- **Model-as-judge in the harness** (§3).

---

## 8. Implementation notes (2026-10-09)

Measured with `scripts/exercise-eval` (two `--all` runs of 50 per version). Departures from the plan above:

- **PR A, the kind of passage moved forward from §2.6.** With the prompts as written in §2.1 and §2.2, about half the informative topics at 6–8 and 9–11 became stories about a child ("volcanoes" became a boy who flees a mountain; "the human body" became a forest story with no body in it). `TopicKind` (§2.6) therefore lands in PR A, and the prompt states the kind: "The passage is a story." or "The passage is an informative text that explains real, well-known facts about <topic>. It is not a story and has no main character." The instructions' "Stories have a character who wants something, a problem and an ending. Informative texts explain real, well-known facts." line was dropped: describing the plot made stories 15 to 30 words shorter, so 6–8 stories still read as lists, as before. Kinds come from the topic prompt by whole word ("story", "fiction", "fictional"), so "music history" stays informative.
- **PR A, purpose hint.** As planned, 3 of 7 purpose questions asked about a character's motive ("Why did Liam include the strange mark?"). The hint now says the question "MUST say "the writer"".
