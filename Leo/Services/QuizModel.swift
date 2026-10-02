import Foundation
import Observation

/// Drives a round of exercises. A round's exercises are generated one after another in the
/// background, starting before the student taps Start, so they are ready when needed.
@Observable
final class QuizModel {
    enum Phase: Equatable {
        case welcome
        case loading
        case answering
        case finished
        case failed(String)
    }

    static let exerciseCount = 6

    private(set) var phase: Phase = .welcome
    private(set) var currentIndex = 0
    private(set) var currentExercise: Exercise?
    private(set) var selectedOption: Int?
    private(set) var correctCount = 0

    private var plan: [(topics: [String], skill: ComprehensionSkill)] = []
    private var generator = ExerciseGenerator(language: .english)
    /// Generated exercises, in order. The next one to generate is at `exercises.count`.
    private var exercises: [Exercise] = []
    /// Set when generating the exercise at `exercises.count` failed.
    private var generationError: String?
    private var generation: Task<Void, Never>?
    private var isRoundStarted = false

    var isLastExercise: Bool { currentIndex == Self.exerciseCount - 1 }

    /// Starts generating a round ahead of time. Does nothing if one is already prepared.
    func prepare() {
        guard plan.isEmpty else { return }
        prepareRound()
    }

    func start() {
        // A round is used once; "Practice again" generates a new one.
        if plan.isEmpty || isRoundStarted { prepareRound() }
        isRoundStarted = true
        currentIndex = 0
        correctCount = 0
        showCurrent()
    }

    func select(_ option: Int) {
        guard selectedOption == nil, let exercise = currentExercise else { return }
        selectedOption = option
        if option == exercise.correctIndex { correctCount += 1 }
    }

    func next() {
        guard selectedOption != nil else { return }
        if isLastExercise {
            phase = .finished
            return
        }
        currentIndex += 1
        showCurrent()
    }

    func retry() {
        let index = exercises.count
        guard index < Self.exerciseCount else { return }
        plan[index] = (topics: Array(Topics.all.shuffled().prefix(3)), skill: plan[index].skill)
        phase = .loading
        generateRemaining()
    }

    private func prepareRound() {
        let shuffled = Topics.all.shuffled()
        let primary = shuffled.prefix(Self.exerciseCount)
        let spares = shuffled.dropFirst(Self.exerciseCount)
        var skills: [ComprehensionSkill] = []
        while skills.count < Self.exerciseCount { skills += ComprehensionSkill.allCases.shuffled() }
        // Each exercise gets its own topic, plus spare topics to fall back on if generation fails.
        plan = zip(primary, skills).map { topic, skill in
            (topics: [topic] + spares.shuffled().prefix(2), skill: skill)
        }
        // Picked per round, so a change to the device language applies to the next round.
        generator = ExerciseGenerator(language: .current())
        exercises = []
        isRoundStarted = false
        generateRemaining()
    }

    /// Generates the remaining exercises one at a time, stopping at the first failure.
    private func generateRemaining() {
        generation?.cancel()
        generationError = nil
        let generator = generator
        generation = Task {
            while exercises.count < Self.exerciseCount {
                let item = plan[exercises.count]
                do {
                    let exercise = try await generator.generate(topics: item.topics, skill: item.skill)
                    // A newer round or a retry replaced this generation.
                    guard !Task.isCancelled else { return }
                    exercises.append(exercise)
                } catch {
                    guard !Task.isCancelled, !(error is CancellationError) else { return }
                    generationError = error.localizedDescription
                }
                if phase == .loading { showCurrent() }
                if generationError != nil { return }
            }
        }
    }

    /// Shows the current exercise if it's ready, otherwise waits for it or reports why it failed.
    private func showCurrent() {
        selectedOption = nil
        if currentIndex < exercises.count {
            currentExercise = exercises[currentIndex]
            phase = .answering
        } else {
            currentExercise = nil
            phase = generationError.map(Phase.failed) ?? .loading
        }
    }
}
