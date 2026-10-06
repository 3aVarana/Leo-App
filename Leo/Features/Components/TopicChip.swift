import SwiftUI

/// A suggested topic the reader turns on or off. VoiceOver reads it as a switch.
struct TopicChip: View {
    let name: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(name)
        }
        .toggleStyle(ChipToggleStyle())
    }
}

/// A topic the reader added. Tapping it removes it; without `onRemove` it can't be removed.
struct CustomTopicChip: View {
    let name: String
    let onRemove: (() -> Void)?

    var body: some View {
        if let onRemove {
            Button(action: onRemove) {
                ChipLabel(isOn: true, trailingSymbol: "xmark") { Text(name) }
            }
            .buttonStyle(ChipButtonStyle())
            .accessibilityLabel(name)
            .accessibilityHint(Text("Removes this topic."))
        } else {
            ChipLabel(isOn: true, trailingSymbol: nil) { Text(name) }
        }
    }
}

private struct ChipToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ChipLabel(isOn: configuration.isOn, leadingSymbol: configuration.isOn ? "checkmark" : "plus") {
                configuration.label
            }
        }
        .buttonStyle(ChipButtonStyle())
    }
}

private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// On: accent fill. Off: a hairline border and quieter text.
private struct ChipLabel<Label: View>: View {
    let isOn: Bool
    var leadingSymbol: String?
    var trailingSymbol: String?
    @ViewBuilder let label: Label

    @ScaledMetric(relativeTo: .subheadline) private var symbolSize = 14

    var body: some View {
        HStack(spacing: 6) {
            if let leadingSymbol {
                symbol(leadingSymbol)
            }
            label
                .leoTextStyle(LeoTextStyle(size: 15, relativeTo: .subheadline))
                .multilineTextAlignment(.leading)
            if let trailingSymbol {
                symbol(trailingSymbol)
            }
        }
        .foregroundStyle(isOn ? Color.leoAccent800 : Color.leoNeutral700)
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background(isOn ? Color.leoAccent100 : .clear, in: .rect(cornerRadius: 2))
        .overlay {
            if !isOn {
                RoundedRectangle(cornerRadius: 2).strokeBorder(Color.leoDivider)
            }
        }
        .contentShape(.rect)
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: symbolSize, weight: .medium))
            .accessibilityHidden(true)
    }
}

#Preview {
    @Previewable @State var volcanoes = true
    @Previewable @State var pirates = false
    FlowLayout {
        TopicChip(name: "Volcanoes", isOn: $volcanoes)
        TopicChip(name: "Pirates and treasure", isOn: $pirates)
        CustomTopicChip(name: "Chess", onRemove: {})
        CustomTopicChip(name: "Origami", onRemove: nil)
    }
    .padding(24)
    .leoScreenBackground()
}
