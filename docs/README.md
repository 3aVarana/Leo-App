# Plans

The plans behind Leo's larger changes, oldest first. Each plan records what was decided when it was written. A **Status** line under its title says what shipped, and notes marked *Update 2026-10-29* say where the app has changed since. When a plan and the code disagree, the code wins. [CLAUDE.md](../CLAUDE.md) holds the rules that apply today.

| Plan | What it covers | Shipped in | Status |
|---|---|---|---|
| [V2 specification](Leo-V2-specifications.md) | Age groups, topics, onboarding, reader preferences | before #2 | Shipped. Screens, prompts and paths changed later |
| [Test Coverage](Leo-Test-Coverage-Plan.md) | Unit and snapshot tests, the live-model suite, CI requirements | #2, CI in #4 | Shipped. Sections 2, 4, 10 and 12 still apply; the test catalog names pre-MVVM types |
| [MVVM + Repository](Leo-MVVM-Repository-Plan.md) | Domain, Data and Features layers, ViewModels, repositories | #9–#13 | Shipped. The layer rules still apply; the file trees describe the app at #13 |
| [Broadsheet Redesign](Leo-Redesign-Plan.md) | Fonts, colors, components and every screen (2a light, 3a dark) | #14–#21 | Shipped. The exercise, retries, Settings and the round size changed later |
| [Launch Screen](Leo-Launch-Screen-Plan.md) | The static launch screen and the launch intro (3a) | #23, #24 | Shipped |
| [Hand-Check Fixes](Leo-Hand-Check-Fixes-Plan.md) | Progress dots at large text sizes, Reduce Motion and iPad fixes to the intro | #25, #26 | Shipped |
| [Resilient Generation](Leo-Resilient-Generation-Plan.md) | Keep generating after a failure, up to 3 automatic replacements | #27 | Shipped. Parallel generation deferred |
| [Exercise Quality](Leo-Exercise-Quality-Plan.md) | Prompts, schema, repair and validation rules, the evaluation harness | #29–#32, #34 | Shipped, except temperature by kind (#33, closed). Section 7 experiments postponed |
| [Exercise Quality samples](Leo-Exercise-Quality-Samples.md) | Raw model output behind the Exercise Quality plan | — | Reference only |
| [Round History](Leo-Round-History-Plan.md) | Saving finished rounds with SwiftData, the History screens | #39–#41, #45, #46 | Shipped |
| [Passage Length](Leo-Passage-Length-Plan.md) | Sentence counts for 15–17 and 18+ on the iPhone's model | #47 | Step 2 shipped. Step 1 and the Mac-model regression are open |

Changes without a plan here:

- **Reading step** (#22): the passage first, then the question, with a reading timer.
- **Texts per round** (#52): 3 to 9 texts, 6 by default, built with the `/feature` pipeline without a docs plan. Several plans above assume 6 and have notes about it.
- **Feedback plan:** added in #42 and reverted in #43, so it isn't in this folder.

## Still open

Collected from the plans as of 2026-10-29:

- **Passage Length:** step 1 (reject a short passage as soon as it's written), and the run-ons the new sentence counts cause on the Mac's older model (open question 4).
- **Exercise Quality:** the section 7 experiments, postponed by the user; factual errors in informative passages, which no rule checks.
- **Resilient Generation:** parallel generation, which needs a measurement on a device first.
- **Round History:** results per skill (H4); History's back button from Welcome doesn't read "Leo" (5.1); no snapshot test uses a round other than 6 texts.
- **Redesign:** suggestions 1, 2, 3, 5, 7 and 8 in section 11.
- **Test Coverage:** Spanish and Portuguese snapshots and `LocalizationTests` (section 11); `displayScale` 2 and Git LFS for `LeoTestsSnapshots/`, now about 61 MB (section 12).
- **Accessibility:** at the largest accessibility text size, Welcome's header wraps "Le / o" and the "Past rounds" button runs into the gear (seen in the current `WelcomeViewSnapshotTests` reference).
