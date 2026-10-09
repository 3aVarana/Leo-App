@testable import Leo

/// A fake `ExerciseRepository` that records each call. Calls are answered from `results` in
/// order while there are any; after that, each call waits until the test resumes it, so tests
/// control when an exercise is ready.
@MainActor
final class StubExerciseRepository: ExerciseRepository {
    struct Call: Equatable {
        let topics: [RoundTopic]
        let skill: ComprehensionSkill
    }

    private(set) var calls: [Call] = []
    /// Waiting calls that were cancelled, which then threw `CancellationError`.
    private(set) var cancelledCount = 0

    private var results: [Result<Exercise, any Error>]
    private var waiting: [(id: Int, continuation: CheckedContinuation<Exercise, any Error>)] = []
    private var nextID = 0
    /// The `onAttempt` of every call, in order, so tests can report a fallback.
    private(set) var attemptHandlers: [(RoundTopic) -> Void] = []
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

    /// Answers calls by a pattern such as `"S F S S"`: `S` succeeds with an exercise titled
    /// "Call N", N being the call's position, and `F` fails. Later calls wait.
    static func scripted(_ pattern: String) -> StubExerciseRepository {
        let results: [Result<Exercise, any Error>] = pattern.split(separator: " ").enumerated().map { index, step in
            precondition(step == "S" || step == "F", "Unknown step \(step)")
            return step == "S"
                ? .success(.fixture(title: "Call \(index + 1)"))
                : .failure(ExerciseGenerationError.failed)
        }
        return StubExerciseRepository(results: results)
    }

    var waitingCount: Int {
        waiting.count
    }

    /// Reports the first topic as tried. Tests report a fallback through `attemptHandlers`.
    func exercise(
        topics: [RoundTopic],
        skill: ComprehensionSkill,
        onAttempt: @escaping (RoundTopic) -> Void,
    ) async throws -> Exercise {
        calls.append(Call(topics: topics, skill: skill))
        if let first = topics.first {
            onAttempt(first)
        }
        attemptHandlers.append(onAttempt)
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
