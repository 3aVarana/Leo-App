# Leo Resilient Generation Plan

## 1. Scope and sources

`QuizViewModel.generateRemaining()` writes a round's 6 exercises one at a time and stops at the first failure. The reader then sees the failure screen when they reach that exercise, even though the rest of the round was never tried. Each failure is already 3 failed model calls: `ExerciseGenerator.generate` tries the main topic and two spares before it throws.

This plan keeps generation going after a failure and automatically queues a replacement exercise, so the failure screen becomes a last resort. Generation stays sequential. Parallel generation is left for later, but the design keeps it a small follow-up (§6).

Current app: `main` at `ebc0d8d`. The `code-review-cleanup` branch (3 commits on top) touches topic minimums, not `QuizViewModel`'s generation, so this work can branch from `main`.

### 1.1 Decisions taken

| # | Question | Decision |
|---|---|---|
| D1 | Approach | **Option 2:** a queue of jobs with limited automatic replacement, generated sequentially. |
| D2 | Round size | **Always 6 exercises.** A round never ends short. If generation can't produce 6, the failure screen still blocks at the gap. |
| D3 | Replacement limit | **Up to 3 automatic replacements per round.** A new round ("Practice again", a settings change) starts with 3 again. |
| D4 | Replacement skill | **Same skill as the failed exercise**, with different topics. This keeps `makePlan`'s guarantee that every `ComprehensionSkill` appears at least once. |
| D5 | Order | **The reader gets the next ready exercise.** Exercises are shown in the order they finish, not in plan order. |
| D6 | Parallelism | **Not now.** Sequential generation, with a measurement spike before any parallel work. |
| D7 | Manual retry and the limit | **Outside the limit.** "Try again" and "Try a different topic" never count against the 3 and never reset it. If a manual retry fails, the failure screen comes back at once. |

---

## 2. Design

### 2.1 State

Replace the in-order `exercises` array and the `generationFailed` flag with a job queue:

| Property | Meaning |
|---|---|
| `plan: [PlanItem]` | The round as planned. Unchanged: it still feeds `plannedTopicNames` (Welcome), so Welcome's topic list doesn't change while the reader is looking at it. |
| `queue: [PlanItem]` | Jobs still to generate, in order. The first one is being written. Starts as a copy of `plan`. |
| `exercises: [Exercise]` | Ready exercises, **in the order they finished**. The reader's exercise is `exercises[currentIndex]`. |
| `failedJobs: [PlanItem]` | Jobs that failed after the replacements ran out. Kept for manual retry. |
| `replacementsLeft: Int` | Starts at `maxReplacements` (`3`) in `prepareRound()`. |

**Invariant:** `exercises.count + queue.count + failedJobs.count == exerciseCount`. A failed job is either swapped for a replacement (queue length unchanged) or moved to `failedJobs`. Tests assert this after every step (§3).

Two facts follow from the design, and the code can rely on them:

- **Generation is stuck exactly when** `queue.isEmpty && exercises.count < exerciseCount`. Then `failedJobs.count` equals the shortfall.
- **`failedJobs` is non-empty only when `replacementsLeft == 0`.** So D7 needs no extra code: manual retry simply never touches `replacementsLeft`.

### 2.2 `generateRemaining()`

```
while let item = queue.first {
    writingTopicName = item.topics.first?.name
    do {
        let exercise = try await repository.exercise(topics: item.topics, skill: item.skill) { … unchanged … }
        guard !Task.isCancelled else { return }
        queue.removeFirst()
        exercises.append(exercise)
    } catch {
        guard !Task.isCancelled, !(error is CancellationError) else { return }
        queue.removeFirst()
        handleFailure(of: item, error)
    }
    if phase == .loading {
        showCurrent()
    }
}
```

- Remove the job only after the result arrives. A cancelled task returns before mutating anything, as today.
- `generationNumber` and the `onAttempt` stale check stay as they are. One generation task at a time is still true.
- Update the doc comments on the class (line 5) and on `generateRemaining()`.

### 2.3 `handleFailure(of:_:)`

- If `replacementsLeft > 0`: decrement it and **append** `PlanItem(topics: replacementTopics(…), skill: item.skill)` to the back of `queue`. Appending, rather than inserting at the front, lets the remaining planned jobs finish first. The total work is the same either way.
- Otherwise: append `item` to `failedJobs`.
- Log both cases, with the skill, the failed main topic and the replacements left, so on-device logs show how often the limit is reached.

### 2.4 Replacement topics

Move the topic choice out of `retryWithDifferentTopics()` into a testable static function, used both by automatic replacement and by the manual button:

```swift
/// Up to 3 topics for another try at a failed exercise, those it didn't just try first.
static func replacementTopics(
    for failed: [RoundTopic],
    from topics: [RoundTopic],
    using rng: inout some RandomNumberGenerator,
) -> [RoundTopic]
```

The behavior is the existing one: untried topics shuffled first, then tried ones shuffled, capped at 3. With 3 topics or fewer, the same topics come back in another order.

### 2.5 Showing exercises

`showCurrent()`:

- `currentIndex < exercises.count` → `.answering`, as today.
- Otherwise → `queue.isEmpty ? .failed : .loading`.

So a reader waiting on a slow or failed job gets whichever job finishes next (D5). They only see `.failed` once nothing is left to generate.

`dotState(at:)` is unchanged: a dot shows `.failed` only when the reader is blocked on it.

### 2.6 Manual retry

Both buttons are allowed only when generation is stuck: `settings != nil && queue.isEmpty && !failedJobs.isEmpty`.

