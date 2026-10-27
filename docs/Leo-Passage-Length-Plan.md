# Passage length at 15–17 and 18+: plan

Written 2026-10-27. Status: step 0 done, step 2 decided (B: 14 to 17 sentences at 15–17, 18 to 22 at 18+), in PR #47. Step 1 not started.

**Decision (2026-10-27):** 15–17 asks for "about 150 words in 14 to 17 sentences" (`passageSentenceRange` 14...17), with no sentence-length line. On the iPhone that's 26/30 accepted (§3.3), against 1/30 before. The passages read as lists of short facts. That's accepted for now as the cost of a passage the phone will write; an example passage in the instructions is the remaining lever if it needs improving.

**Decision (2026-10-27), 18+:** adults ask for "about 195 words in 18 to 22 sentences" (`passageSentenceRange` 18...22). On the iPhone that's 27/30 accepted (§3.5), against 10/30 with no sentence count. Every group now gets a sentence count, so `passageSentenceRange` is no longer optional.

## 1. The problem

Profiling on the iPhone with the Foundation Models instrument, 15–17 exercises are rejected for `passageLength` 10 to 15 times in a row before one is accepted, so each exercise takes more than a minute and the round sometimes reaches `GenerationFailedView`. 6–8 and 9–11 have almost no delay. 12–14 and 18+ are slow only on the first exercise.

The rules today (`AgeGroup`):

| | 15–17 |
|---|---|
| Requested (`passageWordRange`) | 120–180 words, "about 150" |
| Accepted (`acceptedWordCount`) | 72–270 words (60% of the lower bound, 150% of the upper) |
| Sentence count in the prompt (`passageSentenceRange`) | none (6–14 get "10 to 13 sentences") |

## 2. The rejected samples

Counted with the app's own `String.wordCount` (`.byWords`):

| # | Title | Words | Sentences | Exercise as a whole |
|---|---|---|---|---|
| 1 | History's Unsolved Symbols | 52 | 4 | Broken: the passage says the Nazca Lines' "purpose stays unclear", so the wrong answer "Nazca Lines' meaning is ambiguous" is also correct |
| 2 | Sports Science and Movement Efficiency | 38 | 6 | A list of six separate claims, not a text |
| 3 | Earth's Fury: Plates and Power | 45 | 5 | Usable |
| 4 | Carnival Celebrations Across Cultures | 47 | 5 | Weak: the answer "excitement" is a guess the passage barely supports; "Carnevale" is misspelled |
| 5 | Cats and Their Grooming Habits | 23 | 2 | Broken: the answer "vigilance" isn't in the passage, and the question's "she" and "his" don't match it |
| 6 | Secrets of Ancient Discoveries | 59 | 5 | Usable, though "Excitement sparks their research" is close to right too |

**Verdict: the rule rejected all six correctly.** They are 23–59 words. That is under the 72-word floor, and under 6–8's own 50–80 range. Accepting them would break what the app promises 15–17 readers: "Richer vocabulary · 120–180 words" in onboarding and "A 150-word text" on the loading screen. Only 2 of the 6 would be good exercises even if length didn't matter. The short passages are a symptom: the model wrote 4–6 sentences of about 10 words each and stopped.

## 3. It doesn't happen on the Mac

The evaluation harness (`scripts/exercise-eval`) was run on this Mac (macOS 27.0.1) at 15–17: 3 default topics (ancient civilizations, sports science, animal behavior) × 5 skills × 2 runs, one attempt each.

| Version | Accepted | Words: mean (min–max) | Under 120 | Rejected for length | Other failures |
|---|---|---|---|---|---|
| Current `HEAD` | 28 / 30 | 104 (76–130) | 23 / 28 | **0** | 2 standout answer |
| + "in 10 to 13 sentences" at 15–17 | 24 / 30 | 114 (86–147) | 15 / 24 | **0** | 4 standout answer, 1 runaway, 1 parse error |

So on the Mac's model, 15–17 passages are about 100 words: short of the requested 120–180, but never under 72. The phone writes about half that. Either the iPhone's on-device model differs from the Mac's (a different OS version ships a different model), or something about the device run differs. **Any fix has to be measured on the iPhone**, because the Mac harness can't see this problem.

### 3.1 Step 0 result: the iPhone against the Mac's model (2026-10-27)

`PassageLengthLiveTests` (step 0) run on the iPhone and on the iPhone 18 Pro simulator, which uses the Mac's model. Same code (`HEAD` with no prompt change), same 30 cases:

