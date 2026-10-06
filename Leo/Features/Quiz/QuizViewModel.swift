import Foundation
import Observation

/// Drives a round of exercises. A round's exercises are generated one after another in the
/// background, starting before the student taps Start, so they are ready when needed.
@Observable
final class QuizViewModel {
    enum Phase: Equatable {
        case welcome
        case loading
        case answering
        case finished
        case failed(String)
    }

    /// The topics to try for one exercise, main topic first, and the skill its question targets.
    struct PlanItem: Equatable {
        var topics: [String]
        var skill: ComprehensionSkill
    }

    /// How an answer option is shown: `idle` before answering, then `correct` for the right
    /// answer, `incorrect` for a wrong pick and `dimmed` for the rest.
    enum OptionState {
        case idle, correct, incorrect, dimmed
    }

    nonisolated static let exerciseCount = 6

    private(set) var phase: Phase = .welcome
    private(set) var currentIndex = 0
    private(set) var currentExercise: Exercise?
    private(set) var selectedOption: Int?
    private(set) var correctCount = 0

    private var settings: RoundSettings?
    private var plan: [PlanItem] = []
    private let makeRepository: (RoundSettings) -> any ExerciseRepository
    private var repository: (any ExerciseRepository)?
    /// Generated exercises, in order. The next one to generate is at `exercises.count`.
    private var exercises: [Exercise] = []
    /// Set when generating the exercise at `exercises.count` failed.
    private var generationError: String?
    private var generation: Task<Void, Never>?
    private var isRoundStarted = false

    var isLastExercise: Bool {
        currentIndex == Self.exerciseCount - 1
    }

    /// Whether the picked answer is right. `nil` before answering.
    var isAnswerCorrect: Bool? {
        guard let selectedOption, let currentExercise else { return nil }
        return selectedOption == currentExercise.correctIndex
    }

    /// - Parameter makeRepository: Makes the repository for each round.
    init(makeRepository: @escaping (RoundSettings) -> any ExerciseRepository) {
        self.makeRepository = makeRepository
    }

    /// How the option at `index` of the current exercise is shown.
    func optionState(at index: Int) -> OptionState {
        guard let selectedOption, let currentExercise else { return .idle }
        if index == currentExercise.correctIndex {
            return .correct
        }
        if index == selectedOption {
            return .incorrect
        }
        return .dimmed
    }

    /// Starts generating a round ahead of time with these settings. Does nothing if a round
    /// with the same settings is already prepared.
    func configure(_ newSettings: RoundSettings) {
        guard plan.isEmpty || newSettings != settings else { return }
        settings = newSettings
        prepareRound()
    }

    func start() {
        guard settings != nil else { return }
        // A round is used once; "Practice again" generates a new one.
        if plan.isEmpty || isRoundStarted {
            prepareRound()
        }
        isRoundStarted = true
        currentIndex = 0
        correctCount = 0
        showCurrent()
    }

    func select(_ option: Int) {
        guard selectedOption == nil, let exercise = currentExercise else { return }
        selectedOption = option
        if option == exercise.correctIndex {
            correctCount += 1
        }
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
        guard let settings else { return }
        let index = exercises.count
        guard index < Self.exerciseCount else { return }
        plan[index] = PlanItem(topics: Array(settings.topics.shuffled().prefix(3)), skill: plan[index].skill)
        phase = .loading
        generateRemaining()
    }

    /// The topics and skill for each exercise of a round. Each exercise gets its own topic while
    /// there are enough, cycling through them otherwise without repeating a topic back to back,
    /// plus two other topics to fall back on if generation fails. Every skill is used at least once.
    static func makePlan(topics: [String], using rng: inout some RandomNumberGenerator) -> [PlanItem] {
        let shuffled = topics.shuffled(using: &rng)
        let count = shuffled.count
        var skills: [ComprehensionSkill] = []
        while skills.count < exerciseCount {
            skills += ComprehensionSkill.allCases.shuffled(using: &rng)
        }
        return skills.prefix(exerciseCount).enumerated().map { i, skill in
            let primary = (i + i / count) % count
            let spares = shuffled.indices.filter { $0 != primary }.shuffled(using: &rng).prefix(2).map { shuffled[$0] }
            return PlanItem(topics: [shuffled[primary]] + spares, skill: skill)
        }
    }

    private func prepareRound() {
        guard let settings else { return }
        var rng = SystemRandomNumberGenerator()
        plan = Self.makePlan(topics: settings.topics, using: &rng)
        // Made per round, so a change to the device language applies to the next round.
        repository = makeRepository(settings)
        exercises = []
        isRoundStarted = false
        generateRemaining()
    }

    /// Generates the remaining exercises one at a time, stopping at the first failure.
    private func generateRemaining() {
        generation?.cancel()
        generationError = nil
        guard let repository else { return }
        generation = Task {
            while exercises.count < Self.exerciseCount {
                let item = plan[exercises.count]
                do {
                    let exercise = try await repository.exercise(topics: item.topics, skill: item.skill)
                    // A newer round or a retry replaced this generation.
                    guard !Task.isCancelled else { return }
                    exercises.append(exercise)
                } catch {
                    guard !Task.isCancelled, !(error is CancellationError) else { return }
                    generationError = error.localizedDescription
                }
                if phase == .loading {
                    showCurrent()
                }
                if generationError != nil {
                    return
                }
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
