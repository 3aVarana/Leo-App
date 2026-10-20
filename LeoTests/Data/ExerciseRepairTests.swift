import Foundation
@testable import Leo
import Testing

/// The rules of docs/Leo-Exercise-Quality-Plan.md, section 2.4, without the model.
@MainActor
struct ExerciseRepairTests {
    private static let spanish = ContentLanguage(locale: Locale(identifier: "es_ES"))
    private static let portuguese = ContentLanguage(locale: Locale(identifier: "pt_BR"))
    private static let japanese = ContentLanguage(locale: Locale(identifier: "ja_JP"))

    // MARK: Markdown

    @Test(arguments: [
        ("A *space shuttle* is a vehicle.", "A space shuttle is a vehicle."),
        ("A **bold** move.", "A bold move."),
        ("An _emphasized_ word.", "An emphasized word."),
        ("# Volcanoes\nHot rock rises.", "Volcanoes\nHot rock rises."),
        ("## Title", "Title"),
        ("Type `ls` to list.", "Type ls to list."),
        ("* A list item", "A list item"),
    ])
    func removesMarkdown(_ text: String, expected: String) {
        #expect(ExerciseRepair.removingMarkdown(text) == expected)
    }

    @Test(arguments: ["Two times three is 2*3.", "A snake_case name.", "Rain fell #1 in the ranking."])
    func leavesSymbolsInsideWordsAlone(_ text: String) {
        #expect(ExerciseRepair.removingMarkdown(text) == text)
    }

    // MARK: Leading title

    @Test(arguments: [
        ("**Busy Little Bugs**\nInsects live all around us.", "Insects live all around us."),
        ("**Busy Little Bugs** In a sunny garden, a ladybug rests.", "In a sunny garden, a ladybug rests."),
        ("**The Missing Pencil**  Liam found a pencil.", "Liam found a pencil."),
        ("**Volcanoes**\nHot rock rises.", "Hot rock rises."),
        ("# Volcanoes\n\nHot rock rises.", "Hot rock rises."),
        ("Title: Mystery in the Locker\n\nA student found a note.", "A student found a note."),
        ("Título: El volcán\nEl suelo tembló.", "El suelo tembló."),
        ("Mystery in the Locker\n\nA student found a note.", "A student found a note."),
        ("Un día en la playa\nEl sol brilla fuerte sobre el mar.", "El sol brilla fuerte sobre el mar."),
    ])
    func removesLeadingTitle(_ passage: String, expected: String) {
        #expect(ExerciseRepair.removingLeadingTitle(passage) == expected)
    }

    @Test(arguments: [
        "**Volcanoes** are mountains that erupt.",
        "Insects live all around us. **Bees** make honey.",
        "**Stop!** Mia shouted.",
        "**Mount** Etna erupted in 2021.",
        "**Volcanoes** Hot rock rises.",
        "A plain passage.",
        "The bell rang.\n\nEveryone ran outside.",
        "Mia waited by the door, the rain still falling\nThen the bus came.",
    ])
    func keepsPassagesWithoutATitle(_ passage: String) {
        #expect(ExerciseRepair.removingLeadingTitle(passage) == passage)
    }

    // MARK: Line breaks

    @Test(arguments: [
        ("El sol brilla.\nLas olas son suaves.\nHay niños.", "El sol brilla. Las olas son suaves. Hay niños."),
        ("One line.  \n  Two line.", "One line. Two line."),
        ("First paragraph.\n\nSecond paragraph.", "First paragraph.\n\nSecond paragraph."),
        ("First.\n \n\n  Second.\nStill second.", "First.\n\nSecond. Still second."),
        ("No breaks at all.", "No breaks at all."),
    ])
    func joinsLinesButKeepsParagraphs(_ passage: String, expected: String) {
        #expect(ExerciseRepair.joiningLines(passage) == expected)
    }

    // MARK: Punctuation

