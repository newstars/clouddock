import SwiftUI

struct DockIconTile<Content: View>: View {
    let accent: Color
    let isActive: Bool
    @ViewBuilder var content: Content

    init(accent: Color = .blue, isActive: Bool = false, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.isActive = isActive
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .frame(width: 22, height: 22)
                .foregroundStyle(.primary)
        }
        .frame(width: DockLayoutCalculator.iconWidgetWidth, height: DockLayoutCalculator.compactWidgetHeight)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.regularMaterial)
                .overlay(alignment: .topLeading) {
                    LinearGradient(
                        colors: [
                            accent.opacity(isActive ? 0.7 : 0.4),
                            .white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(accent.opacity(isActive ? 0.34 : 0.16), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
