import SwiftUI

/// An answer option: a marker (a letter, or "You" and "Answer" in Review), the text, and an
/// icon once the question is answered. Correct and incorrect never rely on color alone.
struct AnswerRow: View {
    let marker: String
    let text: String
    let state: QuizViewModel.OptionState
    /// A line under the text, such as "Your answer" on a wrong pick.
    var note: LocalizedStringKey?
    /// Letters are hidden from VoiceOver, which reads the text and the state instead.
    var readsMarker = false

    @ScaledMetric(relativeTo: .body) private var iconSize = 22

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(marker)
                .leoTextStyle(.answerMarker)
                .foregroundStyle(markerColor)
                .accessibilityHidden(!readsMarker)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .leoTextStyle(.answer)
                if let note {
                    Text(note)
                        .leoTextStyle(.note)
                        .foregroundStyle(Color.leoMagenta700)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Always laid out, so the text keeps the same width when the icon appears.
            Image(systemName: icon ?? "checkmark.circle.fill")
                .font(.system(size: iconSize))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .opacity(icon == nil ? 0 : 1)
                .accessibilityHidden(true)
        }
        .multilineTextAlignment(.leading)
        .foregroundStyle(textColor)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(fill, in: .rect(cornerRadius: 2))
        .opacity(state == .dimmed ? 0.7 : 1)
        .contentShape(.rect)
    }

    private var icon: String? {
        switch state {
        case .correct: "checkmark.circle.fill"
        case .incorrect: "xmark.circle.fill"
        case .idle, .dimmed: nil
        }
    }

    private var fill: Color {
        switch state {
        case .correct: .leoAccent100
        case .incorrect: .leoMagenta100
        case .idle, .dimmed: .leoSurface
        }
    }

    private var textColor: Color {
        switch state {
        case .correct: .leoAccent900
        case .incorrect: .leoMagenta900
        case .idle, .dimmed: .leoInk
        }
    }

    private var markerColor: Color {
        switch state {
        case .correct, .idle: .leoAccent700
        case .incorrect: .leoMagenta700
        case .dimmed: .leoInk
        }
    }

    private var iconColor: Color {
        state == .incorrect ? .leoMagenta600 : .leoAccent700
    }
}

#Preview {
    VStack(spacing: 8) {
        AnswerRow(marker: "A", text: "To measure how much snow falls", state: .idle)
        AnswerRow(marker: "B", text: "To feel small shakes that could warn of danger", state: .correct)
        AnswerRow(marker: "C", text: "To find the best path to the top", state: .incorrect, note: "Your answer")
        AnswerRow(marker: "D", text: "To keep the magma from moving", state: .dimmed)
    }
    .padding(24)
    .leoScreenBackground()
}
