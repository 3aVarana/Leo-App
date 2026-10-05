import Testing
@testable import Leo

@MainActor
struct AgeGroupTests {
    /// The raw values are dictionary keys in saved preferences.
    @Test func rawValuesAreStable() {
        #expect(AgeGroup.allCases.map(\.rawValue) == ["6-8", "9-11", "12-14", "15-17", "18+"])
    }

    @Test(arguments: AgeGroup.allCases)
    func acceptedWordCountContainsRequestedRange(_ group: AgeGroup) {
        #expect(group.acceptedWordCount.contains(group.passageWordRange.lowerBound))
        #expect(group.acceptedWordCount.contains(group.passageWordRange.upperBound))
    }

    @Test(arguments: [
        (AgeGroup.six, 30...120),
        (.nine, 48...180),
        (.twelve, 60...225),
        (.fifteen, 72...270),
        (.adult, 96...345),
    ])
    func acceptedWordCount(_ group: AgeGroup, expected: ClosedRange<Int>) {
        #expect(group.acceptedWordCount == expected)
    }

    @Test func passageWordRangeNeverDecreases() {
        for (younger, older) in zip(AgeGroup.allCases, AgeGroup.allCases.dropFirst()) {
            #expect(younger.passageWordRange.lowerBound <= older.passageWordRange.lowerBound, "\(younger) → \(older)")
            #expect(younger.passageWordRange.upperBound <= older.passageWordRange.upperBound, "\(younger) → \(older)")
        }
    }

    @Test(arguments: [
        (AgeGroup.six, 10...13),
        (.nine, 10...13),
        (.twelve, 10...13),
        (.fifteen, nil),
        (.adult, nil),
    ] as [(AgeGroup, ClosedRange<Int>?)])
    func passageSentenceRange(_ group: AgeGroup, expected: ClosedRange<Int>?) {
        #expect(group.passageSentenceRange == expected)
    }

    @Test(arguments: AgeGroup.allCases)
    func textsAreNotEmpty(_ group: AgeGroup) {
        #expect(!group.displayName.isEmpty)
        #expect(!group.promptAudience.isEmpty)
        #expect(!group.styleGuidance.isEmpty)
    }
}
