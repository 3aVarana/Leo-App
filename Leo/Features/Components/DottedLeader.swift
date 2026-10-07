import SwiftUI

/// The dotted line that joins a title to its status on the Results screen.
struct DottedLeader: View {
    var body: some View {
        Line()
            .stroke(Color.leoInk.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private nonisolated struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

#Preview {
    HStack(alignment: .lastTextBaseline, spacing: 8) {
        Text(verbatim: "The Sleeping Mountain")
        DottedLeader()
            .frame(minWidth: 20)
            .alignmentGuide(.lastTextBaseline) { $0[.bottom] + 4 }
        Text(verbatim: "Correct")
    }
    .padding(24)
    .leoScreenBackground()
}
