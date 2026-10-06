import Foundation
@testable import Leo
import Testing

@MainActor
struct UserDefaultsPreferencesRepositoryTests {
    private let testDefaults = TestDefaults()

    private var repository: UserDefaultsPreferencesRepository {
        UserDefaultsPreferencesRepository(defaults: testDefaults.defaults)
    }

    @Test func emptySuiteLoadsNil() {
        #expect(repository.load() == nil)
    }

    @Test func savesAndLoads() {
        let preferences = ReaderPreferences.fixture(
            ageGroup: .twelve,
            disabled: [.twelve: ["mythology"]],
            custom: [.twelve: ["Chess"]],
        )
        repository.save(preferences)
        #expect(repository.load() == preferences)
    }

    @Test func corruptDataLoadsNil() {
        testDefaults.defaults.set(Data("not json".utf8), forKey: UserDefaultsPreferencesRepository.key)
        #expect(repository.load() == nil)
    }

    @Test func loadsVersion1Data() {
        testDefaults.defaults.set(Data(#"{"ageGroup":"12-14"}"#.utf8), forKey: UserDefaultsPreferencesRepository.key)
        #expect(repository.load() == ReaderPreferences(ageGroup: .twelve))
    }

    /// Existing installs keep their settings only while the key stays the same.
    @Test func usesReaderPreferencesKey() {
        repository.save(ReaderPreferences(ageGroup: .six))
        #expect(UserDefaultsPreferencesRepository.key == "readerPreferences")
        #expect(testDefaults.defaults.data(forKey: "readerPreferences") != nil)
    }
}
