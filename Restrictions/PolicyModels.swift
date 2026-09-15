import Foundation

struct RollingWindowRule: Equatable, Sendable {
    let identifier: String
    let window: TimeInterval
    let maximumEvents: Int
}

struct PersistedPolicyState: Codable, Equatable, Sendable {
    var dailyUsage = DailyUsageRecord()
    var rollingEvents: [String: [Date]] = [:]
}

struct DailyUsageRecord: Codable, Equatable, Sendable {
    var dayStart: Date?
    var usedSeconds: TimeInterval = 0
}

struct DailyUsageMeter: Equatable, Sendable {
    private(set) var record: DailyUsageRecord
    private var activeSince: Date?

    init(record: DailyUsageRecord = DailyUsageRecord()) {
        self.record = record
    }

    mutating func begin(at now: Date, calendar: Calendar) {
        normalize(for: now, calendar: calendar)
        guard activeSince == nil else { return }
        activeSince = now
    }

    mutating func checkpoint(at now: Date, calendar: Calendar) {
        normalize(for: now, calendar: calendar)
        guard let activeSince else { return }

        // Backward clock changes never refund time. A new local day is handled by
        // normalize before this interval is applied.
        if now >= activeSince {
            record.usedSeconds += now.timeIntervalSince(activeSince)
        }
        self.activeSince = now
    }

    mutating func end(at now: Date, calendar: Calendar) {
        checkpoint(at: now, calendar: calendar)
        activeSince = nil
    }

    mutating func normalize(for now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        guard let storedDay = record.dayStart else {
            record.dayStart = today
            record.usedSeconds = 0
            return
        }

        // Reset only when local time has moved into a genuinely later day.
        // Moving the clock backwards cannot create a fresh allowance.
        if today > storedDay {
            record.dayStart = today
            record.usedSeconds = 0
            if activeSince != nil {
                activeSince = today
            }
        }
    }

    func isLimited(limit: TimeInterval) -> Bool {
        record.usedSeconds >= limit
    }

    func nextUnlockDate(from now: Date, calendar: Calendar) -> Date {
        let basis = max(record.dayStart ?? calendar.startOfDay(for: now), calendar.startOfDay(for: now))
        return calendar.date(byAdding: .day, value: 1, to: basis) ?? now.addingTimeInterval(24 * 60 * 60)
    }
}
