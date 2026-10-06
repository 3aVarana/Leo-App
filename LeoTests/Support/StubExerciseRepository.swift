@testable import Leo

/// A fake `ExerciseRepository` that records each call. Calls are answered from `results` in
/// order while there are any; after that, each call waits until the test resumes it, so tests
/// control when an exercise is ready.
@MainActor
final class StubExerciseRepository: ExerciseRepository {
    struct Call: Equatable {
        let topics: [String]
        let skill: ComprehensionSkill
    }

    private(set) var calls: [Call] = []
    /// Waiting calls that were cancelled, which then threw `CancellationError`.
    private(set) var cancelledCount = 0

    private var results: [Result<Exercise, any Error>]
    private var waiting: [(id: Int, continuation: CheckedContinuation<Exercise, any Error>)] = []
    private var nextID = 0
    /// Keeps waiting calls waiting when their task is cancelled, like a repository that
    /// doesn't check for cancellation, so a late result can be delivered.
    private let ignoresCancellation: Bool

    init(results: [Result<Exercise, any Error>] = [], ignoresCancellation: Bool = false) {
        self.results = results
        self.ignoresCancellation = ignoresCancellation
    }

    /// Answers every call of a round right away.
    static func ready(count: Int = QuizViewModel.exerciseCount) -> StubExerciseRepository {
        StubExerciseRepository(results: (0 ..< count).map { .success(.fixture(title: "Exercise \($0 + 1)")) })
    }

    var waitingCount: Int {
        waiting.count
    }

    func exercise(topics: [String], skill: ComprehensionSkill) async throws -> Exercise {
        calls.append(Call(topics: topics, skill: skill))
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
    func resume(with result: Result<Exercise, any Error>) {
        precondition(!waiting.isEmpty, "No call is waiting")
        waiting.removeFirst().continuation.resume(with: result)
    }

    func resume(returning exercise: Exercise) {
        resume(with: .success(exercise))
    }

    private func cancel(_ id: Int) {
        guard !ignoresCancellation, let index = waiting.firstIndex(where: { $0.id == id }) else { return }
        cancelledCount += 1
        waiting.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}

/// Stands in for `QuizViewModel`'s repository factory: records the settings of every round and
/// hands out a new stub for each.
@MainActor
final class ExerciseRepositoryFactorySpy {
    private(set) var settings: [RoundSettings] = []
    private(set) var stubs: [StubExerciseRepository] = []
    private let makeStub: @MainActor () -> StubExerciseRepository

    init(makeStub: @escaping @MainActor () -> StubExerciseRepository = { StubExerciseRepository() }) {
        self.makeStub = makeStub
    }

    var latest: StubExerciseRepository {
        stubs.last!
    }

    func make(_ settings: RoundSettings) -> any ExerciseRepository {
        self.settings.append(settings)
        let stub = makeStub()
        stubs.append(stub)
        return stub
    }
}
