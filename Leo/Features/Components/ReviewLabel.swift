import SwiftUI

/// The bordered "Review" chip on a missed row, in Results and the round page.
struct ReviewLabel: View {
    var body: some View {
        Text("Review")
            .leoTextStyle(LeoTextStyle(size: 14, weight: .semibold, relativeTo: .subheadline))
            .foregroundStyle(Color.leoMagenta700)
            .fixedSize()
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(Color.leoDivider) }
    }
}

#Preview {
    ReviewLabel()
        .padding(24)
        .leoScreenBackground()
}
