import SwiftUI
import AppKit

struct DatadogWidgetView: View {
    @StateObject private var service = DatadogService()
    @State private var presented = false
    @State private var site = "datadoghq.com"
    @State private var apiKey = ""
    @State private var applicationKey = ""
    private static let icon = Bundle.main.url(forResource: "Datadog", withExtension: "png").flatMap(NSImage.init(contentsOf:))

    var body: some View {
        Button { presented.toggle() } label: {
            Group {
                if let icon = Self.icon {
                    Image(nsImage: icon).resizable().scaledToFit()
                } else {
                    Image(systemName: "waveform.path.ecg")
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(width: DockLayoutCalculator.iconWidgetWidth, height: DockTileMetrics.compactHeight)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).help("Datadog")
        .accessibilityLabel("Datadog")
        .popover(isPresented: $presented) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Datadog").font(.headline)
                    Spacer()
                    if service.connected {
                        Button { Task { await service.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                            .help("Refresh monitors").disabled(service.isLoading)
                    }
                }
                if !service.connected {
                    Picker("Site", selection: $site) {
                        ForEach(DatadogService.sites, id: \.self) { Text($0).tag($0) }
                    }
                    SecureField("API key", text: $apiKey)
                    SecureField("Application key", text: $applicationKey)
                    Button("Connect") {
                        Task {
                            await service.connect(site: site, apiKey: apiKey, applicationKey: applicationKey)
                            if service.connected { apiKey = ""; applicationKey = "" }
                        }
                    }.disabled(service.isLoading || apiKey.isEmpty || applicationKey.isEmpty)
                } else {
                    if service.isLoading { ProgressView() }
                    if let date = service.updatedAt {
                        Text("Updated \(date.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                    if service.monitors.isEmpty && !service.isLoading && service.error == nil {
                        Text("No monitors").foregroundStyle(.secondary)
                    }
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(service.monitors) { monitor in
                                if let url = service.monitorURL(monitor.id) {
                                    Link(destination: url) {
                                        HStack(alignment: .top) {
                                            Circle().fill(color(monitor.overall_state)).frame(width: 8, height: 8).padding(.top, 5)
                                            VStack(alignment: .leading) {
                                                Text(monitor.name).lineLimit(2)
                                                Text(monitor.overall_state ?? "Unknown").font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                            }
                            if service.hasMore {
                                Button("Load more") { Task { await service.refresh(more: true) } }.disabled(service.isLoading)
                            }
                        }
                    }.frame(height: min(CGFloat(service.monitors.count) * 54, 320))
                    Button("Disconnect", role: .destructive) { service.disconnect() }.disabled(service.isLoading)
                }
                if let error = service.error { Text(error).font(.caption).foregroundStyle(.red) }
            }.dockPopoverPanel(width: 350)
                .task { service.restore(); await service.refresh() }
        }
    }

    private func color(_ state: String?) -> Color {
        switch state {
        case "OK": .green
        case "Alert": .red
        case "Warn": .orange
        default: .gray
        }
    }
}