| Device | OS | Accepted | Rejected for length | Words: mean (min–max) | Sentences: mean | Seconds per attempt |
|---|---|---|---|---|---|---|
| iPhone 17 | iOS 27.2 (24B119) | **1 / 30** | **27** | 42 (5–72) | 4.6 | 4.5 |
| Simulator (Mac's model) | macOS 27.0.1 | 27 / 30 | 0 | 107 (93–153) | 10.2 | 6.6 |

The other 2 iPhone attempts were parse errors, where the model stopped before the question or the title. The other 3 simulator attempts were standout-answer rejections. Two iPhone passages were 5 and 6 words, probably a title alone. The iPhone's only acceptance was exactly 72 words, the floor.

So the iOS 27.2 model writes about 4–5 sentences, whatever "about 150 words" asks for. The Mac's model writes about 10. 6–14 have no delay on the same phone, and they are the groups whose prompt also asks for "10 to 13 sentences". That makes option B the cheapest next measurement, and A the fallback if the phone ignores a requested count.

### 3.2 Option B on the iPhone (2026-10-27)

The same 30 cases on the same iPhone, with `.fifteen` given `10 ... 13` in `passageSentenceRange` ("about 150 words in 10 to 13 sentences"):

| Version | Accepted | Rejected for length | Words: mean (min–max) | Under 120 | Sentences: mean (min–max) | Seconds per attempt |
|---|---|---|---|---|---|---|
| No sentence count (§3.1) | 1 / 30 | 27 | 42 (5–72) | 30 / 30 | 4.6 | 4.5 |
| "10 to 13 sentences" | **19 / 30** | **11** | 80 (60–121) | 29 / 30 | 10.7 (10–13) | 4.6 |

The phone kept to the sentence count in all 30 attempts, but its sentences are short, about 7.5 words each. Every remaining rejection is 60–70 words, just under the 72 floor. No other rule fired, and there were no parse errors this time.

With 3 topics per exercise, an exercise now fails only if all 3 are rejected: about 5% (0.37³), against about 90% before. It needs about 1.6 attempts on average, about 7 seconds. Passages are still well under the requested 120–180 words, and 10 sentences of 7 words risk reading as a list. That's the 6–8 problem from the exercise-quality plan, still to be checked by hand.

Since the phone keeps to a sentence count exactly, the next lever is the count itself: about 16 sentences at 7.5 words would reach 120. Option A isn't needed for the count.

### 3.3 "14 to 17 sentences" on the iPhone (2026-10-27)

| Sentence count | Accepted | Rejected for length | Other rejections | Words: mean (min–max) | Sentences: mean | Words per sentence | Seconds per attempt |
|---|---|---|---|---|---|---|---|
| none | 1 / 30 | 27 | 2 parse errors | 42 (5–72) | 4.6 | 9.1 | 4.5 |
| 10 to 13 | 19 / 30 | 11 | 0 | 80 (60–121) | 10.7 | 7.5 | 4.6 |
| 14 to 17 | **26 / 30** | **2** | 2 standout answer | 91 (64–123) | 14.4 | 6.3 | 5.1 |

The phone again kept to the count (14–16 sentences every time), but it made its sentences shorter: 4 more sentences added only about 11 words. With 3 topics per exercise, an exercise now fails about 0.2% of the time ((4/30)³). Passages are still under 120 words in 27 of 30 attempts.

Reading them (all 30 are in `build/passage-samples-15-17.md`, which is not committed): most are lists of 6-word facts, one per sentence ("They built monumental pyramids. They practiced mathematics and astronomy. The Egyptians created hieroglyphs."), with little connection between them and some invented detail ("Children assisted with smaller tasks"). That's below the "clear structure and moderately rich vocabulary" asked for at 15–17.

### 3.4 Adding a sentence-length line on the iPhone (2026-10-27)

"14 to 17 sentences" plus, in `styleGuidance` for `.fifteen`: "Vary your sentences and connect each one to the last, with most sentences 10 to 15 words long."

| Version | Accepted | Rejected for length | Words: mean (min–max) | Sentences: mean | Words per sentence |
|---|---|---|---|---|---|
| 14 to 17 (§3.3) | 26 / 30 | 2 | 91 (64–123) | 14.4 | 6.3 |
| 14 to 17 + style line | **18 / 30** | **12** | 77 (51–136) | 15.8 | 4.9 |

Worse on every count. The phone ignored the words-per-sentence request, and its sentences got shorter still. Two passages ran to 28 and 32 sentences of 3–5 words ("Its impact endured. Generations adapted. The river bridged eras."). The passages read no more connected than in §3.3. All 30 are in `build/passage-samples-15-17-style.md`. On this model, a sentence count is followed and a sentence length isn't.

### 3.5 18+ on the iPhone (2026-10-27)

The same test with `group` set to `.adult` and 3 adult default topics (turning points in history, scientific breakthroughs, psychology and habits) × 5 skills × 2 runs. 18+ asks for 160–230 words ("about 195") and accepts 96–345.

| Sentence count | Accepted | Rejected for length | Other failures | Words: mean (min–max) | Sentences: mean | Words per sentence | Seconds per attempt |
|---|---|---|---|---|---|---|---|
| none | 10 / 30 | 17 | 2 parse errors, 1 guardrail | 89 (7–137) | 9.4 | 9.5 | 3–6 |
| 14 to 17 | 23 / 29 | 5 | 1 guardrail | 112 (70–143) | 14.5 | 7.7 | 4–8 |
| 18 to 22 | **27 / 30** | **1** | 2 guardrail | 139 (94–199) | 18.3 | 7.6 | 5–8 |

Without a sentence count, the phone writes adults about 9 sentences, under half the requested length. Vocabulary was 0/6. Passages with 12 or more sentences were almost always accepted. The phone kept to both counts (16–22 sentences at 18 to 22), and nothing ran past the 345 ceiling, so the run-on seen on the Mac (§3) didn't happen here. At 14 to 17, four psychology passages had 14–15 sentences of about 5 words and were rejected at 70–94 words, so 18+ needs the higher count. Passages are still under 160 words in most attempts.

The passages read like 15–17's: lists of one-fact sentences, with some wrong facts ("The development of vaccines eradicated infectious diseases"). All three versions are in `build/passage-samples-adult.md`, which is not committed.

The 14 to 17 run was rate-limited by the system ("Client rate limit exceeded") after about 20 requests in a row. Psychology and habits was rerun on its own, and one case (scientific breakthroughs, purpose, run 2) is missing, hence 29.

The sentence count added about 10 words on the Mac and halved the share under 120. The extra failures are within noise at n = 30, but the runaway matches the 2026-10-04 note that asking older groups for sentences "makes passages run on".

## 4. Plan

### Step 0: measure on the iPhone (do first)

The `LeoLiveModel` test plan already runs the real model and can run on the phone. Add one test that runs N single attempts at 15–17 and records the passage word and sentence counts, the rejection reason and the time for each, with `Attachment` or `print`. Run it on the iPhone:

```bash
xcodebuild test -scheme Leo -testPlan LeoLiveModel -destination 'platform=iOS,name=<iPhone name>' -only-testing:LeoTests/LiveModel/PassageLengthLiveTests
```

It measures 15–17. Set its `group` to `.adult` to measure 18+ with adult topics. The phone must stay unlocked, and back-to-back runs can be rate-limited by the system.

Run it once for the current code and once for each variant below, with the same 3 topics × 5 skills × 2 runs as §3, so the iPhone numbers line up with the Mac's. Also note the iPhone's iOS version and the Mac's macOS version for the record.

### Step 1: reject short passages as soon as they're finished (no quality risk)

Properties stream in declaration order, so the passage is final as soon as `snapshot.content.question` is non-nil. In `ExerciseGenerator.respond`, next to the runaway check: if the question has started and `passage.wordCount < acceptedWordCount.lowerBound`, throw a `ShortPassage` error, with the outcome `"short passage"` on the signpost. At the moment a rejected attempt still writes the question, four answers, the explanation and the title before it's thrown away. For a 50-word passage that's more than half of the output tokens. This doesn't lower the number of rejections, but each one costs roughly half as long, and the 3 topics per exercise are tried sooner.

Tests: a stub stream isn't available for `LanguageModelSession`, so cover it with a unit test of a small helper, for example `passageIsFinished(_ snapshot:)`, plus the step 0 live run.

### Step 2: make the model write a longer passage at 15–17 (pick from step 0's numbers)

In order of preference:

- **A. Passage as sentences.** `@Guide(.count(10...13)) var sentences: [String]` in place of `passage`, joined by the app before `ExerciseRepair`. The constrained sampler enforces the count whatever the model would do on its own, so the floor holds on any OS's model. §7 of the exercise-quality plan measured this at 6–14: under range 2/58 against 20/56, and the passages read as more connected. It was never tried at 15–17 (only paragraphs, which failed). Cost: a schema change for every age, or a second `@Generable` type for the ages that use it. Risks: list-like text and the run-on seen in §3. Read the output, not just the counts.
- **B. Sentence count in the prompt (chosen, as 14 to 17; see §3.2–3.4).** Give `.fifteen` `10 ... 13` in `passageSentenceRange` (a one-line change, measured in §3 on the Mac). This is cheaper than A, but it's a request, not a guarantee, and the phone may ignore it as it ignores "about 150 words".
- **C. Lower the range.** If neither A nor B gets the phone near 120 words, ask for what it can write, for example `passageWordRange` 90–140 at 15–17 (floor 54). `summary` and the loading screen follow automatically. Lowering only the 60% floor, as the samples might suggest, isn't recommended: the app would ask for 150 words, accept 40, and still show "120–180".

Keep step 1 whichever of A–C is chosen.

### Not proposed

- **Accepting the samples as they are**: see §2.
- **Asking the model to continue a short passage** in the same session: this needs a second request per short passage, and new sentences can make a wrong answer true.

## 5. Done when

- On the iPhone, at least 90% of 15–17 attempts pass the length check, and no exercise needs more than one topic for length reasons in the step 0 run.
- The rejected attempts that remain end at the passage (step 1), as the "short passage" signpost outcome shows.
- The harness `--all` on the Mac shows no regression in the other columns, per the harness README rule.
- A hand check of 6 accepted 15–17 exercises on the iPhone: the passages read as texts, not lists.

## 6. Open questions

1. ~~Which iOS version is the iPhone on?~~ iOS 27.2 (24B119), see §3.1.
2. If A works, use it only at 15–17 (and maybe 18+), or at every age?
3. Is lowering the 15–17 range (C) acceptable as a last resort?
