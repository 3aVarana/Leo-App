# Leo Hand-Check Fixes Plan

## 1. Scope and sources

On 2026-10-07 the launch intro (#23, #24) was hand-checked for Reduce Motion, the largest accessibility text size, and iPad/landscape, by recording cold launches on the iOS 27 simulators and stepping through the frames. Default size, the largest accessibility size, iPhone landscape and iPad portrait all swap seamlessly. Three things need fixing:

| # | What | Where | Severity |
|---|---|---|---|
| F1 | At large text sizes the six progress dots are wider than the screen, so the whole page lays out wider than the screen and is clipped on the right: headline, kicker, topic sentence and the Settings gear | `ProgressDots`, seen on Welcome, Loading, Generation failed, Exercise | Bug, pre-existing since #18 |
| F2 | With Reduce Motion, the header "Leo" pops in about 0.2 s after the crossfade ends instead of fading in with the page | `LaunchIntroModifier` | Small polish |
| F3 | On iPad, when the window rotated during the intro, the moving wordmark landed about 18 pt below the header and jumped up at the swap | `LaunchIntroModifier` | Edge case (rotating within ~1 s of launch) |

Current app: `main` at `d5d759b`.

### 1.1 Decisions taken

| # | Question | Decision |
|---|---|---|
| D1 | Dots that don't fit across the screen | **Cap and shrink to fit.** They stop growing at the largest standard text size, as the code already intends, and all six shrink equally when the row is narrower than that. Always one row. |
| D2 | The header "Leo" under Reduce Motion | **Fade it in with the page.** It isn't hidden under Reduce Motion, so the page, header included, fades in while the centered "Leo" fades out. |
| D3 | The window resizing during the intro | **Diagnose first, then fade.** Confirm the cause with logging. Then, if the window size changes during the intro, drop the move and fade the wordmark out in place (the Onboarding behavior, L1 of the launch plan). |
| D4 | Delivery | **Two independent PRs** (not stacked): PR 1 the dots, PR 2 the two intro fixes. |

---

## 2. PR 1: the progress dots fit across the screen (F1)

### 2.1 Cause

`ProgressDots` caps its content with `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` ("Six dots must fit across a phone"), but the circles' diameters are `@ScaledMetric` properties of `ProgressDots` itself. A view's `@ScaledMetric` reads the environment the view is in, which is outside the cap, so only the numbers stop growing and the circles keep scaling all the way to AX5.

Capping alone isn't enough. At the largest standard size, Footnote scales 13 → 19 pt (×1.46):

| Dots | Diameter at xxxLarge | Row (6 dots + 5 × 8 pt) | Room on a 390 pt iPhone (390 − 2 × 24) | Room on the iPhone 18 Pro (402 − 48) |
|---|---|---|---|---|
| `.regular` (28) | 40.9 | 285 | 342 | 354 |
| `.large` (36, Welcome) | 52.6 | **356** | 342 | 354 |

So Welcome's large dots already overflow at xxxLarge, a standard (non-accessibility) setting, by up to 14 pt on 390 pt phones (computed, not observed). Narrow iPad windows (Slide Over, Stage Manager) have even less room.

### 2.2 Fix

All in `Leo/Features/Components/ProgressDots.swift`:

1. **Cap the diameter, not only the number.** Move one dot into its own small view (`Dot`), with the `@ScaledMetric` diameters as its properties, placed inside the `.dynamicTypeSize(...xxxLarge)` modifier. Its scaled metric then reads the capped environment, so the circle and its number stop growing together.
2. **Shrink to fit.** Replace the `HStack(spacing: 8)` with a small `Layout` (`DotRow`) that gives every dot the same square side:

   `side = min(ideal diameter, (proposed width − 8 × (count − 1)) / count)`

   With no proposed width (ideal size), `side` is the ideal diameter. The dot's ideal size is its capped diameter, and its circle, ring and fill fill whatever square it's offered. The row stays one line, keeps the 8 pt spacing, and the existing `alignment` (leading on Welcome, centered elsewhere) is unchanged.
3. **The number fits a shrunk dot.** Add `.minimumScaleFactor(0.5)` to the number so it can never overflow a small circle. At realistic widths it isn't needed: the narrowest case, Slide Over at about 320 pt, leaves (272 − 40) / 6 ≈ 38.7 pt per large dot around a 22 pt number.
4. Update the comment on the cap to say both the circles and the numbers stop there, and that the row shrinks below that when it must.

The math lives in a static function on `DotRow`, so it can be unit-tested without rendering.

Nothing else changes: VoiceOver still reads "Text 2 of 6", and the default-size look is identical, so every default-size snapshot must still pass unchanged.

### 2.3 Tests

| Test | Kind |
|---|---|
| `DotRow` side: the ideal diameter when there's room; all equal and exactly filling the width when there isn't; never above the ideal; the ideal size when no width is proposed | Unit (`LeoTests/Features/ProgressDotsTests.swift`, new) |
| Both dot sizes at AX5 in a 320 pt-wide frame: one row, inside the frame, numbers legible | Snapshot, new case in `ComponentsSnapshotTests` |
| Re-record the accessibility-size references that show dots, light and dark (10 images): Welcome `six-ax`, Loading `2-of-6-ax`, Generation failed `text-2-ax`, Exercise `unanswered-ax` and `reading-ax` | Snapshot. Check each by eye before committing: nothing clipped on the right, the gear visible on Welcome, the headline wrapping inside the margins |
| Every other snapshot unchanged | Snapshot (the existing suite) |

The current accessibility references were recorded with the clipping and accepted as correct, which is how the bug got through. The by-eye check of the re-recorded images is the main guard here.

### 2.4 Hand checks

1. iPhone 18 Pro at AX5 (`xcrun simctl ui booted content_size accessibility-extra-extra-extra-large`): Welcome fits the width, the gear shows and opens Settings, and Start, Loading, an Exercise and Generation failed (if it can be triggered) all fit.
2. iPhone 17e (the narrowest iOS 27 phone here) at xxxLarge and AX5: the same.
3. Default size: the dots look exactly as before.

---

## 3. PR 2: the intro fixes (F2, F3)

Both fixes are in `Leo/Features/Root/LaunchIntro.swift`.

### 3.1 One rule for hiding the header (F2)

Today the header wordmark is hidden whenever the intro is running (`.environment(\.isLaunchIntroRunning, phase.isRunning)`), but only the move needs that. Under Reduce Motion there is no move, so the header stays hidden through the crossfade and then pops in at `.done`.

Introduce the idea of *how* the wordmark leaves, as a small enum on `LaunchIntro`:

```swift
enum Exit { case move, fade }
```

- `.fade` when Reduce Motion is on, when there's no header target (Onboarding, Unavailable, as today), or after a resize (3.2).
- `.move` otherwise.

The header is hidden only while the intro is running **and** the exit is `.move`. With `.fade`, the header is part of the page and fades in with it, as D2 asks. The existing fade-in-place path (`opacity(isMoving && move == nil ? 0 : 1)`) and the Reduce Motion crossfade timing (0.2 s) are unchanged.

Keep the environment key's name (`isLaunchIntroRunning`) or rename it to `hidesLaunchWordmarkTarget`, which says what it does now. The rename is preferred, since its value is no longer "is the intro running".

### 3.2 A resize during the intro falls back to the fade (F3)

**Step 1: diagnose (no commit).** The likely cause is that `headerFrame` is kept from the `.launch` phase and never updated, so a header measured during or before a rotation is stale. The 18 pt error doesn't match any obvious inset, so confirm it first:

- Temporarily log each `LaunchWordmarkFrame` update (time, phase, frame), the overlay's screen size, and the computed `WordmarkMove`.
- Run the forced-landscape iPad build (3.4) and an iPhone landscape build, and compare.
- **Expected:** on iPad, the last `.launch` update was taken before the rotation settled, and the iPhone, which launches already rotated, gets a correct frame. If instead an iPad already in landscape also gets a wrong frame, the fix below isn't enough. Stop and report back before continuing.

**Step 2: fix.**

- Record the window size on the first frame (`onGeometryChange(for: CGSize.self)` on the overlay's geometry, which ignores the safe area).
- If the size changes while the intro is running, set the exit to `.fade` for the rest of the intro: the wordmark fades out in place over the move's 480 ms, and the header, no longer hidden, comes in with the page (3.1). Once it's set, it isn't switched back to `.move`.
- A change during the hold or mid-move is handled the same way. The rotation's own animation covers any small discontinuity in the header.

No re-aiming, as D3 decided: the wordmark can no longer land anywhere but on the header.

### 3.3 Tests

| Test | Kind |
|---|---|
| The exit: `.fade` with Reduce Motion, with no target, or after a resize; `.move` otherwise; a resize never switches back to `.move` | Unit, `LaunchIntroTests`, on a pure function `LaunchIntro.exit(reduceMotion:hasTarget:didResize:)` |
| The header is hidden only for `.move` while running: replaces `headerWordmarkStaysHiddenUntilTheIntroIsDone` | Unit, on a pure function `LaunchIntro.hidesHeader(phase:exit:)` |
| Reduce Motion mid-crossfade frame: header and page at the same opacity | Snapshot, new case in `LaunchIntroSnapshotTests` with `.playing`, `plays: false` and `\.accessibilityReduceMotion` set. If a frozen `.playing` frame renders at its end state rather than mid-fade, use `.done` with Reduce Motion instead and check that the header shows |
| Existing launch and rest frames | Snapshot, unchanged |

### 3.4 Hand checks

Record a cold launch and step through its frames, as in the original check:

```bash
xcrun simctl io <device> recordVideo --codec h264 --force launch.mp4
```

Extract frames from the recording with `AVAssetImageGenerator` (there's no ffmpeg on this Mac).

1. **Reduce Motion** (`xcrun simctl spawn <device> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true`, then a cold launch): the header "Leo" fades in with the page, with no pop at the end. Turn it back off afterwards.
2. **iPad landscape:** a throwaway build, not committed, with `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad=UIInterfaceOrientationLandscapeRight INFOPLIST_KEY_UIRequiresFullScreen=YES` passed to `xcodebuild`. On the iPad Pro 11-inch (M5), iOS 27, it launches in portrait and rotates during the intro. The wordmark now fades out in place, with no jump at the swap.
3. **iPhone landscape:** a throwaway build with `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone=UIInterfaceOrientationLandscapeRight`, which launches already rotated. The move still plays and lands exactly, so the fallback doesn't trigger without a resize.
4. **Default and AX5 portrait on iPhone and iPad:** the move is unchanged and the swap is seamless.
5. **Not yet checked in the original pass:** taps on Start and the gear during the intro do nothing, and they work right after the swap.

### 3.5 Docs

Update `docs/Leo-Launch-Screen-Plan.md`:

- 3.4 Accessibility: under Reduce Motion the header fades in with the page.
- 3.2: a resize during the intro falls back to the fade.
- Hand checks 3, 4 and 7 are done, with the results of this plan.

---

## 4. Delivery

| PR | Content | Depends on |
|---|---|---|
| 1. Fit the progress dots at large text sizes | `ProgressDots.swift`, `ProgressDotsTests.swift`, the new component snapshot, the 10 re-recorded accessibility references, this plan doc | Nothing |
| 2. Polish the launch intro under Reduce Motion and resizes | `LaunchIntro.swift`, `WelcomeView.swift` (only if the environment key is renamed), `LaunchIntroTests`, `LaunchIntroSnapshotTests`, launch plan doc updates | Nothing (independent of PR 1) |

Each PR includes before and after images: the AX5 Welcome screenshot for PR 1, and the Reduce Motion and iPad frame strips for PR 2.

---

## 5. Implementation notes (2026-10-07)

**PR 1** went as planned. Welcome's dots at AX5 now fit, the gear shows, and the headline wraps inside the margins. Re-recorded images were checked by eye. One result worth knowing: the regular dots scale to about 37 pt at xxxLarge (not the 40.9 computed above), so they fit a 320 pt frame without shrinking; only the large dots shrink there.

**PR 2, F2** went as planned.

**PR 2, F3 (D3) changed in how it is detected.** Diagnosis with logging on the iPad Pro 11-inch (M5) found:

- The window size never changes from SwiftUI's point of view: the overlay reports 1210 x 834 from the first layout, so a size change can't be the trigger.
- The header's natural position moves 22 pt (44.25 to 22.25) about 0.4 s after launch, when the rotation finishes. It is time-based, not tied to the phase: with the hold stretched to 1.2 s the same change shows up while still on the launch frame. It does not happen on an iPhone that launches already rotated.
- The first plan, comparing the header in a coordinate space inside the page, doesn't work: that frame still includes the rise, and the safe-area insets only settle at the end.

The fix compares the header's global frame with its launch-frame measurement during the first 0.18 s of the move. The page has a 0.2 s delay before it rises, so until then the frame includes exactly the 24 pt rise, and a difference can only be a layout change. If it changed, the wordmark fades in place (it has barely left the center) and the header fades in with the page, as D3 asked. The trigger is "the header moved", not "the window resized". A shift later than 0.18 s into the move would still not be caught; the observed shift arrived about 0.1 s in.

A wait-until-the-header-is-still approach was tried and dropped: no change is published on the launch frame before the shift, so there was nothing to wait on.
