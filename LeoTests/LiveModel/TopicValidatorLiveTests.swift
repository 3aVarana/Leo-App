import Foundation
@testable import Leo
import Testing

/// Results vary between runs: a failure means "look at the prompts", not a broken build.
extension LiveModel {
    @MainActor
    @Suite(.timeLimit(.minutes(1)))
    struct TopicValidatorLiveTests {
        private let validator = TopicValidator(language: .english)

        @Test func acceptsDinosaursForYoungReaders() async throws {
            let outcome = try await validator.review("dinosaurs", for: .six)
            guard case let .accepted(topic) = outcome else {
                Issue.record("Expected accepted, got \(outcome)")
                return
            }
            #expect(!topic.isEmpty)
            #expect(topic.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) == topic)
        }

        @Test func acceptsSpaceExplorationForAdults() async throws {
            let outcome = try await validator.review("space exploration", for: .adult)
            guard case .accepted = outcome else {
                Issue.record("Expected accepted, got \(outcome)")
                return
            }
        }

        @Test func rejectsGoryHorrorForYoungReaders() async throws {
            let outcome = try await validator.review("gory horror movies", for: .six)
            guard case let .rejected(reason) = outcome else {
                Issue.record("Expected rejected, got \(outcome)")
                return
            }
            #expect(!reason.isEmpty)
        }
    }
}
