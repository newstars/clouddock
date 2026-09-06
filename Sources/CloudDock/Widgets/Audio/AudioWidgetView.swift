import AppKit
import CoreAudio
import SwiftUI

struct AudioWidgetView: View {
    @StateObject private var model = AudioWidgetModel()
    @State private var isPresented = false

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            model.refresh()
            isPresented.toggle()
        } label: {
            DockIconTile(accent: .cyan, isActive: isPresented) {
                Image(systemName: model.compactSymbolName)
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
        .help("Audio")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            popoverContent
        }
        .onAppear {
            model.refresh()
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
                Text("Audio")
                    .font(.headline)
                Spacer()
                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh audio")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(model.currentDeviceName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(model.currentDeviceStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let error = model.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.currentDeviceSupportsVolume {
                HStack(spacing: 8) {
                    Image(systemName: model.currentDeviceMute ? "speaker.slash.fill" : model.volumeSymbolName)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Slider(
                        value: Binding(
                            get: { Double(model.currentDeviceVolume) },
                            set: { model.setVolume(Float($0)) }
                        ),
                        in: 0...1
                    )

                    Text(model.volumeText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }

                Toggle(
                    isOn: Binding(
                        get: { model.currentDeviceMute },
                        set: { model.setMute($0) }
                    )
                ) {
                    Text("Mute")
                        .font(.caption)
                }
                .toggleStyle(.switch)
            } else {
                Text("This output device does not support hardware volume control.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Text("Output devices")
                .font(.subheadline.weight(.semibold))

            if model.outputDevices.isEmpty {
                Text("No output devices were found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(model.outputDevices) { device in
                            Button {
                                model.select(device)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: device.isDefault ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(device.isDefault ? .cyan : .secondary)
                                        .frame(width: 14)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(device.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.82)
                                        Text(device.detailText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Text(device.supportsVolume ? device.volumeText : "No volume")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(device.supportsVolume ? .secondary : .secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(device.name)
                        }
                    }
                }
                .frame(height: CGFloat(min(model.outputDevices.count, 6)) * 34)
            }
        }
        .dockPopoverPanel(width: 340)
        .fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
private final class AudioWidgetModel: ObservableObject {
    @Published private(set) var outputDevices: [AudioOutputDevice] = []
    @Published private(set) var currentDeviceID: AudioDeviceID?
    @Published private(set) var currentDeviceName = "Output"
    @Published private(set) var currentDeviceStatus = "Loading"
    @Published private(set) var currentDeviceVolume: Float = 0
    @Published private(set) var currentDeviceMute = false
    @Published private(set) var currentDeviceSupportsVolume = false
    @Published private(set) var error: String?

    func refresh() {
        let devices = AudioHardware.outputDevices()
        outputDevices = devices.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        guard let currentID = AudioHardware.defaultOutputDeviceID() else {
            currentDeviceID = nil
            currentDeviceName = "No output device"
            currentDeviceStatus = "System output unavailable"
            currentDeviceVolume = 0
            currentDeviceMute = false
            currentDeviceSupportsVolume = false
            error = nil
            return
        }

        currentDeviceID = currentID
        currentDeviceName = AudioHardware.deviceName(for: currentID)
        currentDeviceVolume = AudioHardware.volume(for: currentID) ?? 0
        currentDeviceMute = AudioHardware.isMuted(for: currentID) ?? false
        currentDeviceSupportsVolume = AudioHardware.supportsVolume(for: currentID)
        currentDeviceStatus = currentDeviceSupportsVolume ? "Volume \(volumeText)" : "Hardware volume not supported"
        error = nil

        outputDevices = outputDevices.map { device in
            var updated = device
            updated.isDefault = device.id == currentID
            if device.id == currentID {
                updated.volume = currentDeviceVolume
                updated.isMuted = currentDeviceMute
                updated.supportsVolume = currentDeviceSupportsVolume
            } else {
                updated.volume = AudioHardware.volume(for: device.id)
                updated.isMuted = AudioHardware.isMuted(for: device.id)
                updated.supportsVolume = AudioHardware.supportsVolume(for: device.id)
            }
            return updated
        }
    }

    func select(_ device: AudioOutputDevice) {
        guard AudioHardware.setDefaultOutputDevice(device.id) else {
            error = "The selected output device could not be set."
            return
        }

        refresh()
    }

    func setVolume(_ value: Float) {
        guard let currentDeviceID, currentDeviceSupportsVolume else {
            error = "This output device does not expose hardware volume control."
            return
        }

        let clamped = min(max(value, 0), 1)
        guard AudioHardware.setVolume(clamped, for: currentDeviceID) else {
            error = "The output device volume could not be changed."
            refresh()
            return
        }

        currentDeviceVolume = clamped
        currentDeviceStatus = "Volume \(volumeText)"
        updateCurrentDeviceCache()
    }

    func setMute(_ value: Bool) {
        guard let currentDeviceID, currentDeviceSupportsVolume else {
            error = "This output device does not expose hardware volume control."
            return
        }

        guard AudioHardware.setMute(value, for: currentDeviceID) else {
            error = "The output device mute state could not be changed."
            refresh()
            return
        }

        currentDeviceMute = value
        updateCurrentDeviceCache()
    }

    var compactSymbolName: String {
        guard currentDeviceSupportsVolume else {
            return "speaker.wave.2"
        }

        if currentDeviceMute || currentDeviceVolume <= 0.01 {
            return "speaker.slash"
        } else if currentDeviceVolume < 0.34 {
            return "speaker.wave.1"
        } else if currentDeviceVolume < 0.67 {
            return "speaker.wave.2"
        } else {
            return "speaker.wave.3"
        }
    }

    var volumeSymbolName: String {
        if currentDeviceMute || currentDeviceVolume <= 0.01 {
            return "speaker.slash"
        } else if currentDeviceVolume < 0.34 {
            return "speaker.wave.1"
        } else if currentDeviceVolume < 0.67 {
            return "speaker.wave.2"
        } else {
            return "speaker.wave.3"
        }
    }

    var volumeText: String {
        "\(Int((currentDeviceVolume * 100).rounded()))%"
    }

    private func updateCurrentDeviceCache() {
        guard let currentDeviceID else { return }
        outputDevices = outputDevices.map { device in
            guard device.id == currentDeviceID else { return device }
            var updated = device
            updated.volume = currentDeviceVolume
            updated.isMuted = currentDeviceMute
            updated.supportsVolume = currentDeviceSupportsVolume
            updated.isDefault = true
            return updated
        }
    }
}

private struct AudioOutputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    var name: String
    var volume: Float?
    var isMuted: Bool?
    var supportsVolume: Bool
    var isDefault: Bool

    var volumeText: String {
        "\(Int(((volume ?? 0) * 100).rounded()))%"
    }

    var detailText: String {
        if isDefault {
            return supportsVolume ? "Default output device" : "Default output device, no volume control"
        }

        return supportsVolume ? "Available output device" : "Available output device, no volume control"
    }
}

private enum AudioHardware {
    static func outputDevices() -> [AudioOutputDevice] {
        let defaultID = defaultOutputDeviceID()
        return allDeviceIDs().compactMap { deviceID in
            guard isOutputDevice(deviceID) else { return nil }
            return AudioOutputDevice(
                id: deviceID,
                name: deviceName(for: deviceID),
                volume: volume(for: deviceID),
                isMuted: isMuted(for: deviceID),
                supportsVolume: supportsVolume(for: deviceID),
                isDefault: deviceID == defaultID
            )
        }
    }

    static func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = withUnsafeMutableBytes(of: &deviceID) { rawPointer -> OSStatus in
            guard let baseAddress = rawPointer.baseAddress else { return -1 }
            return AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &dataSize,
                baseAddress
            )
        }
        return status == noErr ? deviceID : nil
    }

    static func setDefaultOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var mutableID = deviceID
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = withUnsafeMutableBytes(of: &mutableID) { rawPointer -> OSStatus in
            guard let baseAddress = rawPointer.baseAddress else { return -1 }
            return AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                dataSize,
                baseAddress
            )
        }
        return status == noErr
    }

    static func deviceName(for deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutableBytes(of: &name) { rawPointer -> OSStatus in
            guard let baseAddress = rawPointer.baseAddress else { return -1 }
            return AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                baseAddress
            )
        }

        guard status == noErr else {
            return "Output Device"
        }

        return name as String
    }

    static func supportsVolume(for deviceID: AudioDeviceID) -> Bool {
        readVolume(for: deviceID) != nil
    }

    static func volume(for deviceID: AudioDeviceID) -> Float? {
        readVolume(for: deviceID)
    }

    static func setVolume(_ value: Float, for deviceID: AudioDeviceID) -> Bool {
        let clamped = min(max(value, 0), 1)
        var changed = false

        for element in volumeElements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )

            guard AudioObjectHasProperty(deviceID, &address) else {
                continue
            }

            var mutableValue = clamped
            var dataSize = UInt32(MemoryLayout<Float>.size)
            let status = withUnsafeMutableBytes(of: &mutableValue) { rawPointer -> OSStatus in
                guard let baseAddress = rawPointer.baseAddress else { return -1 }
                return AudioObjectSetPropertyData(
                    deviceID,
                    &address,
                    0,
                    nil,
                    dataSize,
                    baseAddress
                )
            }

            if status == noErr {
                changed = true
                if element == kAudioObjectPropertyElementMain { return true }
            }
        }

        return changed
    }

    static func isMuted(for deviceID: AudioDeviceID) -> Bool? {
        guard let value = readUInt32(
            deviceID,
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput
        ) else {
            return nil
        }

        return value != 0
    }

    static func setMute(_ muted: Bool, for deviceID: AudioDeviceID) -> Bool {
        var changed = false
        for element in volumeElements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )

            guard AudioObjectHasProperty(deviceID, &address) else {
                continue
            }

            var mutableValue: UInt32 = muted ? 1 : 0
            var dataSize = UInt32(MemoryLayout<UInt32>.size)
            let status = withUnsafeMutableBytes(of: &mutableValue) { rawPointer -> OSStatus in
                guard let baseAddress = rawPointer.baseAddress else { return -1 }
                return AudioObjectSetPropertyData(
                    deviceID,
                    &address,
                    0,
                    nil,
                    dataSize,
                    baseAddress
                )
            }

            if status == noErr {
                changed = true
                if element == kAudioObjectPropertyElementMain { return true }
            }
        }

        return changed
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        ) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else {
            return []
        }

        var devices = Array(repeating: AudioDeviceID(0), count: count)
        let status = devices.withUnsafeMutableBytes { rawPointer -> OSStatus in
            guard let baseAddress = rawPointer.baseAddress else { return -1 }
            return AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &dataSize,
                baseAddress
            )
        }

        guard status == noErr else {
            return []
        }

        return devices
    }

    private static func isOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
        outputChannelCount(for: deviceID) > 0
    }

    private static func outputChannelCount(for deviceID: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0 else {
            return 0
        }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawPointer.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, rawPointer) == noErr else {
            return 0
        }

        let bufferListPointer = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        let audioBuffers = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return audioBuffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static let volumeElements: [AudioObjectPropertyElement] = [
        kAudioObjectPropertyElementMain,
        1,
        2
    ]

    private static func readVolume(for deviceID: AudioDeviceID) -> Float? {
        for element in volumeElements {
            if let value = readFloat(
                deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeOutput,
                element: element
            ) {
                return min(max(value, 0), 1)
            }
        }

        return nil
    }

    private static func readFloat(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )

        guard AudioObjectHasProperty(deviceID, &address) else {
            return nil
        }

        var value: Float = 0
        var dataSize = UInt32(MemoryLayout<Float>.size)
        let status = withUnsafeMutableBytes(of: &value) { rawPointer -> OSStatus in
            guard let baseAddress = rawPointer.baseAddress else { return -1 }
            return AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                baseAddress
            )
        }

        return status == noErr ? value : nil
    }

    private static func readUInt32(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )

        guard AudioObjectHasProperty(deviceID, &address) else {
            return nil
        }

        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = withUnsafeMutableBytes(of: &value) { rawPointer -> OSStatus in
            guard let baseAddress = rawPointer.baseAddress else { return -1 }
            return AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                baseAddress
            )
        }

        return status == noErr ? value : nil
    }
}
