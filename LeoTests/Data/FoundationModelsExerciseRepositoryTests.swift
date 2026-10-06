@testable import Leo
import Testing

@MainActor
struct FoundationModelsExerciseRepositoryTests {
    /// The language is picked when the repository is made, once per round.
    @Test func usesRoundAgeGroupAndLanguage() {
        let repository = FoundationModelsExerciseRepository(ageGroup: .nine, language: .english)
        #expect(repository.generator.ageGroup == .nine)
        #expect(repository.generator.language.locale == ContentLanguage.english.locale)
    }
}
