import Foundation
import FoundationModels

/// The model's review of a topic the reader wants to add.
@Generable
nonisolated struct TopicReview {
    // Filled in declaration order, so the verdict comes before the phrase and the reason.
    @Guide(description: "Whether the topic is safe and suitable for reading texts for the given reader age")
    var isSuitable: Bool

    @Guide(description: "If suitable, the topic rewritten as a short, clear phrase of at most 6 words, in the same language the reader typed it in; otherwise empty")
    var topic: String

    @Guide(description: "If not suitable, one short friendly sentence for the reader explaining why; otherwise empty")
    var reason: String
}

/// Checks with the on-device model that a custom topic suits the reader, and tidies up its wording.
struct TopicValidator {
    enum Outcome: Equatable {
        /// The cleaned-up phrase to store and show.
        case accepted(String)
        /// Why the topic can't be added, for the reader.
        case rejected(String)
    }

    let language: ContentLanguage

    private static var genericRejection: String {
        String(localized: "That topic isn't a good fit for your reading practice. Try another one.")
    }

    func review(_ text: String, for group: AgeGroup) async throws -> Outcome {
        let instructions = """
            You review topics a reader wants to practice reading about. \
            Accept a topic only if it is appropriate reading material for \(group.promptAudience). \
            Write the topic phrase and the reason in \(language.name).
            """
        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(
                to: "Topic: \(text)",
                generating: TopicReview.self,
                options: GenerationOptions(temperature: 0.2)
            )
            let review = response.content
            let topic = review.topic.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard review.isSuitable, !topic.isEmpty else {
                let reason = review.reason.trimmingCharacters(in: .whitespacesAndNewlines)
                return .rejected(reason.isEmpty ? Self.genericRejection : reason)
            }
            return .accepted(topic)
        } catch LanguageModelSession.GenerationError.guardrailViolation,
                LanguageModelSession.GenerationError.refusal {
            return .rejected(Self.genericRejection)
        } catch {
            if #available(iOS 27, *), case LanguageModelError.guardrailViolation = error { return .rejected(Self.genericRejection) }
            if #available(iOS 27, *), case LanguageModelError.refusal = error { return .rejected(Self.genericRejection) }
            throw error
        }
    }
}
