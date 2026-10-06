import Foundation
@testable import Leo
import Testing

@MainActor
struct TopicValidatorTests {
    /// Looked up rather than written in English, so the test keeps passing in other languages.
    private let genericRejection =
        String(localized: "That topic isn't a good fit for your reading practice. Try another one.")

    private func outcome(isSuitable: Bool, topic: String = "", reason: String = "") -> TopicReviewOutcome {
        TopicValidator.outcome(for: TopicReview(isSuitable: isSuitable, topic: topic, reason: reason))
    }

    @Test(arguments: [
        ("Dinos!", "Dinos"),
        ("  ¿Planetas?  ", "Planetas"),
        ("Space exploration", "Space exploration"),
        ("\n\"Rock music\".\n", "Rock music"),
    ])
    func accepted(_ topic: String, expected: String) {
        #expect(outcome(isSuitable: true, topic: topic) == .accepted(expected))
    }

    @Test(arguments: ["", "  ", "?!...", " ¡¿? "])
    func suitableWithoutTopic(_ topic: String) {
        #expect(outcome(isSuitable: true, topic: topic) == .rejected(genericRejection))
    }

    @Test func rejectedWithReason() {
        let outcome = outcome(
            isSuitable: false,
            topic: "Something",
            reason: "  That's not suitable for young readers.\n",
        )
        #expect(outcome == .rejected("That's not suitable for young readers."))
    }

    @Test(arguments: ["", "  \n"])
    func rejectedWithoutReason(_ reason: String) {
        #expect(outcome(isSuitable: false, reason: reason) == .rejected(genericRejection))
    }
}
