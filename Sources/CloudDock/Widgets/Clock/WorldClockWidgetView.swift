import SwiftUI

struct WorldClockWidgetView: View {
    @AppStorage("cloudDock.worldClockZones") private var storedZones = "Asia/Seoul,America/New_York,Europe/London"
    @State private var isPresented = false
    @State private var query = ""
    @State private var isAddingCity = false

    private var zones: [String] { storedZones.split(separator: ",").map(String.init) }
    private var matches: [String] {
        guard !query.isEmpty else { return [] }
        return TimeZone.knownTimeZoneIdentifiers.filter {
            $0.replacingOccurrences(of: "_", with: " ").localizedCaseInsensitiveContains(query) && !zones.contains($0)
        }
    }

    var body: some View {
        Button { isPresented.toggle() } label: {
            SystemApplicationIcon(bundleIdentifier: "com.apple.clock", fallback: "globe")
        }.buttonStyle(.plain).help("World Clock")
        .accessibilityLabel("World Clock")
        .popover(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("World Clock").font(.headline)
                    Text("\(zones.count)").foregroundStyle(.secondary)
                    Spacer()
                    Button { isAddingCity.toggle() } label: {
                        Image(systemName: isAddingCity ? "xmark" : "plus")
                    }.help(isAddingCity ? "Close city search" : "Add city")
                }
                if zones.isEmpty { Text("No cities").foregroundStyle(.secondary) }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(zones, id: \.self) { identifier in
                                if let zone = TimeZone(identifier: identifier) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(identifier.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: "_", with: " ") ?? identifier)
                                            Text(formatted(context.date, zone: zone, time: false))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(formatted(context.date, zone: zone, time: true))
                                            .font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
                                        Button { storedZones = zones.filter { $0 != identifier }.joined(separator: ",") } label: {
                                            Image(systemName: "minus.circle")
                                        }.help("Remove city")
                                    }.frame(height: 40)
                                }
                            }
                        }
                    }.frame(height: CGFloat(min(zones.count, 6)) * 52)
                }
                if isAddingCity {
                    TextField("Search city or time zone", text: $query)
                }
                if isAddingCity && !query.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(matches, id: \.self) { identifier in
                                Button(identifier.replacingOccurrences(of: "_", with: " ")) {
                                    storedZones = (zones + [identifier]).joined(separator: ",")
                                    query = ""
                                    isAddingCity = false
                                }.buttonStyle(.plain)
                            }
                            if matches.isEmpty { Text("No matching time zones").foregroundStyle(.secondary) }
                        }
                    }.frame(height: 140)
                }
            }.dockPopoverPanel(width: 340)
        }
    }

    private func formatted(_ date: Date, zone: TimeZone, time: Bool) -> String {
        var style = time
            ? Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
            : Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        style.timeZone = zone
        return date.formatted(style)
    }
}
