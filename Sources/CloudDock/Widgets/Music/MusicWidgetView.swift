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
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { notification in
            handleMusicLifecycle(notification)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { notification in
            handleMusicLifecycle(notification)
        }
    }

    private func handleMusicLifecycle(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "com.apple.Music" else { return }
        model.musicLifecycleChanged()
        if isPresented { model.refresh() }
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
                .disabled(model.isBusy || model.isLaunching)
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
                .disabled(model.isBusy || model.isLaunching || !model.isMusicRunning)

                Button {
                    model.togglePlayPause()
                } label: {
                    Image(systemName: model.playPauseSymbolName)
                        .frame(width: 22)
                }
                .buttonStyle(.borderless)
                .help(model.playPauseHelpText)
                .disabled(model.isBusy || model.isLaunching)

                Button {
                    model.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .frame(width: 22)
                }
                .buttonStyle(.borderless)
                .help("Next track")
                .disabled(model.isBusy || model.isLaunching || !model.isMusicRunning)

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
