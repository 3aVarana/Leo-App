@testable import Leo

/// A fake `TopicReviewRepository` that records each call. Calls are answered from `results` in
/// order while there are any; after that, each call waits until the test resumes it, so tests
/// control when a review finishes.
@MainActor
final class StubTopicReviewRepository: TopicReviewRepository {
    struct Call: Equatable {
        let text: String
        let group: AgeGroup
    }

    private(set) var calls: [Call] = []
    /// Waiting calls that were cancelled, which then threw `CancellationError`.
    private(set) var cancelledCount = 0

    private var results: [Result<TopicReviewOutcome, any Error>]
    private var waiting: [(id: Int, continuation: CheckedContinuation<TopicReviewOutcome, any Error>)] = []
    private var nextID = 0
    /// Keeps waiting calls waiting when their task is cancelled, like a review that
    /// doesn't check for cancellation, so a late result can be delivered.
    private let ignoresCancellation: Bool

    init(results: [Result<TopicReviewOutcome, any Error>] = [], ignoresCancellation: Bool = false) {
        self.results = results
        self.ignoresCancellation = ignoresCancellation
    }

    var waitingCount: Int {
        waiting.count
    }

    func review(_ text: String, for group: AgeGroup) async throws -> TopicReviewOutcome {
        calls.append(Call(text: text, group: group))
        if !results.isEmpty {
            return try results.removeFirst().get()
        }

        let id = nextID
        nextID += 1
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiting.append((id, continuation))
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
    }

    /// Answers the oldest waiting call.
    func resume(with result: Result<TopicReviewOutcome, any Error>) {
        precondition(!waiting.isEmpty, "No call is waiting")
        waiting.removeFirst().continuation.resume(with: result)
    }

    func resume(returning outcome: TopicReviewOutcome) {
        resume(with: .success(outcome))
    }

    private func cancel(_ id: Int) {
        guard !ignoresCancellation, let index = waiting.firstIndex(where: { $0.id == id }) else { return }
        cancelledCount += 1
        waiting.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
