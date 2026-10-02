import SwiftUI

struct LoadingView: View {
    let index: Int
    let total: Int

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Writing text \(index + 1) of \(total)…")
                .font(.headline)
            Text("This can take a few seconds.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    LoadingView(index: 0, total: 6)
}
