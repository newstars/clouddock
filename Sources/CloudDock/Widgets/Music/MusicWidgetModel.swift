import AppKit
import SwiftUI

@MainActor
final class MusicWidgetModel: ObservableObject {
    @Published private(set) var state: MusicPlaybackState = .stopped
    @Published private(set) var trackTitle = "Music"
    @Published private(set) var artist = ""
    @Published private(set) var album = ""
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var error: String?
    @Published private(set) var isLaunching = false
    @Published private(set) var artwork: NSImage?
    @Published private(set) var isBusy = false
    private var artworkKey: [String] = []
    private let execute: @Sendable (String) async -> MusicScriptResult
    private let running: @MainActor () -> Bool
    private let usageDescription: String?

    init(execute: @escaping @Sendable (String) async -> MusicScriptResult = { await MusicScriptExecutor.execute($0) },
         running: @escaping @MainActor () -> Bool = {
             NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Music" }
         }, usageDescription: String? = Bundle.main.object(forInfoDictionaryKey: "NSAppleEventsUsageDescription") as? String) {
        self.execute = execute
        self.running = running
        self.usageDescription = usageDescription
    }

    var isMusicRunning: Bool {
        running()
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
        guard !isBusy, !isLaunching else { return }
        if clearError { error = nil }
        guard error == nil else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            await refreshState()
        }
    }

    private func refreshState() async {
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

        guard let output = await runAppleScript(Self.statusScript) else {
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

        await refreshArtwork()

        if trackTitle.isEmpty {
            trackTitle = state == .playing ? "Playing music" : "Music"
        }
    }

    func previousTrack() {
        guard isMusicRunning, !isLaunching else { return }
        perform(Self.previousScript)
    }

    private func refreshArtwork() async {
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
        let result = await execute(Self.artworkScript)
        guard result.errorNumber == nil, result.data.count <= 20_000_000 else { return }
        artwork = NSImage(data: result.data)
    }

    func togglePlayPause() {
        guard !isLaunching, !isBusy else { return }
        guard isMusicRunning else {
            openMusic(activates: false) { [weak self] in self?.togglePlayPause() }
            return
        }
        perform(Self.playPauseScript)
    }

    func nextTrack() {
        guard isMusicRunning, !isLaunching else { return }
        perform(Self.nextScript)
    }

    private func perform(_ source: String) {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        Task {
            defer { isBusy = false }
            guard let result = await runAppleScript(source) else { return }
            if result == "no-track" {
                error = "Choose a song or playlist in Apple Music first."
                return
            }
            await refreshState()
        }
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

    private func runAppleScript(_ source: String) async -> String? {
        guard let usageDescription,
              !usageDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Music control requires NSAppleEventsUsageDescription in the app's Info.plist."
            return nil
        }

        let result = await execute("with timeout of 3 seconds\n\(source)\nend timeout")
        if result.errorNumber != nil {
            error = Self.message(for: result)
            return nil
        }

        // Playback commands can succeed without returning a string.
        return result.text
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

    private static func message(for result: MusicScriptResult) -> String {
        let errorNumber = result.errorNumber ?? 0
        if errorNumber == -1743 {
            return "Allow CloudDock to control Music in System Settings > Privacy & Security > Automation."
        }

        if let message = result.errorMessage, !message.isEmpty {
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

enum MusicPlaybackState: String {
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
