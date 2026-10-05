import Foundation
@testable import Leo
import Testing

@MainActor
struct PreferencesStoreTests {
    private let testDefaults = TestDefaults()
    private let key = "readerPreferences"

    @Test func emptySuite() {
        #expect(PreferencesStore(defaults: testDefaults.defaults).preferences == nil)
    }

    @Test func savesAndReloads() {
        let preferences = ReaderPreferences.fixture(
            ageGroup: .twelve,
            disabled: [.twelve: ["mythology"]],
            custom: [.twelve: ["Chess"]],
        )
        PreferencesStore(defaults: testDefaults.defaults).preferences = preferences

        #expect(testDefaults.defaults.data(forKey: key) != nil)
        #expect(PreferencesStore(defaults: testDefaults.defaults).preferences == preferences)
    }

    @Test func settingNilRemovesKey() {
        let store = PreferencesStore(defaults: testDefaults.defaults)
        store.preferences = ReaderPreferences(ageGroup: .six)
        store.preferences = nil
        #expect(testDefaults.defaults.object(forKey: key) == nil)
    }

    @Test func corruptData() {
        testDefaults.defaults.set(Data("not json".utf8), forKey: key)
        #expect(PreferencesStore(defaults: testDefaults.defaults).preferences == nil)
    }

    @Test func loadsVersion1Data() {
        testDefaults.defaults.set(Data(#"{"ageGroup":"12-14"}"#.utf8), forKey: key)
        #expect(PreferencesStore(defaults: testDefaults.defaults).preferences == ReaderPreferences(ageGroup: .twelve))
    }

    @Test func equalValueIsNotRewritten() {
        let store = PreferencesStore(defaults: testDefaults.defaults)
        store.preferences = ReaderPreferences(ageGroup: .six)
        let other = Data(#"{"ageGroup":"18+"}"#.utf8)
        testDefaults.defaults.set(other, forKey: key)

        store.preferences = ReaderPreferences(ageGroup: .six)
        #expect(testDefaults.defaults.data(forKey: key) == other)
    }
}
