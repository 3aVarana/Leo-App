# Exercise evaluation harness

Generates exercises with the app's own `ExerciseGenerator` on this Mac and scores them with rule-based checks, so a prompt change is measured instead of eyeballed. Background and the rules it checks: [docs/Leo-Exercise-Quality-Plan.md](../../docs/Leo-Exercise-Quality-Plan.md), sections 2.4 and 3.

**The rule:** a change to the prompts, the `@Generable` schema or the repair rules lands with a before/after table from this harness in its pull request.

## Requirements

A Mac with Apple Intelligence turned on. macOS runs the same on-device model as iOS, so results carry over to the app. Nothing here touches the Xcode project or runs in CI.

## Build

```bash
scripts/exercise-eval/build.sh
```

This copies the generator's source files from `Leo/` into a temporary folder, compiles them with [`main.swift`](main.swift) and writes `build/exercise-eval/harness`. Rebuild after every change to the app's files; to compare two versions, build each into its own folder (`build.sh <out-dir>`).

## Run

One case, several times:

```bash
build/exercise-eval/harness 9-11 inference volcanoes 5
```

Arguments: `<age> <skill> <topic> [count] [language]`. Ages are `6-8`, `9-11`, `12-14`, `15-17`, `18+`; skills are `mainIdea`, `detail`, `inference`, `vocabulary`, `purpose`; the language is a locale identifier such as `es_ES` (default `en_US`).

The fixed scenario list, used for before/after tables:

```bash
build/exercise-eval/harness --all > after.txt
```

Every skill at every age group on two default topics, one story and one informative, 50 exercises in about 8 minutes. `--all es_ES` runs the same list in Spanish. The topics are in `scenarioTopics` in `main.swift`; changing them makes runs incomparable with the baseline below.

Each topic gets one attempt, so an exercise the app rejects is printed as `FAILED` instead of being replaced. The app logs the reason; to see which rule fired, run this after a run (`log` alone is a zsh builtin):

```bash
/usr/bin/log show --last 15m --style compact --predicate 'subsystem == "Leo" AND category == "ExerciseGenerator"'
```

## Score

```bash
python3 scripts/exercise-eval/score.py before.txt after.txt
```

| Column | Counts |
|---|---|
| failed | Exercises the app rejected, or generation errors (guardrails, runaway passages) |
| self-ref | Passages that talk about themselves: "the author", "the passage", "the main idea", "this shows"... |
| markdown | Passages with `*`, `_` emphasis, backticks or `#` headings |
| standout | Correct answers more than 1.5 × and at least 3 words longer than the longest wrong answer (the app's rejection rule) |
| longest+25% | Correct answers more than 1.25 × the longest wrong answer (the looser count of the baseline) |
| punct | Exercises whose four answers don't all end the same way |
| q-leak | The correct answer, and only it, reuses the question's wording |
| expl cut | Explanations that stop mid-sentence |
| under range | Passages shorter than the range the prompt asks for (accepted passages can be down to 60% of it) |

Since the app repairs and rejects, most columns read 0 once those rules are in place; the remaining signal is in failed, longest+25%, q-leak and under range, and in reading the passages. Run `--all` twice: one run of 50 varies by a few points per column.

The checks can't see whether facts are right, whether an inference question is a real inference, or whether a story reads as a story. Read the output for those.

## Baseline

`main` at `45d2260`, before the quality plan, two runs of `--all` on 2026-10-09 (macOS 27.0.1):

| run | exercises | failed | self-ref | markdown | standout | longest+25% | punct | q-leak | expl cut | under range |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 50 | 3 | 7 | 2 | 3 | 10 | 4 | 1 | 0 | 17 |
| 2 | 50 | 5 | 8 | 1 | 7 | 14 | 1 | 3 | 0 | 11 |

The hand-scored audit samples behind the plan are in [docs/Leo-Exercise-Quality-Samples.md](../../docs/Leo-Exercise-Quality-Samples.md).
