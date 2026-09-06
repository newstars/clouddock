import SwiftUI

@MainActor
struct DockWidgetFactory {
    @ObservedObject var viewModel: DockViewModel

    @ViewBuilder
    func view(for widget: DockWidgetDescriptor) -> some View {
        switch widget.id {
        case .favorites:
            FavoritesWidgetView()
        case .runningApps:
            RunningAppsWidgetView()
        case .worldClock:
            WorldClockWidgetView()
        case .audio:
            AudioWidgetView()
        case .datadog:
            DatadogWidgetView()
        case .calendar:
            CalendarMeetingsWidgetView()
        case .weather:
            WeatherWidgetView()
        case .nowPlaying:
            MusicWidgetView()
        case .clock:
            ClockWidgetView(
                descriptor: widget,
                privacyMode: viewModel.preferences.privacyMode
            )
        case .date:
            DateWidgetView(
                descriptor: widget,
                privacyMode: viewModel.preferences.privacyMode
            )
        case .pomodoro:
            PomodoroWidgetView(descriptor: widget)
        case .cpu:
            SystemMetricWidgetView(
                descriptor: widget,
                metric: .cpu,
                metricsService: viewModel.systemMetricsService,
                processMonitorService: viewModel.processMonitorService,
                privacyMode: viewModel.preferences.privacyMode
            )
        case .memory:
            SystemMetricWidgetView(
                descriptor: widget,
                metric: .memory,
                metricsService: viewModel.systemMetricsService,
                processMonitorService: viewModel.processMonitorService,
                privacyMode: viewModel.preferences.privacyMode
            )
        case .network:
            NetworkWidgetView(
                descriptor: widget,
                networkStatsService: viewModel.networkStatsService,
                privacyMode: viewModel.preferences.privacyMode
            )
        case .disk:
            DiskWidgetView(
                descriptor: widget,
                diskStatsService: viewModel.diskStatsService,
                privacyMode: viewModel.preferences.privacyMode
            )
        case .battery:
            BatteryWidgetView(
                descriptor: widget,
                batteryStatusService: viewModel.batteryStatusService,
                privacyMode: viewModel.preferences.privacyMode
            )
        case .clipboard:
            ClipboardWidgetView(
                descriptor: widget,
                clipboardService: viewModel.clipboardService,
                privacyMode: viewModel.preferences.privacyMode
            )
        case .quickNote:
            QuickNoteWidgetView(
                descriptor: widget,
                quickNoteService: viewModel.quickNoteService,
                privacyMode: viewModel.preferences.privacyMode
            )
        case .toolsPalette:
            ToolsPaletteWidgetView(
                descriptor: widget,
                launcherService: viewModel.appLauncherService,
                clipboardService: viewModel.clipboardService,
                quickNoteService: viewModel.quickNoteService,
                privacyMode: viewModel.preferences.privacyMode
            )
        case .gitStatus:
            GitStatusWidgetView(
                descriptor: widget,
                gitStatusService: viewModel.gitStatusService,
                privacyMode: viewModel.preferences.privacyMode
            )
        case .github, .kubernetes, .aws, .revenue:
            EmptyView()
        }
    }
}
