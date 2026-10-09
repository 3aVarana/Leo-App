import Foundation
import Observation
import OSLog

/// Drives a round of exercises. A round's exercises are generated one after another in the
/// background, starting before the student taps Start, so they are ready when needed. An exercise
/// that can't be generated is replaced by one with the same skill and other topics, up to
/// `maxReplacements` times per round, and the reader gets exercises in the order they're ready.
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
    /// How many failed exercises a round replaces automatically.
    nonisolated static let maxReplacements = 3

    private(set) var phase: Phase = .welcome
    private(set) var currentIndex = 0
    private(set) var currentExercise: Exercise?
    private(set) var selectedOption: Int?
    /// Whether the reader is still on the passage of the current exercise. Its question shows,
    /// and can be answered, once they finish reading.
    private(set) var isReading = false
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
    /// Exercises still to generate, in order. The first one is being generated.
    private var queue: [PlanItem] = []
    /// Generated exercises, in the order they were ready. The reader's is at `currentIndex`.
    private var exercises: [Exercise] = []
    /// Exercises that failed once the round's replacements ran out, kept for a manual retry.
    /// `exercises`, `queue` and `failedJobs` always add up to `exerciseCount`.
    private var failedJobs: [PlanItem] = []
    /// How many more failed exercises this round replaces automatically.
    private var replacementsLeft = maxReplacements
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

    /// The main topic of the first exercise that couldn't be generated, for the failure screen.
    var failedTopicName: String? {
        failedJobs.first?.topics.first?.name
    }

    /// Whether generation stopped short of a full round, so only a manual retry can go on.
    private var isStuck: Bool {
        queue.isEmpty && !failedJobs.isEmpty
    }

    #if DEBUG
        /// Generated, pending and failed exercises together, which is always `exerciseCount`.
        var jobCount: Int {
            exercises.count + queue.count + failedJobs.count
        }
    #endif

    var isLastExercise: Bool {
        currentIndex == Self.exerciseCount - 1
    }

    /// How long the reader gets to read the current passage, for the reading timer.
    var readingTime: Duration? {
        guard let currentExercise, let roundAgeGroup else { return nil }
        return roundAgeGroup.readingTime(wordCount: currentExercise.passage.wordCount)
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

    /// Hides the passage and shows the question, when the reader is done or their time is up.
    func finishReading() {
        guard phase == .answering else { return }
        isReading = false
    }

    func select(_ option: Int) {
        guard !isReading, selectedOption == nil, let exercise = currentExercise else { return }
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

    /// Generates the failed exercises again with the same topics. Generation is sampled, so a
    /// second try often works. Doesn't use or reset the round's automatic replacements.
    func retry() {
        guard settings != nil, isStuck else { return }
        requeueFailedJobs()
    }

    /// Generates the failed exercises again with other topics, preferring ones they didn't just
    /// try, and the same skills. Doesn't use or reset the round's automatic replacements.
    func retryWithDifferentTopics() {
        guard let settings, isStuck else { return }
        var rng = SystemRandomNumberGenerator()
        for index in failedJobs.indices {
            failedJobs[index].topics = Self.replacementTopics(
                for: failedJobs[index].topics,
                from: settings.topics,
                using: &rng,
            )
        }
        requeueFailedJobs()
    }

    /// Up to 3 topics for another try at a failed exercise, those it didn't just try first.
    static func replacementTopics(
        for failed: [RoundTopic],
        from topics: [RoundTopic],
        using rng: inout some RandomNumberGenerator,
    ) -> [RoundTopic] {
        let failed = Set(failed)
        let untried = topics.filter { !failed.contains($0) }.shuffled(using: &rng)
        let tried = topics.filter { failed.contains($0) }.shuffled(using: &rng)
        return Array((untried + tried).prefix(3))
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
        queue = plan
        exercises = []
        failedJobs = []
        replacementsLeft = Self.maxReplacements
        isRoundStarted = false
        generateRemaining()
    }

    private func requeueFailedJobs() {
        queue = failedJobs
        failedJobs = []
        phase = .loading
        generateRemaining()
    }

    /// Generates the queued exercises one at a time. A failure doesn't stop the others: it's
    /// replaced at the back of the queue while the round has replacements left.
    private func generateRemaining() {
        generation?.cancel()
        generationNumber += 1
        let number = generationNumber
        guard let repository else { return }
        generation = Task {
            while let item = queue.first {
                writingTopicName = item.topics.first?.name
                do {
                    let exercise = try await repository.exercise(topics: item.topics, skill: item.skill) { topic in
                        // A newer round or a retry replaced this generation.
                        guard number == self.generationNumber else { return }
                        self.writingTopicName = topic.name
                    }
                    guard !Task.isCancelled else { return }
                    queue.removeFirst()
                    exercises.append(exercise)
                } catch {
                    guard !Task.isCancelled, !(error is CancellationError) else { return }
                    queue.removeFirst()
                    handleFailure(of: item, error)
                }
                if phase == .loading {
                    showCurrent()
                }
            }
        }
    }

    /// Queues a replacement with the same skill and other topics while the round has some left,
    /// and otherwise keeps the exercise for a manual retry.
    private func handleFailure(of item: PlanItem, _ error: any Error) {
        let failure = "exercise (\(item.skill), \(item.topics.first?.name ?? "no topic"))"
        guard let settings, replacementsLeft > 0 else {
            failedJobs.append(item)
            logger.error("Couldn't generate an \(failure), no replacements left: \(error)")
            return
        }
        replacementsLeft -= 1
        let left = replacementsLeft
        var rng = SystemRandomNumberGenerator()
        let topics = Self.replacementTopics(for: item.topics, from: settings.topics, using: &rng)
        queue.append(PlanItem(topics: topics, skill: item.skill))
        logger.error("Couldn't generate an \(failure), replacing it, \(left) left: \(error)")
    }

    /// Shows the current exercise from its passage if it's ready, otherwise waits for the next one
    /// to be ready, or reports the failure once nothing is left to generate.
    private func showCurrent() {
        selectedOption = nil
        isReading = true
        if currentIndex < exercises.count {
            currentExercise = exercises[currentIndex]
            phase = .answering
        } else {
            currentExercise = nil
            phase = queue.isEmpty ? .failed : .loading
        }
    }
}
