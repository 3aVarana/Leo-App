#if DEBUG
    import Foundation

    /// Shared by the History and round page previews, which can't reach the test target's fixtures.
    extension RoundRecord {
        static func previewFixture(ageGroup: AgeGroup, results: [Bool]) -> RoundRecord {
            let topic = RoundTopic(prompt: "volcanoes", name: "Volcanoes")
            var answers: [RoundAnswer] = []
            for (index, isCorrect) in results.enumerated() {
                let exercise = Exercise(
                    topic: topic,
                    skill: .detail,
                    title: "Preview text \(index + 1)",
                    passage: "A short passage.",
                    question: "A question?",
                    options: ["A", "B", "C", "D"],
                    correctIndex: 0,
                    explanation: "An explanation.",
                )
                let selected = isCorrect ? 0 : 1
                answers.append(RoundAnswer(index: index, exercise: exercise, selectedOption: selected))
            }
            return RoundRecord(id: UUID(), finishedAt: Date(), ageGroup: ageGroup, answers: answers)
        }
    }
#endif