    @Test func addsPeriodsWhenMostEndInOne() {
        #expect(ExerciseRepair.matchingPunctuation(["A cave.", "A tree.", "A field.", "A bridge"])
            == ["A cave.", "A tree.", "A field.", "A bridge."])
    }

    @Test func addsPeriodsWhenHalfEndInOne() {
        #expect(ExerciseRepair.matchingPunctuation(["A cave.", "A tree.", "A field", "A bridge"])
            == ["A cave.", "A tree.", "A field.", "A bridge."])
    }

    @Test func stripsPeriodsWhenFewEndInOne() {
        #expect(ExerciseRepair.matchingPunctuation(["A cave.", "A tree", "A field", "A bridge"])
            == ["A cave", "A tree", "A field", "A bridge"])
    }

    @Test func questionsAndExclamationsCountAsTerminal() {
        #expect(ExerciseRepair.matchingPunctuation(["Why?", "Run!", "Stop.", "Wait"])
            == ["Why?", "Run!", "Stop.", "Wait."])
    }

    @Test func stripKeepsEllipses() {
        #expect(ExerciseRepair.matchingPunctuation(["Wait...", "A tree.", "A field", "A bridge", "A cave"])
            == ["Wait...", "A tree", "A field", "A bridge", "A cave"])
        #expect(ExerciseRepair.matchingPunctuation(["待って。。。", "森", "海", "山"]) == ["待って。。。", "森", "海", "山"])
    }

    @Test func stripKeepsQuestionMarks() {
        #expect(ExerciseRepair.matchingPunctuation(["Why?", "A tree", "A field", "A bridge"])
            == ["Why?", "A tree", "A field", "A bridge"])
    }

    @Test func usesTheAnswersOwnFullStop() {
        #expect(ExerciseRepair.matchingPunctuation(["森へ行った。", "海へ行った。", "山へ行った。", "川へ行った"])
            == ["森へ行った。", "海へ行った。", "山へ行った。", "川へ行った。"])
    }

    // MARK: Explanation

    @Test(arguments: ["The mention of", "The passage says the fox ran (across the field"])
    func truncatedExplanationBecomesEmpty(_ explanation: String) {
        #expect(ExerciseRepair.completeExplanation(explanation) == "")
    }

    @Test(arguments: [
        "The passage says so.",
        "Is it not clear?",
        "It says \u{201C}the ground shakes.\u{201D}",
        "It calls this \u{201C}a warning\u{201D}",
        "El texto lo dice.",
        "文章にそう書いてある。",
        "",
    ])
    func completeExplanationIsKept(_ explanation: String) {
        #expect(ExerciseRepair.completeExplanation(explanation) == explanation)
    }

    // MARK: Self-reference

    @Test func rejectsEnglishSelfReference() {
        #expect(ExerciseRepair.refersToItself("Rivers run. The author wanted to show change.", language: .english))
        #expect(ExerciseRepair.refersToItself("In this passage, we learn about rivers.", language: .english))
        #expect(ExerciseRepair.refersToItself("THE MAIN IDEA is simple.", language: .english))
        #expect(ExerciseRepair.refersToItself("The writer’s purpose is to warn us.", language: .english))
        // Found by the harness after the review's narrower list let them through.
        #expect(ExerciseRepair.refersToItself("The writer shows how the robot helps.", language: .english))
        #expect(ExerciseRepair.refersToItself("The writer includes this to show their power.", language: .english))
    }

    @Test func rejectsSpanishAndPortugueseSelfReference() {
        #expect(ExerciseRepair.refersToItself("El autor quiso mostrar el cambio.", language: Self.spanish))
        #expect(ExerciseRepair.refersToItself("Este texto habla del agua.", language: Self.spanish))
        #expect(ExerciseRepair.refersToItself("A autora explica o ciclo.", language: Self.portuguese))
    }

    @Test(arguments: [
        "She lived on Author Street.",
        "The authors of the law met in Rome.",
        "They read the textbook together.",
        "A coauthor joined them.",
    ])
    func matchesWholeWordsOnly(_ passage: String) {
        #expect(!ExerciseRepair.refersToItself(passage, language: .english))
    }

    /// Words that are only self-reference with a verb about the passage, from the PR #31 review.
    @Test(arguments: [
        "She read the text on her phone.",
        "The passage of time made the old writer sad.",
        "This shows that bees need flowers.",
        "The writer sat at her desk and smiled.",
    ])
    func ordinaryUseIsNotSelfReference(_ passage: String) {
        #expect(!ExerciseRepair.refersToItself(passage, language: .english))
    }

    @Test func otherLanguagesHaveNoList() {
        #expect(!ExerciseRepair.refersToItself("The author wanted to show change.", language: Self.japanese))
        #expect(!ExerciseRepair.refersToItself("作者は変化を示したかった。", language: Self.japanese))
    }

    @Test func listIsPerLanguage() {
        #expect(!ExerciseRepair.refersToItself("The author wanted to show change.", language: Self.spanish))
    }

    // MARK: Standout correct answer

    private let fourWords = ["one two three four", "one two three", "one two"]

    @Test func longCorrectAnswerStandsOut() {
        #expect(ExerciseRepair.correctAnswerStandsOut(
            "one two three four five six seven eight nine", distractors: fourWords,
        ))
    }

    @Test func slightlyLongerCorrectAnswerIsAccepted() {
        #expect(!ExerciseRepair.correctAnswerStandsOut("one two three four five six", distractors: fourWords))
    }

    /// Twice as long by ratio, but only 2 words longer.
    @Test func shortAnswersAreNotRejectedByRatioAlone() {
        #expect(!ExerciseRepair.correctAnswerStandsOut("one two three four", distractors: ["one two", "three", "four"]))
    }
}