- **`retry()`:** `queue = failedJobs`, `failedJobs = []`, `phase = .loading`, `generateRemaining()`. Same topics; sampling often succeeds on a second try.
- **`retryWithDifferentTopics()`:** the same, but each job gets `replacementTopics(for: job.topics, from: settings.topics)`. The skill is kept.
- Neither changes `replacementsLeft`. It is already 0 here (§2.1), so a job that fails again goes straight back to `failedJobs`.
- If more than one job failed, all of them are requeued. If only some succeed, the reader answers those, then sees the failure screen again for the rest.

### 2.7 The failure screen's topic

`plannedTopicName(at:)` assumes exercise *i* is `plan[i]`, which is no longer true. It is only used by the failure screen.

- Remove it and add `var failedTopicName: String? { failedJobs.first?.topics.first?.name }`.
- In `RootView`, pass `topicName: quiz.failedTopicName` to `GenerationFailedView`. The view and its snapshots don't change.
- "Text N didn't print" still uses `currentIndex`, which is the reader's position. That's still correct.

### 2.8 Unchanged

- `ExerciseRepository`, `ExerciseGenerator` and the 3-topic fallback within one job.
- `makePlan`, `plannedTopicNames`, `writingTopicName` (still the topic of the job being written, which is the one the waiting reader will get), `LoadingView`, `GenerationFailedView`, `ProgressDots`.

---

## 3. Tests

All in `LeoTests/Features/`. The stub answers calls in call order, which still works because generation is sequential. A small helper that builds a results list from a pattern (for example `"S F S S S S S"`) keeps the new tests readable.

### 3.1 Existing tests that change meaning

| Test | Today | After |
|---|---|---|
| `failureWhileWaiting` | One failure → `.failed` | One failure → still `.loading`, then the next job's exercise shows. Rename it `failureWhileWaitingShowsNextReady`. |
| `failureShowsWhenReaderReachesIt`, `quizFailedAtSecondExercise` | One failure at job 2 | Script 4 failures (job 2 plus its 3 replacements) so the failure screen appears when the reader reaches the gap. |
| `retryGeneratesFailedExerciseAgain` | Retries `calls[1]` | Retries the job that failed last, with the same topics and skill. Assert that no automatic replacement follows a failed retry. |
| `retryWithDifferentTopicsAvoidsFailedTopics`, `retryWithDifferentTopicsWithoutOthers` | Failure at job 2 | Same assertions, reached after the limit is used up. |
| `retryWhenRoundIsGeneratedDoesNothing` | | Unchanged. |
| `plannedTopicNames` (Round tests) | Uses `plannedTopicName(at:)` | Drop the `plannedTopicName(at:)` lines. |
| Round test asserting `[.done, .failed, .upcoming…]` (line ~138) | | Needs 4 failures to reach `.failed`. |

### 3.2 New tests

| Test | Checks |
|---|---|
| `failureIsReplacedWithSameSkill` | Job 2 fails → call 7 has job 2's skill and topics outside job 2's topics where possible. The round ends with 6 exercises and never shows `.failed`. |
| `generationContinuesAfterFailure` | After a failure, the next planned job is requested right away (calls 3…6 happen). |
| `readerGetsNextReadyExercise` | Job 1 fails while the reader waits on Loading → the reader sees job 2's exercise at index 0. |
| `replacementLimitIsThreePerRound` | 4 failures → exactly 9 calls (6 + 3), the 4th failed job lands in `failedJobs`, and `.failed` appears only when the reader reaches index 5. |
| `failureAfterLimitStillGeneratesTheRest` | With the limit used up early, later jobs still run, and each further failure adds to the shortfall. |
| `failedTopicNameIsFirstFailedJob` | The failure screen's topic is the failed job's main topic. |
| `manualRetryDoesNotUseOrResetLimit` | A failed manual retry → `.failed` again with exactly one more call. |
| `manualRetryRequeuesEveryFailedJob` | Two failed jobs, retry → both requested. One succeeds → the reader answers it, then sees `.failed` for the other. |
| `newRoundResetsReplacementLimit` | After "Practice again", 3 more automatic replacements are available. |
| `jobCountInvariant` | `exercises + queue + failedJobs == 6` after every step of a mixed scenario. Needs a `#if DEBUG` or internal accessor, or an equivalent check through the call count. |
| `replacementTopics…` (static) | Untried topics first, at most 3, falls back to the failed topics in another order when there are no others. Seeded RNG. |

Snapshot tests are unaffected.

### 3.3 Hand checks

Failures can't be forced with the real model, so the unit tests cover failure paths. On the iPhone 18 Pro simulator, which has the on-device model:

1. Play a full round. It behaves as today: 6 exercises, the dots advance, Results and Review are correct.
2. Tap Start straight away on Welcome. Loading shows the topic being written, and exercises arrive as before.
3. Open Settings mid-round and change topics. The new round starts cleanly (no stale exercise or topic).

---

## 4. Docs

- `README.md` "Little waiting for questions" (line 27): add that a text that can't be written is replaced automatically, up to 3 times per round.
- Class doc comment of `QuizViewModel`.

## 5. Delivery

One PR from `main`: "Keep generating after a failed exercise and replace it". It contains the view model, the `RootView` line, the tests and the README line. The diff is small, so it doesn't need stacking.

## 6. Later: parallel generation

Not part of this work (D6). This design keeps it a contained change:

- Replace the single loop with a runner that takes up to `maxConcurrentJobs` jobs from `queue`, generating job 1 alone first so time-to-first-exercise doesn't get worse. "Ready in finish order" already matches what concurrency produces.
- Track jobs in flight separately from `queue`, and keep `writingTopicName` for the oldest job in flight.
- The stub would need results matched by topic or skill instead of call order.
- Before building it, measure a full round on device at 1, 2 and 3 concurrent jobs, and how often a reader actually waits on Loading after exercise 1.
