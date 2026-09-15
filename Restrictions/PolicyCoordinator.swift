import Combine
import Foundation

enum CreationKind: String, Sendable {
    case story
    case note
}

@MainActor
final class PolicyCoordinator: ObservableObject {
    @Published private(set) var storyPostsRemaining = 0
    @Published private(set) var notePostsRemaining = 0

    let dailyLimit: DailyLimitController

    private let persistence: PolicyPersistence
    private var state: PersistedPolicyState
    private let storyLimiter = RollingWindowLimiter(rule: AppPolicy.storyPostingRule)
    private let noteLimiter = RollingWindowLimiter(rule: AppPolicy.notePostingRule)

    init(persistence: PolicyPersistence = PolicyPersistence(), now: Date = Date()) {
        self.persistence = persistence
        self.state = persistence.load()
        self.dailyLimit = DailyLimitController(persistence: persistence, now: now)
        refresh(at: now)
    }

    func refresh(at now: Date = Date()) {
        state = persistence.load()
        let storyEvents = storyLimiter.retainedEvents(
            state.rollingEvents[AppPolicy.storyPostingRule.identifier] ?? [],
            at: now
        )
        let noteEvents = noteLimiter.retainedEvents(
            state.rollingEvents[AppPolicy.notePostingRule.identifier] ?? [],
            at: now
        )
        state.rollingEvents[AppPolicy.storyPostingRule.identifier] = storyEvents
        state.rollingEvents[AppPolicy.notePostingRule.identifier] = noteEvents
        storyPostsRemaining = storyLimiter.remaining(events: storyEvents, at: now)
        notePostsRemaining = noteLimiter.remaining(events: noteEvents, at: now)
        _ = persistence.save(state)
        dailyLimit.refresh(at: now)
    }

    /// Records the final publish attempt. Returning false instructs JavaScript to
    /// cancel the action because its rolling quota is already exhausted.
    func recordFinalPublishAttempt(_ kind: CreationKind, at now: Date = Date()) -> Bool {
        state = persistence.load()
        let rule = kind == .story ? AppPolicy.storyPostingRule : AppPolicy.notePostingRule
        let limiter = kind == .story ? storyLimiter : noteLimiter
        let existing = state.rollingEvents[rule.identifier] ?? []
        guard let updated = limiter.recordingEvent(events: existing, at: now) else {
            refresh(at: now)
            return false
        }
        state.rollingEvents[rule.identifier] = updated
        guard persistence.save(state) else {
            // Persistence failure must not turn a hard quota into unlimited retries.
            refresh(at: now)
            return false
        }
        refresh(at: now)
        return true
    }
}
