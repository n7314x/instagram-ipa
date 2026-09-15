import Foundation

struct RollingWindowLimiter: Sendable {
    let rule: RollingWindowRule

    func retainedEvents(_ events: [Date], at now: Date) -> [Date] {
        let cutoff = now.addingTimeInterval(-rule.window)
        // Future timestamps are retained. This makes moving the device clock
        // backwards fail closed instead of silently restoring quota.
        return events.filter { $0 > cutoff }.sorted()
    }

    func remaining(events: [Date], at now: Date) -> Int {
        max(0, rule.maximumEvents - retainedEvents(events, at: now).count)
    }

    func canRecord(events: [Date], at now: Date) -> Bool {
        remaining(events: events, at: now) > 0
    }

    func recordingEvent(events: [Date], at now: Date) -> [Date]? {
        let retained = retainedEvents(events, at: now)
        guard retained.count < rule.maximumEvents else { return nil }
        return (retained + [now]).sorted()
    }
}
