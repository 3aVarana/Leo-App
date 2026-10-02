import Foundation
import Observation

/// Drives a round of exercises. Each exercise is generated on demand, and the next one is
/// prefetched while the student reads the current one.
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

    private let generator = ExerciseGenerator()
    private var plan: [(topics: [String], skill: ComprehensionSkill)] = []
    private var tasks: [Int: Task<Exercise, Error>] = [:]

    var isLastExercise: Bool { currentIndex == Self.exerciseCount - 1 }

    func start() {
        tasks.values.forEach { $0.cancel() }
        tasks = [:]
        currentIndex = 0
        correctCount = 0
        selectedOption = nil
        currentExercise = nil

        let shuffled = Topics.all.shuffled()
        let primary = shuffled.prefix(Self.exerciseCount)
        let spares = shuffled.dropFirst(Self.exerciseCount)
        var skills: [ComprehensionSkill] = []
        while skills.count < Self.exerciseCount { skills += ComprehensionSkill.allCases.shuffled() }
        // Each exercise gets its own topic, plus spare topics to fall back on if generation fails.
        plan = zip(primary, skills).map { topic, skill in
            (topics: [topic] + spares.shuffled().prefix(2), skill: skill)
        }

        loadCurrent()
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
        selectedOption = nil
        currentExercise = nil
        loadCurrent()
    }

    func retry() {
        let skill = plan[currentIndex].skill
        plan[currentIndex] = (topics: Array(Topics.all.shuffled().prefix(3)), skill: skill)
        tasks[currentIndex] = nil
        loadCurrent()
    }

    private func loadCurrent() {
        let index = currentIndex
        let task = task(for: index)
        phase = .loading
        Task {
            do {
                let exercise = try await task.value
                guard index == currentIndex, tasks[index] == task else { return }
                currentExercise = exercise
                phase = .answering
                prefetch(index + 1)
            } catch is CancellationError {
                // A newer round replaced this one.
            } catch {
                guard index == currentIndex, tasks[index] == task else { return }
                tasks[index] = nil
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func prefetch(_ index: Int) {
        guard index < Self.exerciseCount else { return }
        _ = task(for: index)
    }

    private func task(for index: Int) -> Task<Exercise, Error> {
        if let existing = tasks[index] { return existing }
        let item = plan[index]
        let generator = generator
        let task = Task { try await generator.generate(topics: item.topics, skill: item.skill) }
        tasks[index] = task
        return task
    }
}
