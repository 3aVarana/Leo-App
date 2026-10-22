# Leo Feedback Plan

## 1. Scope and sources

Leo has no way for a tester or a reader to report a problem or send feedback. This plan adds that in layers, without giving up the README's privacy promise: "no accounts, no analytics and no network code".

The most useful report for Leo is "this text is wrong", because every text is written by the on-device model. So besides a general "Send feedback", each text gets a "Report this text" that carries the whole exercise, in a form the evaluation harness in [`scripts/exercise-eval`](../scripts/exercise-eval/README.md) can reproduce.

There is no design mock for these screens. The plan reuses existing components (`Kicker`, `.leo(.ghost)` and `.leo(.secondary)` buttons, `leoBottomBar`), so every new screen matches the Broadsheet design. If you want a mock first, ask Claude Design for: Settings' Help section, the "Report this text" sheet and the parental gate.

Current app: `main` at `2b02ca0`, with the round history screens (`RoundView`, `ReviewView(backTitle:)`) merged.

### 1.1 Decisions taken

| # | Question | Decision |
|---|---|---|
| F1 | Who it's for | **Testers and readers.** It's in the App Store build. Until it ships, testers use TestFlight's own feedback (section 2). |
| F2 | Network | **"No network code" stays a hard rule.** A report leaves the device only when the reader sends it from their own mail app, after seeing everything it contains. Leo never sends anything itself. |
| F3 | Where reports go | **A dedicated email alias** (for example `leo-feedback@…`; the address is still to be chosen, see 1.3). No GitHub issues; triage is by hand (section 7). |
| F4 | Kids category | **Not decided yet.** The plan builds a parental gate whose rule is one switch, so both answers work (section 4.4). |

### 1.2 Extrapolated (not decided yet, can be changed before the PR that builds it)

- **No text field in the app.** The reader picks a reason in Leo. Anything they want to add, they type in the email itself, where a parent can see it before it's sent. Leo never stores or handles anything the reader wrote about the problem.
- **One reason per report**, from a fixed list (4.2). An "Other" reason covers the rest.
- **Where "Report this text" appears:** on an exercise once it's answered, on each Review page, and from a long press on a text's row on a saved round's page (`RoundView`). Not while the passage is being read, so it can't be tapped by accident before the question.
- **The gate covers 6–8 and 9–11** while F4 is open: the reader is under 13, and a link out of the app should be for a parent. 12 and older go straight to the email.
- **No on-device flag (yet).** The brainstorm suggested also marking a reported text as flagged on the device. It needs a `RoundHistorySchemaV2` migration and a design for showing it, for little benefit before we know how often readers report. Moved to section 11.
- **No logs attached (yet).** `OSLogStore` on iOS only reads the current launch, and the log lines need a privacy pass first. Moved to section 11.

### 1.3 Still needed from you

- **The email alias.** It goes in one place (`FeedbackAddress.email`, section 6), so PR 1 can start with a placeholder; it must be set before the first build that includes the feature goes to TestFlight.
- **F4**, before the App Store submission. Only the gate's switch (4.4) and the App Store metadata depend on it.

---

## 2. Layer 0: TestFlight, now (no code)

TestFlight already lets a tester send a screenshot with a comment, and asks for a comment after a crash. Both show up in App Store Connect → TestFlight → Feedback, with the device, iOS version and build.

To do, once:

1. In App Store Connect → TestFlight → Test Information, set the **Feedback Email** to the alias (F3), and fill **Beta App Description** and **What to Test**.
2. Send testers this note (also in What to Test):

   > **How to tell us about a problem.** Take a screenshot in Leo (side button + volume up), tap the preview, then tap **Share Beta Feedback** and say what's wrong. If a text, question or answer seems wrong, make sure the passage and the question are in the screenshot. If Leo crashes, TestFlight asks you for a comment: please say what you were doing.

This layer stays useful after the in-app feedback ships: it's the quickest way to report a layout problem, because it includes a screenshot.

---

## 3. How a report leaves the device

All reports use the same route, `FeedbackSender`, which tries three ways in order:

