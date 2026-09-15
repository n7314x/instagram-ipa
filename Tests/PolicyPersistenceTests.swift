import Foundation
import XCTest
@testable import Instagram

final class PolicyPersistenceTests: XCTestCase {
    func testStateRoundTripsThroughJSON() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("state.json")
        let persistence = PolicyPersistence(fileURL: file)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000.125)
        let expected = PersistedPolicyState(
            dailyUsage: DailyUsageRecord(dayStart: timestamp, usedSeconds: 42.5),
            rollingEvents: ["story-posts": [timestamp]]
        )
        XCTAssertTrue(persistence.save(expected))
        XCTAssertEqual(persistence.load(), expected)
    }

    func testMissingAndMalformedFilesReturnCleanState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("state.json")
        let persistence = PolicyPersistence(fileURL: file)
        XCTAssertEqual(persistence.load(), PersistedPolicyState())
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: file)
        XCTAssertEqual(persistence.load(), PersistedPolicyState())
    }
}
