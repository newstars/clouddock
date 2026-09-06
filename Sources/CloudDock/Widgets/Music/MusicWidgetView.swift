import AppKit
import SwiftUI

struct MusicWidgetView: View {
    @StateObject private var model = MusicWidgetModel()
    @State private var isPresented = false

    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            isPresented.toggle()
            if isPresented { model.refresh(clearError: true) }
        } label: {
            SystemApplicationIcon(bundleIdentifier: "com.apple.Music", fallback: "music.note")
        }
        .buttonStyle(.plain)
        .help("Music")
        .accessibilityLabel("Apple Music")
        .contextMenu {
            Button("Open Apple Music") { model.openMusic() }
        }
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
                Button {
                    model.openMusic()
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .help("Open Apple Music")
                .accessibilityLabel("Open Apple Music")
                .disabled(model.isLaunching)
                Spacer()
                Button {
                    model.refresh(clearError: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh music")
            }

            if model.isLaunching { ProgressView("Opening Music...") }

            HStack(spacing: 10) {
                Group {
                    if let artwork = model.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.white.opacity(0.08))
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel("Album artwork")

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
                .frame(maxWidth: .infinity, alignment: .leading)
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
                .disabled(model.isLaunching || !model.isMusicRunning)

                Button {
                    model.togglePlayPause()
                } label: {
                    Image(systemName: model.playPauseSymbolName)
                        .frame(width: 22)
                }
                .buttonStyle(.borderless)
                .help(model.playPauseHelpText)
                .disabled(model.isLaunching)

                Button {
                    model.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .frame(width: 22)
                }
                .buttonStyle(.borderless)
                .help("Next track")
                .disabled(model.isLaunching || !model.isMusicRunning)

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
    @Published private(set) var isLaunching = false
    @Published private(set) var artwork: NSImage?
    private var artworkKey: [String] = []

    var isMusicRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Music" }
    }

    func openMusic(activates: Bool = true, completion: (@MainActor () -> Void)? = nil) {
        guard !isLaunching else { return }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") else {
            error = "Apple Music is not installed."; return
        }
        error = nil
        isLaunching = true
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        configuration.hides = !activates
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { @Sendable [weak self] _, error in
            let failed = error != nil
            Task { @MainActor in
                self?.isLaunching = false
                if failed {
                    self?.error = "Apple Music could not be opened."
                } else {
                    completion?()
                }
            }
        }
    }

    func refresh(clearError: Bool = false) {
        if clearError { error = nil }
        guard !isLaunching, error == nil else { return }
        guard isMusicRunning else {
            artwork = nil
            artworkKey = []
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
            artwork = nil
            artworkKey = []
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

        refreshArtwork()

        if trackTitle.isEmpty {
            trackTitle = state == .playing ? "Playing music" : "Music"
        }
    }

    func previousTrack() {
        guard isMusicRunning, !isLaunching else { return }
        error = nil
        guard runAppleScript(Self.previousScript) != nil else { return }
        refresh()
    }

    private func refreshArtwork() {
        guard state == .playing || state == .paused else {
            artwork = nil
            artworkKey = []
            return
        }
        let key = [trackTitle, artist, album]
        guard key != artworkKey else { return }
        artworkKey = key
        artwork = nil
        // Artwork is optional; a missing image must not interrupt playback controls.
        guard let script = NSAppleScript(source: Self.artworkScript) else { return }
        var scriptError: NSDictionary?
        let result = script.executeAndReturnError(&scriptError)
        guard scriptError == nil, result.data.count <= 20_000_000 else { return }
        artwork = NSImage(data: result.data)
    }

    func togglePlayPause() {
        guard !isLaunching else { return }
        guard isMusicRunning else {
            openMusic(activates: false) { [weak self] in self?.togglePlayPause() }
            return
        }
        error = nil
        guard let result = runAppleScript(Self.playPauseScript) else { return }
        if result == "no-track" {
            error = "Choose a song or playlist in Apple Music first."
            return
        }
        refresh()
    }

    func nextTrack() {
        guard isMusicRunning, !isLaunching else { return }
        error = nil
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

        // Playback commands can succeed without returning a string.
        return descriptor.stringValue ?? ""
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

    private static let artworkScript = """
    with timeout of 2 seconds
        tell application "Music"
            if exists current track then
                if (count of artworks of current track) > 0 then
                    return raw data of artwork 1 of current track
                end if
            end if
        end tell
    end timeout
    """

    private static let playPauseScript = """
    tell application "Music"
        if player state is playing then
            pause
        else if player state is paused then
            play
        else
            if exists current track then
                play
            else
                set selectedTracks to selection
                if (count of selectedTracks) > 0 then
                    play item 1 of selectedTracks
                else
                    return "no-track"
                end if
            end if
        end if
        return "ok"
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
