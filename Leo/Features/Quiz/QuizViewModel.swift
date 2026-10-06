import Foundation
import Observation
import OSLog

/// Drives a round of exercises. A round's exercises are generated one after another in the
/// background, starting before the student taps Start, so they are ready when needed.
@Observable
final class QuizViewModel {
    enum Phase: Equatable {
        case welcome
        case loading
        case answering
        case finished
        case failed
    }

    /// The topics to try for one exercise, main topic first, and the skill its question targets.
    struct PlanItem: Equatable {
        var topics: [RoundTopic]
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
    /// The answers of the round started last, kept after it ends, and when the settings
    /// change, so Results and Review still show them.
    private(set) var answers: [RoundAnswer] = []
    /// The age group of the round started last.
    private(set) var roundAgeGroup: AgeGroup?
    /// The topic of the exercise being generated, updated when the generator falls back to a spare one.
    private(set) var writingTopicName: String?

    private var settings: RoundSettings?
    private var plan: [PlanItem] = []
    private let makeRepository: (RoundSettings) -> any ExerciseRepository
    private var repository: (any ExerciseRepository)?
    /// Generated exercises, in order. The next one to generate is at `exercises.count`.
    private var exercises: [Exercise] = []
    /// Whether generating the exercise at `exercises.count` failed.
    private var generationFailed = false
    private var generation: Task<Void, Never>?
    /// Counts generations, so a late report from a replaced one is ignored.
    private var generationNumber = 0
    private var isRoundStarted = false
    private let logger = Logger(subsystem: "Leo", category: "QuizViewModel")

    var correctCount: Int {
        answers.count(where: \.isCorrect)
    }

    var misses: [RoundAnswer] {
        answers.filter { !$0.isCorrect }
    }

    /// The main topic of each exercise of the prepared round, without repeats, in round order.
    var plannedTopicNames: [String] {
        var seen: Set<String> = []
        return plan.compactMap(\.topics.first?.name).filter { seen.insert($0).inserted }
    }

    /// The main topic of the exercise at `index`, as planned.
    func plannedTopicName(at index: Int) -> String? {
        plan.indices.contains(index) ? plan[index].topics.first?.name : nil
    }

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

    /// How the dot of the exercise at `index` is drawn. Dots of answered exercises are neutral;
    /// the current one shows the verdict only while its feedback is on screen.
    func dotState(at index: Int) -> DotState {
        switch phase {
        case .welcome: return .upcoming
        case .finished: return .done
        case .loading, .answering, .failed: break
        }
        if index < currentIndex {
            return .done
        }
        if index > currentIndex {
            return .upcoming
        }
        switch phase {
        case .failed: return .failed
        case .answering: return isAnswerCorrect.map { $0 ? .currentCorrect : .currentMissed } ?? .current
        case .welcome, .loading, .finished: return .current
        }
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
        answers = []
        roundAgeGroup = settings?.ageGroup
        showCurrent()
    }

    func select(_ option: Int) {
        guard selectedOption == nil, let exercise = currentExercise else { return }
        selectedOption = option
        answers.append(RoundAnswer(index: currentIndex, exercise: exercise, selectedOption: option))
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

    /// Generates the failed exercise again with the same topics. Generation is sampled, so a
    /// second try often works.
    func retry() {
        guard settings != nil, exercises.count < Self.exerciseCount else { return }
        phase = .loading
        generateRemaining()
    }

    /// Generates the failed exercise again with other topics, preferring ones it didn't just try.
    func retryWithDifferentTopics() {
        guard let settings else { return }
        let index = exercises.count
        guard index < Self.exerciseCount else { return }
        let failed = Set(plan[index].topics)
        let untried = settings.topics.filter { !failed.contains($0) }.shuffled()
        let tried = settings.topics.filter { failed.contains($0) }.shuffled()
        plan[index].topics = Array((untried + tried).prefix(3))
        retry()
    }

    /// The topics and skill for each exercise of a round. Each exercise gets its own topic while
    /// there are enough, cycling through them otherwise without repeating a topic back to back,
    /// plus two other topics to fall back on if generation fails. Every skill is used at least once.
    static func makePlan(topics: [RoundTopic], using rng: inout some RandomNumberGenerator) -> [PlanItem] {
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
        generationFailed = false
        generationNumber += 1
        let number = generationNumber
        guard let repository else { return }
        generation = Task {
            while exercises.count < Self.exerciseCount {
                let item = plan[exercises.count]
                writingTopicName = item.topics.first?.name
                do {
                    let exercise = try await repository.exercise(topics: item.topics, skill: item.skill) { topic in
                        // A newer round or a retry replaced this generation.
                        guard number == self.generationNumber else { return }
                        self.writingTopicName = topic.name
                    }
                    guard !Task.isCancelled else { return }
                    exercises.append(exercise)
                } catch {
                    guard !Task.isCancelled, !(error is CancellationError) else { return }
                    logger.error("Couldn't generate exercise \(self.exercises.count + 1): \(error)")
                    generationFailed = true
                }
                if phase == .loading {
                    showCurrent()
                }
                if generationFailed {
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
            phase = generationFailed ? .failed : .loading
        }
    }
}
