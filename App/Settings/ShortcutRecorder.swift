import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press a key combination to record it. Escape cancels.
struct ShortcutRecorder: View {
    @Binding var shortcut: GlobalShortcut?
    /// Called when recording starts and stops.
    var onRecordingChange: (Bool) -> Void = { _ in }

    @State private var isRecording = false
    @State private var showsHint = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Button(action: toggleRecording) {
                    Group {
                        if isRecording {
                            Text("Press a shortcut…")
                        } else if let shortcut {
                            Text(verbatim: shortcut.symbols)
                                .monospaced()
                        } else {
                            Text("None")
                        }
                    }
                    .frame(minWidth: 130)
                }
                .accessibilityHint(Text("Press a key combination to set the shortcut"))

                if shortcut != nil, !isRecording {
                    Button {
                        shortcut = nil
                    } label: {
                        Label("Clear Shortcut", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(Text("Clear Shortcut"))
                }
            }

            if showsHint {
                Text("Include ⌘, ⌃, or ⌥, or use a function key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        showsHint = false
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                handle(event)
            }
            return nil
        }
    }

    private func handle(_ event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            stopRecording()
        } else if let recorded = GlobalShortcut(event: event) {
            shortcut = recorded
            stopRecording()
        } else {
            showsHint = true
            NSSound.beep()
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
        onRecordingChange(false)
    }
}
