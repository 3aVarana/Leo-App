import SwiftUI

/// A small uppercase label above a headline or a section.
struct Kicker: View {
    let text: Text
    var color: Color = .leoInkMuted

    init(_ key: LocalizedStringKey, color: Color = .leoInkMuted) {
        text = Text(key)
        self.color = color
    }

    init(verbatim string: String, color: Color = .leoInkMuted) {
        text = Text(string)
        self.color = color
    }

    var body: some View {
        text
            .leoTextStyle(.kicker)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Kicker(verbatim: "Welcome to Leo")
        Kicker(verbatim: "Now writing", color: .leoAccent700)
        Kicker(verbatim: "Text 2 didn't print", color: .leoMagenta700)
    }
    .padding(24)
    .leoScreenBackground()
}
