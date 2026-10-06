import SwiftUI

struct ResultView: View {
    let correct: Int
    let total: Int
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("\(correct) of \(total) correct")
                    .font(.largeTitle.bold())
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button(action: onRestart) {
                Text("Practice again")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    private var ratio: Double {
        Double(correct) / Double(total)
    }

    private var symbol: String {
        ratio >= 0.8 ? "star.fill" : ratio >= 0.5 ? "hand.thumbsup.fill" : "book.fill"
    }

    private var message: String {
        if ratio == 1 {
            return String(localized: "Perfect score! You understood every text.")
        }
        if ratio >= 0.8 {
            return String(localized: "Great reading! You're paying close attention.")
        }
        if ratio >= 0.5 {
            return String(localized: "Good work. Keep practicing to sharpen your understanding.")
        }
        return String(localized: "Keep going! Try reading each text slowly and look for key ideas.")
    }
}

#Preview {
    ResultView(correct: 5, total: 6, onRestart: {})
}
