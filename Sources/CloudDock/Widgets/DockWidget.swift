import Foundation

enum DockWidgetID: String, Codable, CaseIterable, Identifiable {
    case clock
    case date
    case pomodoro
    case cpu
    case memory
    case network
    case disk
    case clipboard
    case quickNote
    case toolsPalette
    case gitStatus
    case github
    case datadog
    case kubernetes
    case aws
    case battery
    case calendar
    case weather
    case nowPlaying
    case revenue
    case favorites
    case runningApps
    case worldClock
    case audio

    var id: String { rawValue }
}

enum WidgetCategory: String, CaseIterable, Identifiable {
    case quickAccess
    case dailyFocus
    case macControls
    case utility
    case business
    case developer
    case cloud

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickAccess: "Quick Access"
        case .dailyFocus: "Daily Focus"
        case .macControls: "Mac Controls"
        case .utility: "Utility"
        case .business: "Business"
        case .developer: "Developer"
        case .cloud: "Cloud"
        }
    }
}

enum WidgetAvailability: Equatable {
    case available
    case planned
}

struct DockWidgetDescriptor: Identifiable, Equatable {
    let id: DockWidgetID
    let title: String
    let symbolName: String
    let category: WidgetCategory
    let summary: String
    let availability: WidgetAvailability

    var isAvailable: Bool {
        availability == .available
    }
}

enum WidgetRegistry {
    static let availableWidgets: [DockWidgetDescriptor] = [
        DockWidgetDescriptor(id: .favorites, title: "Files & Folders", symbolName: "folder.badge.star", category: .quickAccess, summary: "Favorite files and folders", availability: .available),
        DockWidgetDescriptor(id: .runningApps, title: "Running Apps", symbolName: "app.badge", category: .quickAccess, summary: "Switch between running applications", availability: .available),
        DockWidgetDescriptor(id: .worldClock, title: "World Clock", symbolName: "globe", category: .dailyFocus, summary: "Local time in your cities", availability: .available),
        DockWidgetDescriptor(id: .audio, title: "Audio", symbolName: "speaker.wave.2", category: .macControls, summary: "Volume and output devices", availability: .available),
        DockWidgetDescriptor(id: .clock, title: "Clock", symbolName: "clock", category: .dailyFocus, summary: "Current time", availability: .available),
        DockWidgetDescriptor(id: .date, title: "Date", symbolName: "calendar", category: .dailyFocus, summary: "Today at a glance", availability: .available),
        DockWidgetDescriptor(id: .pomodoro, title: "Pomodoro", symbolName: "timer", category: .dailyFocus, summary: "Focus timer", availability: .available),
        DockWidgetDescriptor(id: .cpu, title: "CPU", symbolName: "cpu", category: .macControls, summary: "Processor load", availability: .available),
        DockWidgetDescriptor(id: .memory, title: "Memory", symbolName: "memorychip", category: .macControls, summary: "Memory pressure", availability: .available),
        DockWidgetDescriptor(id: .network, title: "Network", symbolName: "arrow.down.left.arrow.up.right", category: .macControls, summary: "Throughput trend", availability: .available),
        DockWidgetDescriptor(id: .disk, title: "Disk", symbolName: "internaldrive", category: .macControls, summary: "Startup disk usage", availability: .available),
        DockWidgetDescriptor(id: .clipboard, title: "Clipboard", symbolName: "doc.on.clipboard", category: .utility, summary: "Recent copied text", availability: .available),
        DockWidgetDescriptor(id: .quickNote, title: "Notes", symbolName: "note.text", category: .dailyFocus, summary: "Pinned quick note", availability: .available),
        DockWidgetDescriptor(id: .toolsPalette, title: "Tools", symbolName: "ellipsis.circle", category: .quickAccess, summary: "Compact launcher for apps, clipboard, and notes", availability: .available),
        DockWidgetDescriptor(id: .gitStatus, title: "Git", symbolName: "point.3.connected.trianglepath.dotted", category: .developer, summary: "Branch and dirty state", availability: .available),
        DockWidgetDescriptor(id: .github, title: "GitHub", symbolName: "chevron.left.forwardslash.chevron.right", category: .developer, summary: "PRs, reviews, notifications", availability: .planned),
        DockWidgetDescriptor(id: .datadog, title: "Datadog", symbolName: "waveform.path.ecg", category: .cloud, summary: "Monitor states and alerts", availability: .available),
        DockWidgetDescriptor(id: .kubernetes, title: "Kubernetes", symbolName: "shippingbox", category: .cloud, summary: "Context and workloads", availability: .planned),
        DockWidgetDescriptor(id: .aws, title: "AWS", symbolName: "cloud", category: .cloud, summary: "Profile, account, region", availability: .planned),
        DockWidgetDescriptor(id: .battery, title: "Battery", symbolName: "battery.75percent", category: .macControls, summary: "Power and battery", availability: .available),
        DockWidgetDescriptor(id: .calendar, title: "Calendar", symbolName: "calendar.badge.clock", category: .dailyFocus, summary: "Today and next meetings", availability: .available),
        DockWidgetDescriptor(id: .weather, title: "Weather", symbolName: "cloud.sun", category: .utility, summary: "Forecast and conditions", availability: .available),
        DockWidgetDescriptor(id: .nowPlaying, title: "Music", symbolName: "music.note", category: .quickAccess, summary: "Apple Music playback controls", availability: .available),
        DockWidgetDescriptor(id: .revenue, title: "Revenue", symbolName: "dollarsign.circle", category: .business, summary: "Business metrics", availability: .planned)
    ]

    static let configurableWidgets: [DockWidgetDescriptor] = availableWidgets.filter(\.isAvailable)

    static let nativeAppWidgetIDs: Set<DockWidgetID> = [.worldClock, .calendar, .weather, .nowPlaying]

    static func groupingNativeApps(_ order: [DockWidgetID]) -> [DockWidgetID] {
        order.filter { !nativeAppWidgetIDs.contains($0) }
            + order.filter { nativeAppWidgetIDs.contains($0) }
    }

    static let legacyDefaultWidgetIDs: Set<DockWidgetID> = [.clock, .cpu, .memory, .gitStatus]

    static let defaultWidgetIDs: [DockWidgetID] = [
        .toolsPalette,
        .clock,
        .cpu,
        .memory,
        .clipboard
    ]

    static func descriptor(for id: DockWidgetID) -> DockWidgetDescriptor? {
        availableWidgets.first { $0.id == id }
    }

    static func searchableWidgets(matching query: String) -> [DockWidgetDescriptor] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return configurableWidgets
        }

        return configurableWidgets.filter { descriptor in
            descriptor.title.localizedCaseInsensitiveContains(trimmed)
                || descriptor.summary.localizedCaseInsensitiveContains(trimmed)
                || descriptor.category.title.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
