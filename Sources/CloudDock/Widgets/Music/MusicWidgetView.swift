import AppKit
import SwiftUI

struct MusicWidgetView: View {
    @StateObject private var model = MusicWidgetModel()
    @State private var isPresented = false

    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            model.refresh()
            isPresented.toggle()
        } label: {
            SystemApplicationIcon(bundleIdentifier: "com.apple.Music", fallback: "music.note")
        }
        .buttonStyle(.plain)
        .help("Music")
        .accessibilityLabel("Apple Music")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            popoverContent
        }
        .onReceive(timer) { _ in
            if isPresented {
                model.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if isPresented {
                model.refresh()
            }
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Music")
                    .font(.headline)
                Spacer()
                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh music")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(model.trackTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(model.subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Button {
                    model.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .frame(width: 22)
                }
                .buttonStyle(.borderless)
                .help("Previous track")

                Button {
                    model.togglePlayPause()
                } label: {
                    Image(systemName: model.playPauseSymbolName)
                        .frame(width: 22)
                }
                .buttonStyle(.borderless)
                .help(model.playPauseHelpText)

                Button {
                    model.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .frame(width: 22)
                }
                .buttonStyle(.borderless)
                .help("Next track")

                Spacer()

                Text(model.stateText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if model.duration > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: model.progress)
                    HStack {
                        Text(model.currentTimeText)
                        Spacer()
                        Text(model.durationText)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }

            if let error = model.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .dockPopoverPanel(width: 300)
        .fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
private final class MusicWidgetModel: ObservableObject {
    @Published private(set) var state: MusicPlaybackState = .stopped
    @Published private(set) var trackTitle = "Music"
    @Published private(set) var artist = ""
    @Published private(set) var album = ""
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var error: String?

    func refresh() {
        guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.apple.Music" }) else {
            state = .stopped
            trackTitle = "Music"
            artist = ""
            album = ""
            currentTime = 0
            duration = 0
            error = nil
            return
        }

        guard let output = runAppleScript(Self.statusScript) else {
            state = .stopped
            trackTitle = "Music"
            artist = ""
            album = ""
            currentTime = 0
            duration = 0
            return
        }

        let parts = output.components(separatedBy: "|||")
        state = MusicPlaybackState(rawValue: parts[safe: 0]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? .unknown
        trackTitle = parts[safe: 1]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        artist = parts[safe: 2]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        album = parts[safe: 3]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        duration = Double(parts[safe: 4]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
        currentTime = Double(parts[safe: 5]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
        error = nil

        if trackTitle.isEmpty {
            trackTitle = state == .playing ? "Playing music" : "Music"
        }
    }

    func previousTrack() {
        guard runAppleScript(Self.previousScript) != nil else { return }
        refresh()
    }

    func togglePlayPause() {
        guard runAppleScript(Self.playPauseScript) != nil else { return }
        refresh()
    }

    func nextTrack() {
        guard runAppleScript(Self.nextScript) != nil else { return }
        refresh()
    }

    var isPlaying: Bool {
        state == .playing
    }

    var compactSymbolName: String {
        switch state {
        case .playing:
            return "pause.fill"
        case .paused:
            return "play.fill"
        case .stopped, .unknown:
            return "music.note"
        }
    }

    var playPauseSymbolName: String {
        state == .playing ? "pause.fill" : "play.fill"
    }

    var playPauseHelpText: String {
        state == .playing ? "Pause" : "Play"
    }

    var stateText: String {
        switch state {
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        case .stopped:
            return "Stopped"
        case .unknown:
            return "Unavailable"
        }
    }

    var subtitleText: String {
        let components = [artist, album].filter { !$0.isEmpty }

        if !components.isEmpty {
            return components.joined(separator: " • ")
        }

        return stateText
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    var currentTimeText: String {
        formatTime(currentTime)
    }

    var durationText: String {
        formatTime(duration)
    }

    private func runAppleScript(_ source: String) -> String? {
        guard let usageDescription = Bundle.main.object(forInfoDictionaryKey: "NSAppleEventsUsageDescription") as? String,
              !usageDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Music control requires NSAppleEventsUsageDescription in the app's Info.plist."
            return nil
        }

        guard let script = NSAppleScript(source: "with timeout of 3 seconds\n\(source)\nend timeout") else {
            error = "Music control could not prepare the AppleScript command."
            return nil
        }

        var scriptError: NSDictionary?
        let descriptor = script.executeAndReturnError(&scriptError)

        if let scriptError {
            error = Self.message(for: scriptError)
            return nil
        }

        return descriptor.stringValue
    }

    private func formatTime(_ value: Double) -> String {
        guard value.isFinite, value > 0 else {
            return "0:00"
        }

        let rounded = Int(value.rounded())
        let hours = rounded / 3600
        let minutes = (rounded % 3600) / 60
        let seconds = rounded % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }

    private static func message(for errorInfo: NSDictionary) -> String {
        let errorNumber = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
        if errorNumber == -1743 {
            return "Allow CloudDock to control Music in System Settings > Privacy & Security > Automation."
        }

        if let message = errorInfo[NSAppleScript.errorMessage] as? String, !message.isEmpty {
            return message
        }

        return "Music control failed."
    }

    private static let statusScript = """
    tell application "Music"
        set theState to player state as text
        set theTitle to ""
        set theArtist to ""
        set theAlbum to ""
        set theDuration to 0
        set thePosition to 0

        if theState is "playing" or theState is "paused" then
            set theTitle to name of current track
            set theArtist to artist of current track
            set theAlbum to album of current track
            set theDuration to duration of current track
            set thePosition to player position
        end if

        return theState & "|||" & theTitle & "|||" & theArtist & "|||" & theAlbum & "|||" & theDuration & "|||" & thePosition
    end tell
    """

    private static let previousScript = """
    tell application "Music"
        previous track
    end tell
    """

    private static let playPauseScript = """
    tell application "Music"
        playpause
    end tell
    """

    private static let nextScript = """
    tell application "Music"
        next track
    end tell
    """
}

private enum MusicPlaybackState: String {
    case playing
    case paused
    case stopped
    case unknown
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
