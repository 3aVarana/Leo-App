import SwiftUI

/// Lays its subviews out in rows, left to right, wrapping to a new row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = rows(sizes: sizes(subviews, width: width), width: width)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let sizes = sizes(subviews, width: bounds.width)
        var y = bounds.minY
        for row in rows(sizes: sizes, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: size.width, height: size.height),
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// Each subview's ideal size, narrowed to `width` so a long chip wraps its text instead of overflowing.
    private func sizes(_ subviews: Subviews, width: CGFloat) -> [CGSize] {
        subviews.map { subview in
            let ideal = subview.sizeThatFits(.unspecified)
            guard ideal.width > width else { return ideal }
            return subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
        }
    }

    private func rows(sizes: [CGSize], width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (index, size) in sizes.enumerated() {
            let neededWidth = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if neededWidth > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row(indices: [index], width: size.width, height: size.height)
            } else {
                row.indices.append(index)
                row.width = neededWidth
                row.height = max(row.height, size.height)
            }
        }
        if !row.indices.isEmpty {
            rows.append(row)
        }
        return rows
    }
}
