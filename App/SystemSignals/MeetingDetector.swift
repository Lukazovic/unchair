import CoreAudio
import CoreMediaIO
import Foundation

/// Detects calls by checking whether another app is using the microphone or camera.
/// It only reads device state. It never captures audio or video.
enum MeetingDetector {
    static func isInMeeting() -> Bool {
        isMicrophoneInUse() || isCameraInUse()
    }

    /// What the detector can see, for logging. Useful to confirm the sandbox
    /// doesn't hide devices or processes.
    static func diagnostics() -> String {
        let devices = objectList(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDevices) ?? []
        let inputs = devices.filter(hasInputStreams).count
        var processes = -1
        if #available(macOS 14.2, *) {
            processes = objectList(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList)?
                .count ?? -1
        }
        return "audioInputs=\(inputs) audioProcesses=\(processes) cameras=\(cameraDevices().count)"
    }

    // MARK: - Microphone

    static func isMicrophoneInUse() -> Bool {
        if #available(macOS 14.2, *), let result = isMicrophoneInUseByAnotherProcess() {
            return result
        }
        return isAnyInputDeviceRunning()
    }

    /// Per-process input state. Precise: playing music doesn't count.
    @available(macOS 14.2, *)
    private static func isMicrophoneInUseByAnotherProcess() -> Bool? {
        guard let processes = objectList(
            AudioObjectID(kAudioObjectSystemObject),
            kAudioHardwarePropertyProcessObjectList
        ), !processes.isEmpty else { return nil }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return processes.contains { process in
            scalar(process, kAudioProcessPropertyIsRunningInput, as: UInt32.self) == 1
                && scalar(process, kAudioProcessPropertyPID, as: pid_t.self) != ownPID
        }
    }

    /// Device-level fallback. Less precise for devices that also play audio.
    private static func isAnyInputDeviceRunning() -> Bool {
        let devices = objectList(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDevices) ?? []
        return devices.contains { device in
            hasInputStreams(device)
                && scalar(device, kAudioDevicePropertyDeviceIsRunningSomewhere, as: UInt32.self) == 1
        }
    }

    private static func hasInputStreams(_ device: AudioObjectID) -> Bool {
        var address = address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func scalar<Value: BinaryInteger>(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        as _: Value.Type
    ) -> Value? {
        var address = address(selector)
        var value: Value = 0
        var size = UInt32(MemoryLayout<Value>.size)
        let status = withUnsafeMutableBytes(of: &value) { buffer in
            guard let pointer = buffer.baseAddress else { return OSStatus(kAudioHardwareUnspecifiedError) }
            return AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        }
        return status == noErr ? value : nil
    }

    private static func objectList(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector
    ) -> [AudioObjectID]? {
        var address = address(selector)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr else { return nil }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &objects) == noErr else { return nil }
        return objects
    }

    // MARK: - Camera

    static func isCameraInUse() -> Bool {
        cameraDevices().contains { device in
            var address = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            var running: UInt32 = 0
            var used: UInt32 = 0
            let size = UInt32(MemoryLayout<UInt32>.size)
            return CMIOObjectGetPropertyData(device, &address, 0, nil, size, &used, &running) == noErr && running != 0
        }
    }

    static func cameraDevices() -> [CMIOObjectID] {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == noErr else { return [] }
        return devices
    }
}
