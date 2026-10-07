import SwiftUI

/// A screen's content in the readable column, scrolling when it doesn't fit. Spacers inside
/// stretch to fill the screen, so they replace the mock's fixed top offsets.
struct ScrollingScreen<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .foregroundStyle(Color.leoInk)
                .leoReadableWidth()
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
        .leoScreenBackground()
    }
}

/// The space between the top of a screen and its headline: the mock's offset when there's
/// room, less on short screens.
struct TopOffset: View {
    let height: CGFloat

    var body: some View {
        Spacer(minLength: 24)
            .frame(maxHeight: height)
    }
}

extension View {
    /// The screen's main buttons, pinned above the home indicator.
    func leoBottomBar(@ViewBuilder _ buttons: () -> some View) -> some View {
        safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                buttons()
            }
            .leoReadableWidth()
            .padding(.top, 16)
            .background(Color.leoBackground)
        }
    }
}
