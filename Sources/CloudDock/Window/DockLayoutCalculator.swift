import AppKit

enum DockLayoutCalculator {
    static let height: CGFloat = 58
    static let screenEdgeInset: CGFloat = 14
    static let compactWidgetWidth: CGFloat = 136
    static let iconWidgetWidth: CGFloat = 44
    static let maxDockWidth: CGFloat = 1040
    static let compactWidgetHeight: CGFloat = DockTileMetrics.compactHeight
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 18
    static let itemSpacing: CGFloat = 8
    static let rowSpacing: CGFloat = 8
    static let dockControlCount: CGFloat = 1
    static let dockControlsWidth: CGFloat = iconWidgetWidth * dockControlCount + itemSpacing
    static let dockDragHandleWidth: CGFloat = 18

    static func size(widgetIDs: [DockWidgetID], isDockOpen: Bool, screen: NSScreen?) -> NSSize {
        guard isDockOpen else {
            return NSSize(width: iconWidgetWidth + horizontalPadding, height: height)
        }

        let visibleFrame = resolvedVisibleFrame(screen)
        let screenMaxWidth = min(max(visibleFrame.width - screenEdgeInset * 2, 520), maxDockWidth)
        let maxContentWidth = max(screenMaxWidth - horizontalPadding, compactWidgetWidth)
        let rows = packedRows(widgetIDs: widgetIDs, maxContentWidth: maxContentWidth)
        let contentWidth = rows.map(\.width).max() ?? compactWidgetWidth
        let contentHeight = rows.reduce(CGFloat(0)) { $0 + $1.height }
            + CGFloat(max(rows.count - 1, 0)) * rowSpacing

        let width = min(max(contentWidth + horizontalPadding, 160), screenMaxWidth)
        let height = max(contentHeight + verticalPadding, Self.height)
        return NSSize(width: width, height: height)
    }

    private static func packedRows(
        widgetIDs: [DockWidgetID],
        maxContentWidth: CGFloat
    ) -> [(width: CGFloat, height: CGFloat)] {
        let ids = widgetIDs.isEmpty ? [.clock] : widgetIDs
        var rows: [(width: CGFloat, height: CGFloat)] = []
        var rowWidth: CGFloat = dockDragHandleWidth + dockControlsWidth
        var rowHeight: CGFloat = compactWidgetHeight

        for id in ids {
            let itemWidth = compactWidth(for: id)
            let itemHeight = compactWidgetHeight
            let proposedWidth = rowWidth + itemSpacing + itemWidth

            if proposedWidth > maxContentWidth {
                rows.append((rowWidth, rowHeight))
                rowWidth = itemWidth
                rowHeight = itemHeight
            } else {
                rowWidth = proposedWidth
                rowHeight = max(rowHeight, itemHeight)
            }
        }

        rows.append((rowWidth, rowHeight))
        return rows
    }

    static func compactWidth(for widgetID: DockWidgetID) -> CGFloat {
        switch widgetID {
        case .clock:
            return 88
        case .clipboard, .quickNote, .toolsPalette, .favorites, .runningApps, .worldClock, .audio, .calendar, .weather, .nowPlaying, .datadog:
            return iconWidgetWidth
        case .pomodoro:
            return 112
        case .date, .battery:
            return 112
        case .cpu, .memory, .disk, .gitStatus:
            return 112
        case .network:
            return 128
        default:
            return compactWidgetWidth
        }
    }

    static func origin(size: NSSize, position: DockPosition, screen: NSScreen?) -> NSPoint {
        let frame = resolvedVisibleFrame(screen)

        switch position {
        case .bottom:
            let display = screen ?? NSScreen.main
            let dock = UserDefaults(suiteName: "com.apple.dock")
            let orientation = dock?.string(forKey: "orientation") ?? "bottom"
            var bottom = frame.minY
            if orientation == "bottom", let display {
                let tileSize = (dock?.object(forKey: "tilesize") as? NSNumber)?.doubleValue ?? 64
                let largeSize = (dock?.object(forKey: "largesize") as? NSNumber)?.doubleValue ?? 128
                let iconSize = dock?.bool(forKey: "magnification") == true ? max(tileSize, largeSize) : tileSize
                // visibleFrame alone does not reserve space for a hidden or magnified Dock.
                bottom = max(bottom, display.frame.minY + min(max(iconSize, 16), 256) + 32)
            }
            return NSPoint(x: frame.midX - size.width / 2,
                           y: min(bottom + screenEdgeInset, max(frame.minY, frame.maxY - size.height - screenEdgeInset)))
        case .top:
            return NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height - screenEdgeInset)
        case .left:
            return NSPoint(x: frame.minX + screenEdgeInset, y: frame.midY - size.height / 2)
        case .right:
            return NSPoint(x: frame.maxX - size.width - screenEdgeInset, y: frame.midY - size.height / 2)
        }
    }

    static func clampedOrigin(_ origin: NSPoint, size: NSSize, screen: NSScreen?) -> NSPoint {
        let frame = resolvedVisibleFrame(screen)
        let minX = frame.minX + screenEdgeInset
        let maxX = frame.maxX - screenEdgeInset - size.width
        let minY = frame.minY + screenEdgeInset
        let maxY = frame.maxY - screenEdgeInset - size.height

        return NSPoint(
            x: min(max(origin.x, minX), max(minX, maxX)),
            y: min(max(origin.y, minY), max(minY, maxY))
        )
    }

    static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    static func isFrameVisible(_ frame: NSRect, screen: NSScreen?) -> Bool {
        let visibleFrame = resolvedVisibleFrame(screen)
        return visibleFrame.contains(frame)
    }

    private static func resolvedVisibleFrame(_ screen: NSScreen?) -> NSRect {
        let fallbackFrame = NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: maxDockWidth + screenEdgeInset * 2, height: 900)

        let frame = screen?.visibleFrame ?? fallbackFrame
        guard frame.width >= 320, frame.height >= height else {
            return fallbackFrame.width >= 320 ? fallbackFrame : NSRect(x: 0, y: 0, width: maxDockWidth + screenEdgeInset * 2, height: 900)
        }

        return frame
    }
}
