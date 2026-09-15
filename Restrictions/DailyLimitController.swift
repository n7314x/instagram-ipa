import Combine
import Foundation

@MainActor
final class DailyLimitController: ObservableObject {
    @Published private(set) var isLocked = false
    @Published private(set) var usedSeconds: TimeInterval = 0
    @Published private(set) var nextUnlockDate = Date()

    private let persistence: PolicyPersistence
    private var state: PersistedPolicyState
    private var meter: DailyUsageMeter
    private var timerTask: Task<Void, Never>?
    private var isActive = false
    private let calendar: Calendar

    init(
        persistence: PolicyPersistence,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) {
        self.persistence = persistence
        self.calendar = calendar
        self.state = persistence.load()
        self.meter = DailyUsageMeter(record: state.dailyUsage)
        refresh(at: now)
    }

    func applicationBecameActive(at now: Date = Date()) {
        refresh(at: now)
        if !isLocked {
            isActive = true
            meter.begin(at: now, calendar: calendar)
            persist()
        }
        startTimer()
    }

    func applicationResignedActive(at now: Date = Date()) {
        if isActive {
            meter.end(at: now, calendar: calendar)
        }
        isActive = false
        timerTask?.cancel()
        timerTask = nil
        publishAndPersist(at: now)
    }

    func refresh(at now: Date = Date()) {
        meter.normalize(for: now, calendar: calendar)
        publishAndPersist(at: now)
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled, let self {
                let now = Date()
                let delay: TimeInterval
                if self.isLocked {
                    delay = min(60, max(0.25, self.nextUnlockDate.timeIntervalSince(now)))
                } else {
                    let remaining = max(0.25, AppPolicy.dailyUsageLimit - self.usedSeconds)
                    delay = min(AppPolicy.usageCheckpointInterval, remaining)
                }
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
                let wakeDate = Date()
                if self.isLocked {
                    self.refresh(at: wakeDate)
                    if !self.isLocked {
                        self.isActive = true
                        self.meter.begin(at: wakeDate, calendar: self.calendar)
                        self.persist()
                    }
                } else {
                    self.checkpoint(at: wakeDate)
                }
            }
        }
    }

    private func checkpoint(at now: Date = Date()) {
        guard isActive else { return }
        meter.checkpoint(at: now, calendar: calendar)
        publishAndPersist(at: now)
        if isLocked {
            meter.end(at: now, calendar: calendar)
            isActive = false
            persist()
        }
    }

    private func publishAndPersist(at now: Date) {
        state.dailyUsage = meter.record
        usedSeconds = meter.record.usedSeconds
        isLocked = meter.isLimited(limit: AppPolicy.dailyUsageLimit)
        nextUnlockDate = meter.nextUnlockDate(from: now, calendar: calendar)
        persist()
    }

    private func persist() {
        // Reload before writing so rolling-window events recorded by the bridge
        // are never overwritten by a usage checkpoint.
        state = persistence.load()
        state.dailyUsage = meter.record
        _ = persistence.save(state)
    }
}
