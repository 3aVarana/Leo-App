@testable import Leo
import Testing

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
        (AgeGroup.six, 30 ... 120),
        (.nine, 48 ... 180),
        (.twelve, 60 ... 225),
        (.fifteen, 72 ... 270),
        (.adult, 96 ... 345),
    ])
    func acceptedWordCount(_ group: AgeGroup, expected: ClosedRange<Int>) {
        #expect(group.acceptedWordCount == expected)
    }

    @Test(arguments: [
        (AgeGroup.nine, 100, Duration.seconds(90)),
        (.adult, 200, .seconds(90)),
        // 75 seconds, rounded up to 10.
        (.six, 50, .seconds(80)),
        (.six, 80, .seconds(120)),
        (.adult, 345, .seconds(160)),
        // Short passages get the minimum.
        (.adult, 40, .seconds(30)),
        (.nine, 0, .seconds(30)),
    ])
    func readingTime(_ group: AgeGroup, wordCount: Int, expected: Duration) {
        #expect(group.readingTime(wordCount: wordCount) == expected)
    }

    /// Older readers read faster, and get no more time for the same passage.
    @Test func readingPaceNeverDecreases() {
        for (younger, older) in zip(AgeGroup.allCases, AgeGroup.allCases.dropFirst()) {
            #expect(younger.readingWordsPerMinute < older.readingWordsPerMinute, "\(younger) → \(older)")
            #expect(younger.readingTime(wordCount: 150) >= older.readingTime(wordCount: 150), "\(younger) → \(older)")
        }
    }

    @Test func passageWordRangeNeverDecreases() {
        for (younger, older) in zip(AgeGroup.allCases, AgeGroup.allCases.dropFirst()) {
            #expect(younger.passageWordRange.lowerBound <= older.passageWordRange.lowerBound, "\(younger) → \(older)")
            #expect(younger.passageWordRange.upperBound <= older.passageWordRange.upperBound, "\(younger) → \(older)")
        }
    }

    @Test(arguments: [
        (AgeGroup.six, 10 ... 13),
        (.nine, 10 ... 13),
        (.twelve, 10 ... 13),
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

    @Test func shortNames() {
        #expect(AgeGroup.allCases.map(\.shortName) == ["6–8", "9–11", "12–14", "15–17", "18+"])
    }

    /// The figures in the summary are the ones the model is asked for.
    @Test(arguments: AgeGroup.allCases)
    func summaryMatchesPassageWordRange(_ group: AgeGroup) {
        let range = group.passageWordRange
        #expect(group.summary.hasSuffix(" · \(range.lowerBound)–\(range.upperBound) words"))
    }

    @Test func summaryExample() {
        #expect(AgeGroup.nine.summary == "Everyday words · 80–120 words")
    }
}
