import AppKit
import Combine
import EventKit
import SwiftUI

@MainActor
struct CalendarMeetingsWidgetView: View {
    @StateObject private var model = CalendarMeetingsModel()
    @State private var isPresented = false
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Button { isPresented.toggle() } label: {
            SystemApplicationIcon(bundleIdentifier: "com.apple.iCal", fallback: "calendar")
        }
        .buttonStyle(.plain)
        .help("Calendar meetings")
        .accessibilityLabel("Calendar meetings")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Upcoming events").font(.headline)
                    Spacer()
                    Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                        .help("Refresh calendar")
                        .disabled(model.isConnecting)
                }
                if model.isConnecting {
                    ProgressView("Connecting calendar...")
                } else if model.authorization == .fullAccess {
                    if model.events.isEmpty {
                        Text("No upcoming events in the next 7 days.").foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(model.events) { event in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title).font(.subheadline.weight(.semibold))
                                        Text(event.isAllDay
                                             ? "\(event.start.formatted(date: .abbreviated, time: .omitted)) - All day"
                                             : "\(event.start.formatted(date: .abbreviated, time: .shortened)) - \(event.end.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text(event.calendar).font(.caption).foregroundStyle(.secondary)
                                        if let url = event.meetingURL {
                                            Button { model.openMeeting(url) } label: {
                                                Label("Open meeting link", systemImage: "video")
                                            }
                                            .help(url.host ?? "Meeting link")
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Divider()
                                }
                            }
                        }
                        .frame(maxHeight: 340)
                    }
                } else if model.authorization == .denied || model.authorization == .restricted {
                    Text(model.authorization == .restricted
                         ? "Calendar access is restricted on this Mac."
                         : "Calendar access was denied. Allow full access in System Settings > Privacy & Security > Calendars.")
                        .foregroundStyle(.secondary)
                    Button("Check access again") { model.refresh() }
                } else {
                    Text("Connect your calendar to see upcoming events.").foregroundStyle(.secondary)
                    Button("Connect Calendar") { Task { await model.connect() } }
                }
                if let error = model.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            .dockPopoverPanel(width: 340)
            .onAppear { model.refresh() }
        }
        .onReceive(timer) { _ in if isPresented { model.refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
    }
}

@MainActor
private final class CalendarMeetingsModel: ObservableObject {
    struct Event: Identifiable {
        let id: Int
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let calendar: String
        let meetingURL: URL?
    }

    @Published private(set) var authorization = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var events: [Event] = []
    @Published private(set) var isConnecting = false
    @Published private(set) var error: String?
    private let store = EKEventStore()

    func connect() async {
        guard !isConnecting else { return }
        // A missing usage description can terminate the process when requesting access.
        guard let description = Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") as? String,
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Calendar access is not configured in this app build."
            return
        }
        isConnecting = true
        error = nil
        defer { isConnecting = false }
        do {
            // Keep the EventKit store on the main actor; only the result crosses executors.
            let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, any Error>) in
                store.requestFullAccessToEvents { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
            refresh()
            if !granted && authorization != .denied && authorization != .restricted {
                error = "Full calendar access was not granted. Try connecting again."
            }
        } catch {
            refresh()
            self.error = error.localizedDescription
        }
    }

    func refresh() {
        authorization = EKEventStore.authorizationStatus(for: .event)
        guard authorization == .fullAccess else {
            events = []
            return
        }
        error = nil
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .filter { $0.endDate > now && $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
            .prefix(50)
            .enumerated().map { index, event in
                Event(id: index, title: event.title ?? "Untitled event", start: event.startDate,
                      end: event.endDate, isAllDay: event.isAllDay, calendar: event.calendar.title,
                      meetingURL: Self.meetingURL(for: event))
            }
    }

    func openMeeting(_ url: URL) {
        guard Self.isWebURL(url) else { return }
        if !NSWorkspace.shared.open(url) {
            error = "The meeting link could not be opened."
        }
    }

    static func isWebURL(_ url: URL) -> Bool {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = parts.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil else { return false }
        return true
    }

    private static func meetingURL(for event: EKEvent) -> URL? {
        if let url = event.url, isWebURL(url) { return url }
        let text = [event.location, event.notes].compactMap { $0 }.joined(separator: "\n")
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap(\.url).first(where: isWebURL)
    }
}
