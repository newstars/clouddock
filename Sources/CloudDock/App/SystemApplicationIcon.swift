import AppKit
import SwiftUI

struct SystemApplicationIcon: View {
    private let icon: NSImage?
    private let fallback: String

    init(bundleIdentifier: String, fallback: String) {
        self.fallback = fallback
        icon = SystemApplicationIconCache.icon(for: bundleIdentifier)
    }

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: fallback).resizable().scaledToFit().padding(4)
            }
        }
        // macOS app artwork includes transparent margins inside its icon canvas.
        .frame(width: 46, height: 46)
        .frame(width: DockLayoutCalculator.iconWidgetWidth, height: DockTileMetrics.compactHeight)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}

@MainActor
private enum SystemApplicationIconCache {
    private static var icons: [String: NSImage] = [:]

    static func icon(for identifier: String) -> NSImage? {
        if let icon = icons[identifier] { return icon }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[identifier] = icon
        return icon
    }
}
