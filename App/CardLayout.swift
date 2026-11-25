import SwiftUI

/// Cards two to a row. A wide card, or one left without a partner, takes a whole row.
struct CardLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let heights = rows(subviews).map { height($0, subviews, width) }
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(0, heights.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(subviews) {
            let height = height(row, subviews, bounds.width)
            let width = cardWidth(row, bounds.width)
            for (column, index) in row.enumerated() {
                subviews[index].place(at: CGPoint(x: bounds.minX + CGFloat(column) * (width + spacing), y: y),
                                      proposal: ProposedViewSize(width: width, height: height))
            }
            y += height + spacing
        }
    }

    private func rows(_ subviews: Subviews) -> [[Int]] {
        CardRows.rows(subviews.map { $0[IsWideKey.self] })
    }

    private func cardWidth(_ row: [Int], _ width: CGFloat) -> CGFloat {
        row.count == 1 ? width : max(0, (width - spacing) / 2)
    }

    private func height(_ row: [Int], _ subviews: Subviews, _ width: CGFloat) -> CGFloat {
        row.map { subviews[$0].sizeThatFits(ProposedViewSize(width: cardWidth(row, width), height: nil)).height }.max() ?? 0
    }
}

enum CardRows {
    static func rows(_ isWide: [Bool]) -> [[Int]] {
        var rows: [[Int]] = []
        for index in isWide.indices {
            if !isWide[index], let last = rows.last, last.count == 1, !isWide[last[0]] {
                rows[rows.count - 1].append(index)
            } else {
                rows.append([index])
            }
        }
        return rows
    }

    /// Which cards end up taking a whole row.
    static func full(_ isWide: [Bool]) -> Set<Int> { Set(rows(isWide).filter { $0.count == 1 }.map { $0[0] }) }
}

private struct IsWideKey: LayoutValueKey { static let defaultValue = false }

extension View {
    func wideCard(_ isWide: Bool) -> some View { layoutValue(key: IsWideKey.self, value: isWide) }
}
