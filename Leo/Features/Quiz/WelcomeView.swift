import SwiftUI

struct WelcomeView: View {
    let ageGroup: AgeGroup
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "book.pages")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("Leo")
                    .font(.largeTitle.bold())
                Text("Six short texts for readers aged \(ageGroup.displayName), about the topics you chose.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button(action: onStart) {
                Text("Start")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}

#Preview {
    WelcomeView(ageGroup: .twelve, onStart: {})
}
