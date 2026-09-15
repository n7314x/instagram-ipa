import Foundation
import XCTest
@testable import Instagram

final class RollingWindowLimiterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testStoryAllowsOneEventWithinSevenDays() {
        let limiter = RollingWindowLimiter(rule: AppPolicy.storyPostingRule)
        let recorded = limiter.recordingEvent(events: [], at: now)
        XCTAssertEqual(recorded, [now])
        XCTAssertFalse(limiter.canRecord(events: recorded ?? [], at: now.addingTimeInterval(1)))
    }

    func testStoryEventExpiresAtSevenDayBoundary() {
        let limiter = RollingWindowLimiter(rule: AppPolicy.storyPostingRule)
        let oldEvent = now.addingTimeInterval(-AppPolicy.storyPostingRule.window)
        XCTAssertTrue(limiter.canRecord(events: [oldEvent], at: now))
    }

    func testNoteAllowsExactlyTwoEvents() {
        let limiter = RollingWindowLimiter(rule: AppPolicy.notePostingRule)
        let first = limiter.recordingEvent(events: [], at: now)!
        let second = limiter.recordingEvent(events: first, at: now.addingTimeInterval(1))!
        XCTAssertEqual(second.count, 2)
        XCTAssertNil(limiter.recordingEvent(events: second, at: now.addingTimeInterval(2)))
    }

    func testFutureTimestampFailsClosedAfterClockRollback() {
        let limiter = RollingWindowLimiter(rule: AppPolicy.storyPostingRule)
        XCTAssertFalse(limiter.canRecord(events: [now.addingTimeInterval(3_600)], at: now))
    }
}
