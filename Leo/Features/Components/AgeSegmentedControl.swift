import SwiftUI

/// The five age groups side by side. Falls back to a menu when the segments don't fit,
/// at accessibility text sizes.
struct AgeSegmentedControl: View {
    @Binding var selection: AgeGroup

    var body: some View {
        ViewThatFits(in: .horizontal) {
            segments
            menu
        }
    }

    private var segments: some View {
        HStack(spacing: 0) {
            ForEach(AgeGroup.allCases, id: \.self) { group in
                if group != AgeGroup.allCases.first {
                    Rectangle()
                        .fill(Color.leoDivider)
                        .frame(width: 1)
                }
                segment(group)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(.rect(cornerRadius: 2))
        .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(Color.leoDivider) }
    }

    private func segment(_ group: AgeGroup) -> some View {
        let isSelected = group == selection
        return Button {
            selection = group
        } label: {
            Text(group.shortName)
                .leoTextStyle(.caption)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? Color.leoBackground : Color.leoInk)
                .padding(.vertical, 9)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? Color.leoAccent : .clear)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var menu: some View {
        Menu {
            Picker(selection: $selection) {
                ForEach(AgeGroup.allCases, id: \.self) { group in
                    Text(group.displayName)
                }
            } label: {
                Text("Age group")
            }
        } label: {
            HStack {
                Text(selection.displayName)
                    .leoTextStyle(.body)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.leoInk)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(Color.leoDivider) }
        }
        .accessibilityLabel(Text("Age group"))
        .accessibilityValue(selection.displayName)
    }
}

#Preview {
    @Previewable @State var group = AgeGroup.nine
    AgeSegmentedControl(selection: $group)
        .padding(24)
        .leoScreenBackground()
}
