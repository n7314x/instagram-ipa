import Foundation

/// Compile-time restrictions. None of these values are exposed through Settings.
enum AppPolicy {
    /// Add lowercase Instagram usernames here, without the leading `@`.
    static let allowedStoryUsernames: Set<String> = []

    static let dailyUsageLimit: TimeInterval = 30 * 60
    static let usageCheckpointInterval: TimeInterval = 15

    static let storyPostingRule = RollingWindowRule(
        identifier: "story-posts",
        window: 7 * 24 * 60 * 60,
        maximumEvents: 1
    )

    static let notePostingRule = RollingWindowRule(
        identifier: "note-posts",
        window: 7 * 24 * 60 * 60,
        maximumEvents: 2
    )
}
