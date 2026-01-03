import SwiftUI
import Carbon

struct ShortcutRecorder: View {
    @State private var isRecording = false
    @State private var currentDisplay: String = ""
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text("Capture Shortcut:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: toggleRecording) {
                Text(displayText)
                    .frame(minWidth: 100)
            }
        }
        .onAppear {
            loadCurrent()
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var displayText: String {
        if isRecording {
            return "Type Shortcut..."
        }
        return currentDisplay.isEmpty ? "Record" : currentDisplay
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func loadCurrent() {
        if let data = UserDefaults.standard.data(forKey: "Picnic.CaptureShortcut"),
           let shortcut = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            currentDisplay = shortcut.displayString
        } else {
            currentDisplay = "⌘⇧5"
        }
    }
    
    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore events that are just modifier key presses
            // We check if the keyCode is a modifier key code
            if isModifier(event.keyCode) {
                return event
            }
            
            HotKeyManager.shared.saveShortcut(
                keyCode: UInt32(event.keyCode),
                modifiers: event.modifierFlags,
                characters: event.charactersIgnoringModifiers
            )
            
            loadCurrent()
            stopRecording()
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func isModifier(_ keyCode: UInt16) -> Bool {
        let modifiers: [Int] = [
            kVK_Command,
            kVK_Shift,
            kVK_CapsLock,
            kVK_Option,
            kVK_Control,
            kVK_RightCommand,
            kVK_RightShift,
            kVK_RightOption,
            kVK_RightControl,
            kVK_Function
        ]
        return modifiers.contains(Int(keyCode))
    }
}
