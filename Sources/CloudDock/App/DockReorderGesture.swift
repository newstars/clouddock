import SwiftUI

struct DockItemFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

struct DockReorderGesture: ViewModifier {
    let id: String
    let space: String
    let move: (String, CGPoint) -> Void
    @State private var translation = CGSize.zero
    @GestureState private var dragging = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: DockItemFrames.self, value: [id: geometry.frame(in: .named(space))])
                }
            }
            .offset(dragging ? translation : .zero)
            .zIndex(dragging ? 100 : 0)
            .opacity(dragging ? 0.8 : 1)
            .simultaneousGesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named(space))
                    .updating($dragging) { _, active, _ in active = true }
                    .onChanged { translation = $0.translation }
                    .onEnded { value in
                        translation = .zero
                        move(id, value.location)
                    }
            )
    }
}

enum DockReordering {
    static let storageKey = "cloudDock.combinedIconOrder.v1"

    static func reordered(_ ids: [String], source: String, location: CGPoint, frames: [String: CGRect]) -> [String] {
        guard ids.contains(source),
              let target = ids.filter({ $0 != source }).min(by: {
                  distance(location, frames[$0]) < distance(location, frames[$1])
              }), let frame = frames[target] else { return ids }
        // Dropping outside the bar cancels instead of unexpectedly moving an item.
        let area = frames.values.reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -30, dy: -30)
        guard area.contains(location) else { return ids }
        var result = ids.filter { $0 != source }
        guard let targetIndex = result.firstIndex(of: target) else { return ids }
        result.insert(source, at: targetIndex + (location.x > frame.midX ? 1 : 0))
        return result
    }

    private static func distance(_ point: CGPoint, _ frame: CGRect?) -> CGFloat {
        guard let frame else { return .greatestFiniteMagnitude }
        let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return dx * dx + dy * dy
    }
}
