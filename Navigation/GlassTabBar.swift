import SwiftUI

struct GlassTabBar: View {
    let selection: InstagramSection
    let onSelect: (InstagramSection) -> Void
    let onOpenSettings: () -> Void
    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(InstagramSection.allCases) { section in
                    tabButton(section)
                }
            }
            .padding(6)
            .glassEffect(.regular.interactive(), in: .capsule)
            .glassEffectID("navigationBar", in: glassNamespace)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: selection)
    }

    @ViewBuilder
    private func tabButton(_ section: InstagramSection) -> some View {
        Button {
            onSelect(section)
        } label: {
            ZStack {
                if selection == section {
                    Circle()
                        .fill(.clear)
                        .glassEffect(.regular.tint(.accentColor.opacity(0.24)).interactive(), in: .circle)
                        .glassEffectID("selection", in: glassNamespace)
                        .glassEffectTransition(.matchedGeometry)
                }

                Image(systemName: selection == section ? section.selectedSymbol : section.symbol)
                    .font(.system(size: 19, weight: selection == section ? .semibold : .regular))
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selection == section ? Color.primary : Color.secondary)
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(selection == section ? .isSelected : [])
        .contextMenu {
            if section == .profile {
                Button("Settings", systemImage: "gearshape") {
                    onOpenSettings()
                }
            }
        }
        .accessibilityAction(named: "Open Settings") {
            if section == .profile { onOpenSettings() }
        }
    }
}