| | When | What happens |
|---|---|---|
| 1 | `MFMailComposeViewController.canSendMail()` (an account is set up in Apple's Mail) | The Mail compose sheet opens inside Leo, with the address, subject, body and, for a text report, the JSON file attached. The reader can edit it, add a note, send it or cancel. |
| 2 | Otherwise, a `mailto:` URL opens (`openURL` returns `true`) | Opens the reader's default mail app (Gmail, Outlook…) with the address, subject and body. No attachment: the report's JSON goes in the body, after the readable part (5.3). |
| 3 | Neither works | An alert: "No email app is set up. Copy the report and send it to \(address)." with **Copy report** (puts the whole body on the pasteboard) and **Cancel**. |

- Leo learns nothing about whether the email was sent. `MFMailComposeResult` is only used to dismiss the sheet; it isn't logged or stored.
- The `mailto:` body is percent-encoded with `URLComponents`. A text report is about 2–4 KB, which mail apps accept.
- `MFMailComposeViewController` comes from MessageUI, a system framework. It doesn't make Leo do any networking: Mail sends the email.

---

## 4. What the reader sees

### 4.1 Settings: Help section

At the end of `SettingsView`, after the topics:

- `Kicker("Help")`, header trait, 28pt above.
- A row button "Send feedback" (17 semibold, `leoInk`), with `envelope` on the left and `chevron.right` on the right, 44pt minimum. Below it, a caption (`.caption`, `leoInkMuted`): "Opens an email to the developer with Leo's version and your device. You'll see everything before it's sent."
- Tapping it goes through the gate (4.4) for 6–8 and 9–11, then section 3.

The address is `FeedbackAddress.email`, a `static let` in `Leo/Domain/FeedbackReport.swift` (section 6).

### 4.2 "Report this text"

A `.leo(.ghost)` button with `flag` and "Report this text" (15, `leoInkSoft`), left-aligned:

- **Exercise:** under the passage once the question is answered (it scrolls in after the feedback and the passage, so it never competes with "Next text").
- **Review:** at the end of each `ReviewPage`, under the passage.
- **Saved round:** a `.contextMenu` on each `RoundView` row with "Report this text", so texts that were answered right can be reported too. Rows that are buttons (missed texts) keep their tap.

Tapping it opens a sheet, `ReportTextSheet` (medium detent, `leoBackground`):

- Heading "What's wrong with this text?" (`.display(28)`, header trait), then the text's title in `leoInkSoft`.
- One button per reason, as a list of rows with a check mark on the selected one:

  | `TextReportReason` | Shown as |
  |---|---|
  | `wrongAnswer` | "The right answer is wrong" |
  | `confusing` | "The question or answers are confusing" |
  | `notSuitable` | "It's not right for this age" |
  | `wrongLanguage` | "It's in the wrong language, or mixes languages" |
  | `tooHard` | "Too hard" |
  | `tooEasy` | "Too easy" |
  | `other` | "Something else" |

- Bottom bar: "Continue" (`.leo(.primary)`, disabled until a reason is picked), then the gate (4.4) and section 3. Cancel in the toolbar.
- Reporting doesn't change the round: an exercise reported mid-round stays answered as it was, and "Next text" carries on.

### 4.3 VoiceOver and sizes

- The report button reads "Report this text", hint "Opens an email to the developer about this text". The context menu action is also exposed as an accessibility action on the row ("Report this text").
- The reason rows are buttons with the `.isSelected` trait when picked.
- At accessibility sizes, the Help row and the reason rows wrap; nothing truncates.

### 4.4 Parental gate

`ParentalGate`, a sheet shown before anything leaves the app when `FeedbackPolicy.needsParentalGate(for:)` is true.

- "Ask a grown-up" heading, then "To send an email, answer this question." and a multiplication written in words, in the interface language: "What is seven times eight?" (factors 6–9, random each time, so the answer is 36–81 and can't be memorized).
- A number field (`.keyboardType(.numberPad)`) and "Continue". A wrong answer shakes the field (the existing `ShakeEffect`) and picks a new question; no limit on tries.
- Numbers are spelled with `NumberFormatter`'s `.spellOut` style in the interface locale, so it works in Spanish and Portuguese without new strings per number.

`FeedbackPolicy` (Domain) holds the rule in one place:

```swift
nonisolated enum FeedbackPolicy {
    /// Set to `true` if Leo is listed in the App Store Kids category (guideline 1.3):
    /// then every age group goes through the gate.
    static let isKidsCategory = false

    static func needsParentalGate(for ageGroup: AgeGroup) -> Bool {
        isKidsCategory || ageGroup == .six || ageGroup == .nine
    }
}
```

The age group is the one in the current preferences, also for a saved round of another age group.

---

## 5. What a report contains

### 5.1 Domain

New `Leo/Domain/FeedbackReport.swift`, Foundation only:

```swift
nonisolated enum TextReportReason: String, CaseIterable, Codable, Sendable { … } // 4.2

nonisolated struct FeedbackDiagnostics: Equatable, Codable, Sendable {
    let appVersion: String       // CFBundleShortVersionString, "1.0"
    let build: String            // CFBundleVersion, "12"
    let osVersion: String        // "iOS 27.0"
    let deviceModel: String      // "iPhone18,1", from utsname; not the device's name
    let interfaceLanguage: String // Bundle.main.preferredLocalizations.first, "es"
    let contentLanguage: String  // ContentLanguage.current().locale.identifier(.icu), "es_ES"
    let ageGroup: AgeGroup       // current preferences
    let isReadingTimerOn: Bool
    let modelAvailability: String // "available" or the ModelUnavailableReason case
}

nonisolated enum FeedbackReport: Sendable {
    case general(FeedbackDiagnostics)
    case text(RoundAnswer, ageGroup: AgeGroup, reason: TextReportReason, FeedbackDiagnostics)
}
```

- `ageGroup` in `.text` is the age group the text was written for: the round's (`QuizViewModel.roundAgeGroup` or `RoundRecord.ageGroup`), which can differ from the current one in `FeedbackDiagnostics`.
- **Never included:** the reader's topic list, other rounds, history totals, the device's name, any identifier. A text report includes the one exercise's topic, which may be a topic the reader typed; the body shows it, so the parent sees it before sending.

`FeedbackDiagnostics` is built by `FeedbackDiagnosticsProvider` in `Leo/Data` (it reads `Bundle`, `ProcessInfo`, `utsname`, `ContentLanguage` and the `ModelAvailabilityProvider`), behind a protocol so tests pass fixed values.

### 5.2 `FeedbackComposer`

New `Leo/Features/Feedback/FeedbackComposer.swift`, pure functions, no UI:

- `subject(for:) -> String`: "Leo feedback · 1.0 (12)" or "Leo text report · Wrong answer · 1.0 (12)". The reason in the subject stays English so the inbox can be filtered; the rest of the email is in the interface language.
- `body(for:includingJSON:) -> String`: the readable part, then the JSON when there's no attachment (3, way 2 and 3).
- `attachment(for:) -> (data: Data, fileName: String)?`: `leo-text-report.json` for `.text`, `nil` for `.general`.
- `mailtoURL(for:) -> URL`

### 5.3 The email

General feedback:

```
Write your feedback here:



—
Leo 1.0 (12) · iOS 27.0 · iPhone18,1
Interface: es · Texts: es_ES · Readers 9 to 11 · Reading timer on
On-device model: available
```

Text report:

```
What's wrong: The right answer is wrong
Anything to add:



—
"Why bread rises" · Readers 9 to 11 · Inference · Topic: Baking (story)

<passage>

Question: <question>
A. <option>   B. <option> (picked)   C. <option> (right)   D. <option>
Explanation: <explanation>

—
Leo 1.0 (12) · iOS 27.0 · iPhone18,1
Interface: es · Texts: es_ES · Readers 9 to 11 · Reading timer on
On-device model: available
```

The attached JSON (`schemaVersion` lets the format change later):

```json
{
  "schemaVersion": 1,
  "reason": "wrongAnswer",
  "ageGroup": "9-11",
  "skill": "inference",
  "topic": { "prompt": "baking bread at home", "name": "Baking", "kind": "story" },
  "contentLanguage": "es_ES",
  "exercise": {
    "title": "…", "passage": "…", "question": "…",
    "options": ["…", "…", "…", "…"], "correctIndex": 2, "selectedOption": 1,
    "explanation": "…"
  },
  "harness": "build/exercise-eval/harness 9-11 inference 'baking bread at home' 5 es_ES",
  "diagnostics": { … }
}
```

- `ageGroup`, `skill` and `topic.kind` use the persisted raw values, which never change.
- `harness` is the command that reproduces the case in the evaluation harness, so triage can start from the report (section 7).
- `contentLanguage` is the language at report time. For an old saved round it may not be the language the text was written in (rounds don't store it); the passage itself shows which it was.

---

## 6. Code layout

| Where | What |
|---|---|
| `Leo/Domain/FeedbackReport.swift` | `TextReportReason`, `FeedbackDiagnostics`, `FeedbackReport`, `FeedbackAddress`, `FeedbackPolicy` |
| `Leo/Data/Feedback/FeedbackDiagnosticsProvider.swift` | Protocol + live implementation |
| `Leo/Features/Feedback/FeedbackComposer.swift` | Subject, body, JSON, `mailto:` (5.2) |
| `Leo/Features/Feedback/FeedbackViewModel.swift` | `@Observable`. Owns the flow: report → gate if needed → route (3). Takes a `MailCapability` protocol (`canSendMail`, `open(_ url:) async -> Bool`, `copy(_:)`) so tests don't need Mail |
| `Leo/Features/Feedback/MailComposeView.swift` | `UIViewControllerRepresentable` around `MFMailComposeViewController` |
| `Leo/Features/Feedback/ParentalGate.swift` | 4.4 |
| `Leo/Features/Feedback/ReportTextSheet.swift` | 4.2 |
| `Leo/Features/Feedback/FeedbackModifier.swift` | `.feedbackFlow(_ viewModel:)`: the sheets and the alert, attached once at the root, so Settings, Exercise, Review and RoundView only call `viewModel.start(_:)` |

- `RootViewModel` owns one `FeedbackViewModel` and passes it down like `history`. `MyApp` builds it with the live provider and `MailCapability`.
- Settings is a sheet, so it attaches its own `.feedbackFlow` (a sheet can't present from the root while it's up).
- `MessageUI` is imported only in `MailComposeView.swift` and the live `MailCapability`.

---

## 7. Triage (by hand)

1. Filter the alias by subject: "Leo text report · <reason>".
2. For a text report, save `leo-text-report.json` and run its `harness` command a few times to see whether the problem repeats.
3. A pattern across reports (for example, `wrongAnswer` at 6–8 on inference) becomes a task for the exercise quality work, with the harness before/after table its rule asks for.
4. Reply to the sender only from the alias. Don't keep reports longer than needed; delete them once handled.

---

## 8. Privacy, App Store and docs

- **`PrivacyInfo.xcprivacy`:** no change. Leo still collects nothing itself. Check that MessageUI and `utsname` don't need a required-reason entry (neither is on Apple's list today; confirm in PR 1).
- **App Privacy label (App Store Connect):** feedback that's optional, rare, not the app's main function and sent by the user knowing what's in it is the case Apple describes as "optional disclosure". Confirm against Apple's current wording at submission, and if in doubt, declare "Other User Content" and "Other Diagnostic Data", not linked to the user, not used for tracking.
- **Privacy policy (support URL):** add a paragraph: what a report contains (5.3), that it's sent only by the reader from their own mail app, where it goes, and that it's deleted once handled.
- **README:** the Privacy section gains one sentence ("If you choose to send feedback, Leo opens an email in your own mail app with what's described here; you see it before sending."), and the feature list gets a "Feedback" item.
- **Strings:** all new strings in `Localizable.xcstrings` for English, Spanish and Brazilian Portuguese, in the repo's compact form. The subject's reason stays English (5.2).

---

## 9. Tests

All in the `Leo` test plan, Swift Testing, hand-written fakes.

### 9.1 PR 1

- `Domain/FeedbackPolicyTests`: the gate per age group; every group when `isKidsCategory` (tested through a parameter, not the constant).
- `Features/FeedbackComposerTests`:
  - `generalBodyHasDiagnosticsAndNoTopics`
  - `subjectHasVersionAndBuild`
  - `mailtoURLIsEncodedAndHasAddressSubjectBody` (Spanish text with accents, `&` and line breaks)
  - `mailtoBodyIncludesJSONWhenNoAttachment`
- `Features/FeedbackViewModelTests` (stub `MailCapability`):
  - `canSendMailShowsComposer`
  - `noMailOpensMailto`, `mailtoFailsOffersCopy`, `copyPutsBodyOnPasteboard`
  - `youngReaderSeesGateFirst`, `wrongGateAnswerKeepsGate`, `rightGateAnswerContinues`
- `Data/FeedbackDiagnosticsProviderTests`: model availability mapping, versions from a test bundle.
- Snapshots: Settings with the Help section (9–11, light, dark, accessibility size); `ParentalGate` (English and Spanish, to check spelled-out numbers).

### 9.2 PR 2

- `Features/FeedbackComposerTests`:
  - `textReportJSONRoundTrips`, `textReportJSONUsesRawValues`
  - `harnessCommandQuotesTheTopic` (a topic with an apostrophe)
  - `textReportUsesTheRoundsAgeGroup` (current preferences differ)
- `Features/FeedbackViewModelTests`: `textReportNeedsAReason`, `reportingDoesNotChangeTheRound` (with `QuizViewModel`).
- Snapshots: `ReportTextSheet` (none picked, one picked, dark, accessibility size); `ExerciseView` answered, with the button; a `ReviewPage` with the button.

### 9.3 Hand checks (iPhone 18 Pro simulator, on-device model)

The simulator has no Mail account, so it exercises way 2 or 3; way 1 needs a real device with Mail set up.

1. Settings → Send feedback at 15–17: no gate; the fallback opens or offers Copy; the copied text has the diagnostics.
2. Same at 6–8: the gate first; a wrong answer shakes and changes the question; the right one continues.
3. Report a text mid-round: pick a reason, continue, come back; the round carries on at the same text.
4. Report from Review and from a saved round's row (long press, and the VoiceOver action).
5. Spanish interface: the gate's question, the reasons, the body.
6. On a device with Mail: the compose sheet has the address, subject, body and `leo-text-report.json`; cancelling returns to the same screen.
7. Run a report's `harness` command on the Mac.

---

## 10. Delivery

Stacked PRs, one at a time against `main`:

| PR | Contents | Visible change |
|---|---|---|
| 0 | This plan | None |
| — | TestFlight setup and tester note (section 2) | None in the app |
| 1. Send feedback | 5.1, 5.2 (general), 3, 4.1, 4.4, 6, the alias, strings, README, tests 9.1 | Settings' Help section and the parental gate |
| 2. Report this text | 4.2, 4.3, 5.3 (text report and JSON), tests 9.2, hand checks 9.3 | "Report this text" on exercises, Review and saved rounds |

Before the App Store submission: decide F4 (and set `FeedbackPolicy.isKidsCategory`), update the privacy policy and the App Privacy answers (section 8).

---

## 11. Later

- **Flag on the device:** remember which texts were reported, show it in History and Review, and maybe use it to steer topics. Needs `RoundHistorySchemaV2` (an optional `reportReason` on `StoredAnswer`, a lightweight migration).
- **Logs in a report:** Leo's own `os_log` lines from the current launch (`OSLogStore(scope: .currentProcessIdentifier)`), after checking they hold nothing personal.
- **A web form or sending reports from the app**, only if email doesn't scale. Sending from the app would break F2 and change the App Privacy label, so it would need its own decision.
