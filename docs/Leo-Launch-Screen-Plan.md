# Leo Launch Screen Plan: 3a "Quieter, native-speed"

## 1. Scope and sources

This plan adds a branded launch screen and a short SwiftUI intro that picks up from it. It closes the launch-screen half of follow-up 6 in `docs/Leo-Redesign-Plan.md` ("so the first frame matches the new ground color instead of flashing white or black"). The app icon half is out of scope.

| Source | Where |
|---|---|
| Design | Claude Design project "Leo Launch Screen Ideas", file `Leo Launch Screen.dc.html`. Local export: `~/Downloads/leo-launch-screen-ideas/project/` |
| Chosen option | **3a, Quieter, native-speed** (turn 3, a riff on 2b "Wordmark hand-off") |
| Landing screen in the mock | `Leo Welcome.dc.html`, the existing Welcome screen |
| Design system | Broadsheet (`_ds/broadsheet-…/styles.css`, `readme.md`) |
| Current app | `main` at `c9e6fef` |

### 1.1 Today

The target uses Xcode's generated launch screen with no keys (`INFOPLIST_KEY_UILaunchScreen_Generation = YES` in both build configurations of `Leo.xcodeproj/project.pbxproj`). iOS shows a blank system background, white or black, and then Welcome cuts in on a #f3f2f2 / #1c1b1a ground.

### 1.2 What 3a is

| Part | Mock |
|---|---|
| Static frame | "Leo" in Source Serif 4 Semibold, **48pt**, Ink color, centered on the Background ground. Light: #201e1d on #f3f2f2. Dark: #efeded on #1c1b1a. |
| Wordmark move | From the center of the screen into Welcome's header wordmark (20pt, top-left). Scale 2.4 → 1 and translate, **480 ms**, `cubic-bezier(.65, 0, .25, 1)`. |
| Page | Everything else on Welcome (gear, kicker, headline, dots, body, Start) rises **24pt** and fades in **as one block**: no stagger, starts **200 ms** after the move begins, **480 ms**, `cubic-bezier(.2, .7, .2, 1)`. |
| Swap | The real header wordmark appears and the moving one is removed in the same frame. |
| Total | About 0.7 s from the end of the hold to a resting Welcome. |

In the mock, the static frame holds for 700 ms. That stands in for the app's launch time and isn't part of the intro.

### 1.3 Decisions taken

| # | Question | Decision |
|---|---|---|
| L1 | Landing on Onboarding (first launch) or Unavailable, which have no header wordmark | **Fade the wordmark out in place** while the page rises as one block, with 3a's timings and curves. The full move only plays into Welcome. |
| L2 | When the move starts | **Short hold of 0.3 s** on the centered wordmark after the first frame, then the move. |
| L3 | Taps during the intro | **Blocked** until the intro ends (3.4). |
| L4 | Delivery | **Two stacked PRs**: the static launch screen, then the intro (section 5). |

---

## 2. Part 1: the static launch screen

### 2.1 Info.plist

Replace the generated launch screen with a `UILaunchScreen` dictionary in `Leo/Info.plist`:

