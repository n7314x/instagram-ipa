import Foundation
import XCTest
@testable import Instagram

final class DailyUsageTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testForegroundUsageIsAccumulated() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var meter = DailyUsageMeter()
        meter.begin(at: start, calendar: calendar)
        meter.checkpoint(at: start.addingTimeInterval(45), calendar: calendar)
        meter.end(at: start.addingTimeInterval(75), calendar: calendar)
        XCTAssertEqual(meter.record.usedSeconds, 75, accuracy: 0.001)
    }

    func testBackgroundTimeIsNotAccumulated() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var meter = DailyUsageMeter()
        meter.begin(at: start, calendar: calendar)
        meter.end(at: start.addingTimeInterval(20), calendar: calendar)
        meter.begin(at: start.addingTimeInterval(500), calendar: calendar)
        meter.end(at: start.addingTimeInterval(510), calendar: calendar)
        XCTAssertEqual(meter.record.usedSeconds, 30, accuracy: 0.001)
    }

    func testUsageResetsOnNextLocalDay() {
        let dayOne = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 23, minute: 59))!
        let dayTwo = calendar.date(byAdding: .minute, value: 2, to: dayOne)!
        var meter = DailyUsageMeter(record: DailyUsageRecord(
            dayStart: calendar.startOfDay(for: dayOne),
            usedSeconds: 1_799
        ))
        meter.normalize(for: dayTwo, calendar: calendar)
        XCTAssertEqual(meter.record.usedSeconds, 0)
        XCTAssertEqual(meter.record.dayStart, calendar.startOfDay(for: dayTwo))
    }

    func testBackwardClockDoesNotResetUsage() {
        let storedDay = calendar.date(from: DateComponents(year: 2026, month: 4, day: 2))!
        let earlier = calendar.date(byAdding: .day, value: -1, to: storedDay)!
        var meter = DailyUsageMeter(record: DailyUsageRecord(dayStart: storedDay, usedSeconds: 1_800))
        meter.normalize(for: earlier, calendar: calendar)
        XCTAssertTrue(meter.isLimited(limit: 1_800))
        XCTAssertEqual(meter.record.dayStart, storedDay)
    }

    func testLimitBoundaryIsInclusive() {
        let meter = DailyUsageMeter(record: DailyUsageRecord(dayStart: Date(), usedSeconds: 1_800))
        XCTAssertTrue(meter.isLimited(limit: 1_800))
    }

    func testActiveUsageContinuesAcrossMidnightOnFreshAllowance() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 23, minute: 59, second: 50))!
        let afterMidnight = start.addingTimeInterval(20)
        var meter = DailyUsageMeter()
        meter.begin(at: start, calendar: calendar)
        meter.checkpoint(at: afterMidnight, calendar: calendar)
        XCTAssertEqual(meter.record.dayStart, calendar.startOfDay(for: afterMidnight))
        XCTAssertEqual(meter.record.usedSeconds, 10, accuracy: 0.001)
    }
}
