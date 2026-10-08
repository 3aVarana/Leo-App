@testable import Leo
import SwiftUI
import Testing

struct ProgressDotsTests {
    private func side(ideal: CGFloat = 36, count: Int = 6, width: CGFloat?) -> CGFloat {
        DotRow.side(ideal: ideal, count: count, spacing: 8, proposedWidth: width)
    }

    @Test func dotsKeepTheirIdealDiameterWhenThereIsRoom() {
        #expect(side(width: 354) == 36)
        // Exactly enough: six 36 pt dots and five 8 pt gaps.
        #expect(side(width: 256) == 36)
    }

    @Test func dotsShrinkEquallyToFillTheWidthWhenThereIsNot() {
        // The large dots at the largest standard size, on a 342 pt row.
        let ideal: CGFloat = 52.6
        let side = side(ideal: ideal, width: 342)
        #expect(side < ideal)
        #expect(abs(side * 6 + 8 * 5 - 342) < 0.001)
    }

    @Test func dotsNeverGrowAboveTheirIdealDiameter() {
        #expect(side(width: 10000) == 36)
        #expect(side(ideal: 28, width: 400) == 28)
    }

    @Test func noProposedWidthMeansTheIdealDiameter() {
        #expect(side(width: nil) == 36)
        #expect(side(width: .infinity) == 36)
    }

    @Test func aRowTooNarrowForTheGapsGetsNoNegativeSide() {
        #expect(side(width: 20) == 0)
    }

    @Test func anEmptyRowKeepsTheIdealDiameter() {
        #expect(side(count: 0, width: 300) == 36)
    }
}