| Key | Value |
|---|---|
| `UIColorName` | `Background` (the existing color set; `Colors/` doesn't provide a namespace, so the bare name resolves) |
| `UIImageName` | `LaunchWordmark` (new image set) |
| `UIImageRespectsSafeAreaInsets` | `NO`, so the image is centered on the whole screen, like the intro's first frame |

Remove both `INFOPLIST_KEY_UILaunchScreen_Generation` lines from each build configuration (4 lines in total) so the generated empty dictionary doesn't compete with the one in `Info.plist`.

The Background color set already has a dark appearance, so the ground follows Dark Mode with no extra work.

### 2.2 The wordmark image

A launch screen can't use custom fonts or text, so "Leo" ships as an image.

- **New image set** `Leo/Assets.xcassets/LaunchWordmark.imageset` with two single-scale PDFs: `LaunchWordmark.pdf` (any appearance, #201e1d) and `LaunchWordmark-dark.pdf` (dark appearance, #efeded). The asset catalog rasterizes them at build time for each scale.
- **Generated, not hand-exported.** A committed script, `scripts/render-launch-wordmark.swift`, draws "Leo" with Core Text from `Leo/Resources/Fonts/SourceSerif4-Semibold.otf` at 48pt and writes both PDFs. Rerun it if the font, size or Ink color changes.
- **Same box as SwiftUI's text.** The PDF's page is the line box SwiftUI gives a one-line `Text`: the advance width of "Leo" by the font's line height (ascent + descent + leading), with the baseline at the same place. Both are centered on the screen, so the glyphs land on the same pixels and the hand-off from the launch image to the intro's first frame is invisible.
- No tracking and no kerning changes: the header wordmark uses neither.

### 2.3 Caveats

- **Launch screens are cached by iOS.** After changing them, delete the app and restart the simulator or device before checking. This is the main hand-check gotcha.
- **No Dynamic Type.** The launch image is a fixed 48pt; the intro's first frame matches it, also at a fixed 48pt (section 3.2).
- On iPad and in landscape the image stays at 48pt, centered. The mock only shows iPhone portrait.

Part 1 alone fixes the white/black flash. It can ship before Part 2.

---

## 3. Part 2: the SwiftUI intro

### 3.1 Where it lives

| File | Change |
|---|---|
| `Leo/Features/Root/LaunchIntro.swift` (new) | The intro: its phase, timings, the centered wordmark overlay and the modifier that hides and raises the page |
| `Leo/Features/Root/RootView.swift` | Wraps its content in the intro on cold launch only |
| `Leo/Features/Quiz/WelcomeView.swift` | Publishes the header wordmark's bounds as the move's target, and hides it while the intro is running |
| `Leo/Features/Theme/Theme.swift` | `LeoTextStyle.launchWordmark`: Semibold, fixed 48pt (not scaled with Dynamic Type) |

No changes to ViewModels or repositories. Whether the intro has played is view state, not business logic.

### 3.2 How it works

Three layers in `RootView`, bottom to top:

1. **Ground.** `Color.leoBackground`, ignoring the safe area. Always there, so nothing flashes while the page above it is transparent.
2. **Page.** Today's `RootView` content (Welcome, Onboarding or Unavailable), with `opacity` and a vertical offset driven by the intro.
3. **Wordmark overlay.** `Text(verbatim: "Leo")` in `.launchWordmark`, Ink, centered on the whole window (ignoring the safe area), hidden from VoiceOver.

The first frame is the ground plus the centered overlay, with the page at opacity 0. This matches the launch image exactly.

**Timeline** (constants in a `LaunchIntro.Timing` enum so tests and tuning have one place):

| t (s) | What happens |
|---|---|
| 0 | First frame: identical to the launch screen |
| 0 → 0.30 | Hold (L2) |
| 0.30 → 0.78 | Wordmark move: `.timingCurve(0.65, 0, 0.25, 1, duration: 0.48)` |
| 0.50 → 0.98 | Page rises 24pt → 0 and fades 0 → 1: `.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.48)` |
| 0.98 | Swap: header wordmark shown, overlay removed, taps enabled |

The moving wordmark arrives at 0.78 s and waits there, under nothing, until the page has finished rising at 0.98 s, and only then is swapped for the header. (Swapping at 0.78 s, as the first draft had it, left the page about 1.5 pt short of its place, so the header jumped.)

Driven by a single `.task` that sets the phase after `Task.sleep`, so it is cancelled with the view. The animations hang off the phase with `.animation(_:value:)`, one curve for the page and one for the wordmark.

**The rise is a `visualEffect`, not `.offset`.** With a plain `.offset` on the page, the Welcome layout flickered between two heights during the rise. `visualEffect` only changes how the page is drawn, not its layout.

**Move target (Welcome).** `WelcomeView` attaches `anchorPreference(key: LaunchWordmarkTarget.self, value: .bounds)` to its header wordmark. `RootView` reads it with `overlayPreferenceValue` and computes:

- the overlay's end center: the header wordmark's center, minus the page's current rise offset, so the target is where the wordmark will be **at rest** rather than where it is mid-rise;
- the end scale: header wordmark height ÷ overlay height. That is 20 / 48 at the default text size, and follows Dynamic Type for larger sizes, so the swap is seamless at any text size.

`scaleEffect` and `position` on the overlay animate together on the move curve. Source Serif 4 here is a static (non-variable) font, so the scaled 48pt glyphs match the 20pt ones at the swap.

While the wordmark is moving, `WelcomeView` sets its header wordmark's opacity to 0, through an environment value `\.hidesLaunchWordmarkTarget` set by the intro (`LaunchIntro.hidesHeader(phase:exit:)`). It keeps its place in the layout so the anchor is valid. When the wordmark fades instead of moving, the header isn't hidden: it is part of the page and fades in with it.

**How the wordmark leaves (`LaunchIntro.Exit`).** It moves, unless one of these makes it fade out in place over the move's 480 ms, with the page rise unchanged:

- **No target (Onboarding, Unavailable): L1.** No anchor is published.
- **Reduce Motion** (3.4).
- **The header moved after it was measured.** A rotating iPad (checked on the iPad Pro 11-inch (M5) with a landscape-only build) finishes its layout about 0.4 s after launch, which is just after the move begins at 0.3 s. The header, measured on the launch frame, then sits 22pt higher than the wordmark's target. The header's frame is compared with its launch-frame measurement during the first 0.18 s of the move, when the page hasn't started to rise yet (it has a 0.2 s delay), so any difference is a layout change. If it changed, the wordmark fades where it is, having barely left the center, and the header fades in with the page. An iPhone that launches already rotated doesn't trigger this: its layout doesn't change, and the move plays.

**Welcome but no round yet.** Welcome shows "Drawn from your topics…" until the round is prepared, as it does today. The intro doesn't wait for topics; the sentence updates when they arrive, as today.

### 3.3 When it plays

- **Cold launch only.** A `@State private var hasPlayedIntro = false` in `RootView`. Coming back from the background, or the scene being re-created on iPad, doesn't replay it.
- **Not in tests.** The test host already shows `EmptyView` with `--leo-running-tests`, and snapshot tests render screens directly, so they don't see the intro.
- **Previews.** `RootView`'s preview plays it. A `#Preview("Launch frame")` shows the first frame for comparison against the launch image.

### 3.4 Accessibility

- **Reduce Motion:** no move and no rise. After the hold, the overlay fades out and the page fades in together, over 0.2 s. The header "Leo" is part of the page and fades in with it.
- **VoiceOver:** the overlay is `accessibilityHidden`. The page is focusable straight away; the first element read is still Welcome's "Leo" header (hidden visually for under a second, but present).
- **Taps are blocked during the intro (L3).** The page has `.allowsHitTesting(false)` until the swap at 0.98 s (0.5 s with Reduce Motion), so a tap on Start or the gear mid-rise does nothing. VoiceOver activation is blocked the same way; the window is under a second.

### 3.5 Not recommended

- **Keeping a 0.7 s hold as in the mock.** Rejected in L2; 0.3 s is the hold.
- **A storyboard launch screen** (`LaunchScreen.storyboard`) to render "Leo" as a label with the custom font. Storyboard launch screens can't load app fonts reliably either, and the plist approach is simpler and is what the mock's notes assume.
- **Animating `.font` size** instead of `scaleEffect`. Font size isn't smoothly animatable and would re-lay out the text every frame.

---

## 4. Tests

| Test | Kind |
|---|---|
| Launch frame light and dark: the intro's first frame on iPhone portrait | Snapshot (`LeoTests/Snapshots/LaunchIntroSnapshotTests.swift`), recorded and compared by eye against a screenshot of the real launch screen once |
| Rest frame light and dark: the intro's final frame equals today's Welcome snapshot | Snapshot (same reference as `WelcomeViewSnapshotTests`) |
| End scale and target: the computation from header bounds and rise offset, at default and an accessibility text size | Unit test on a small pure function in `LaunchIntro.swift` |
| Timeline: the page rises during the move and ends after it; the swap waits for the page | Unit test on `LaunchIntro.Timing` |
| Hit testing: the page isn't hit-testable before the swap and is after it | Unit test on the intro's phase → `allowsHitTesting` mapping |

### 4.1 Hand checks (iPhone 18 Pro simulator)

Delete the app and restart the simulator first (2.3). Then:

1. Light and Dark: no flash, the launch image and the first frame line up, the wordmark lands on the header with no jump at the swap.
2. First launch (reset preferences): wordmark fades out over Onboarding (L1).
3. Largest accessibility text size: the swap is still seamless. (Done 2026-10-07: iPhone and iPad portrait.)
4. Reduce Motion on: crossfade only. (Done 2026-10-07. Found the header "Leo" popping in after the crossfade; fixed so it fades in with the page.)
5. Taps on Start and the gear during the intro do nothing; they work right after the swap. (Done 2026-10-07 with a throwaway 8 s hold: both taps did nothing on the launch frame, and the gear opened Settings after the swap.)
6. Background and foreground: no replay.
7. Landscape and iPad: centered, no jump. (Done 2026-10-07: iPhone landscape, launched already rotated, plays the move. iPad rotating during the intro landed 22pt low and jumped at the swap; fixed with the fade fallback in 3.2, which now fades in place with no jump.)
8. Slow-motion animations (Simulator ▸ Debug ▸ Slow Animations) to inspect the swap frame.

---

## 5. Delivery

Two stacked PRs (L4), each with before/after screenshots or a screen recording:

| PR | Content | Ships alone? |
|---|---|---|
| 1. Static launch screen | `Info.plist`, the build-setting removal, `LaunchWordmark.imageset`, `scripts/render-launch-wordmark.swift` | Yes: removes the flash, then cuts to Welcome |
| 2. Launch intro | `LaunchIntro.swift`, `RootView`, `WelcomeView`, `Theme`, tests; marks follow-up 6's launch-screen half done in `docs/Leo-Redesign-Plan.md` | Needs PR 1 |
