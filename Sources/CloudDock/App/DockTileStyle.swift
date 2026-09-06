import SwiftUI

enum DockTileMetrics {
    static let compactHeight: CGFloat = 38
    static let cornerRadius: CGFloat = 13
    static let horizontalPadding: CGFloat = 12
    static let iconSize: CGFloat = 15
    static let labelFont = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let popoverRadius: CGFloat = 13
}

struct DockTileModifier: ViewModifier {
    let width: CGFloat?
    let height: CGFloat
    let accent: Color
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.primary)
            .padding(.horizontal, DockTileMetrics.horizontalPadding)
            .frame(width: width)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: DockTileMetrics.cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DockTileMetrics.cornerRadius, style: .continuous)
                    .stroke(accent.opacity(isActive ? 0.3 : 0.14), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: DockTileMetrics.cornerRadius, style: .continuous))
    }
}

extension View {
    func dockTile(width: CGFloat? = nil, height: CGFloat = DockTileMetrics.compactHeight, accent: Color = .white, isActive: Bool = false) -> some View {
        modifier(DockTileModifier(width: width, height: height, accent: accent, isActive: isActive))
    }

    func dockPopoverPanel(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        modifier(DockPopoverPanelModifier(width: width, height: height))
    }
}

struct DockCompactLabel: View {
    let symbolName: String
    let text: String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: DockTileMetrics.iconSize, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 18, height: 18)

            Text(text)
                .font(DockTileMetrics.labelFont)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DockPopoverPanelModifier: ViewModifier {
    let width: CGFloat?
    let height: CGFloat?

    func body(content: Content) -> some View {
        content
            .padding(10)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DockTileMetrics.popoverRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DockTileMetrics.popoverRadius, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
    }
}
