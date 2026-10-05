import Foundation
import Testing

/// References are stored in `LeoTestsSnapshots/<TestFile>/`, so two test files with the same
/// name would share a folder and overwrite each other's images.
struct SnapshotLayoutTests {
    @Test
    func testFileNamesAreUnique() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let files = try #require(FileManager.default.enumerator(at: testsDirectory, includingPropertiesForKeys: nil))
        let names = files.compactMap { ($0 as? URL)?.lastPathComponent }.filter { $0.hasSuffix(".swift") }
        let duplicates = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        #expect(duplicates.isEmpty, "Duplicate test file names: \(duplicates)")
    }
}
