import SwiftUI

struct WelcomeView: View {
    let ageGroup: AgeGroup
    /// This round's planned topics, in order. Empty until the round is prepared.
    let topicNames: [String]
    let onStart: () -> Void
    /// `nil` hides the Settings button.
    var onSettings: (() -> Void)?

    @ScaledMetric(relativeTo: .title3) private var gearSize = 24

    var body: some View {
        ScrollingScreen {
            HStack {
                Text(verbatim: "Leo")
                    .leoTextStyle(.wordmark)
                    .accessibilityAddTraits(.isHeader)
                    .launchWordmarkTarget()
                Spacer()
                if let onSettings {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: gearSize))
                            .symbolRenderingMode(.hierarchical)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Settings"))
                }
            }
            .padding(.top, 4)
            .frame(minHeight: 44)

            TopOffset(height: 120)

            Kicker("Today's round · readers \(ageGroup.displayName)", color: .leoAccent700)
            Text("\(Self.spelledOutCount) short texts, written for you.")
                .leoTextStyle(.display(48))
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 12)
            ProgressDots(
                states: Array(repeating: .upcoming, count: QuizViewModel.exerciseCount),
                currentIndex: nil,
                size: .large,
                alignment: .leading,
            )
            .padding(.top, 28)
            Text(topicSentence)
                .leoTextStyle(.bodyLarge)
                .foregroundStyle(Color.leoInkSoft)
                .padding(.top, 24)
            Spacer(minLength: 24)
        }
        .leoBottomBar {
            Button("Start", action: onStart)
                .buttonStyle(.leo(.primary))
        }
    }

    /// "Six", in the reader's language.
    private static var spelledOutCount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        let words = formatter.string(from: QuizViewModel.exerciseCount as NSNumber) ?? "\(QuizViewModel.exerciseCount)"
        return words.prefix(1).localizedUppercase + words.dropFirst()
    }

    /// Names up to three of this round's topics, and how many more there are.
    private var topicSentence: String {
        guard !topicNames.isEmpty else {
            return String(localized: "Drawn from your topics. One question after each.")
        }
        let shown = topicNames.prefix(3)
        let more = topicNames.count - shown.count
        guard more > 0 else {
            let list = ListFormatter.localizedString(byJoining: Array(shown))
            return String(localized: "Drawn from \(list). One question after each.")
        }
        let list = shown.joined(separator: String(localized: ", ", comment: "Separates topic names in a list"))
        return String(localized: "Drawn from \(list) and \(more) more of your topics. One question after each.")
    }
}

#Preview {
    WelcomeView(
        ageGroup: .nine,
        topicNames: ["Volcanoes", "The solar system", "Pirates and treasure", "Inventors", "Rainforests"],
        onStart: {},
        onSettings: {},
    )
}
