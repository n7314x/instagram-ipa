import UIKit

@MainActor
enum HapticManager {
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    static func selectionChanged() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
}
