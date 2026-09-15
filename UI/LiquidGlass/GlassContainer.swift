import SwiftUI

struct DailyLimitLockView: View {
    let nextUnlockDate: Date

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "hourglass.circle.fill")
                .font(.system(size: 48, weight: .medium))
                .symbolRenderingMode(.hierarchical)

            Text("Daily limit reached")
                .font(.title2.bold())

            Text("Instagram is unavailable until your daily allowance resets.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("Available again")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(nextUnlockDate, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(maxWidth: 360)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(24)
        .accessibilityElement(children: .combine)
    }
}
