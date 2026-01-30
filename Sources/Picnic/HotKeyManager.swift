import Carbon
import Cocoa
import Foundation

struct SavedShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let displayString: String
}

final class HotKeyManager {
    static let shared = HotKeyManager()
    
    enum HotKeyID: Int {
        case capture = 1
        case selectionCopy = 2
        case selectionCancel = 3
    }

    private var hotKeyRef: EventHotKeyRef?
    private var selectionCopyHotKeyRef: EventHotKeyRef?
    private var selectionCancelHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    var onCapture: (() -> Void)?
    var onSelectionCopy: (() -> Void)?
    var onSelectionCancel: (() -> Void)?
    
    private let shortcutKey = "Picnic.CaptureShortcut"

    init() {
        // Load initial shortcut or default
    }

    func registerHotKeys() {
        // Install event handler once
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, userData in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if status == noErr {
                if hotKeyID.id == UInt32(HotKeyID.capture.rawValue) {
                    manager.onCapture?()
                } else if hotKeyID.id == UInt32(HotKeyID.selectionCopy.rawValue) {
                    manager.onSelectionCopy?()
                } else if hotKeyID.id == UInt32(HotKeyID.selectionCancel.rawValue) {
                    manager.onSelectionCancel?()
                }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        loadAndRegister()
    }
    
    func loadAndRegister() {
        unregisterCurrent()
        
        if let data = UserDefaults.standard.data(forKey: shortcutKey),
           let shortcut = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
        } else {
            // Default: Shift + Cmd + 5 (kVK_ANSI_5 = 0x17)
            // Carbon modifiers: cmdKey (256) + shiftKey (512)
            let defaultKeyCode: UInt32 = 0x17 // kVK_ANSI_5
            let defaultModifiers = UInt32(cmdKey | shiftKey)
            register(keyCode: defaultKeyCode, modifiers: defaultModifiers)
        }
    }
    
    func saveShortcut(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, characters: String?) {
        let carbonModifiers = Self.convertToCarbonModifiers(modifiers)
        let display = Self.shortcutString(modifiers: modifiers, characters: characters, keyCode: keyCode)
        
        let shortcut = SavedShortcut(keyCode: keyCode, modifiers: carbonModifiers, displayString: display)
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: shortcutKey)
            loadAndRegister()
        }
    }
    
    private func register(keyCode: UInt32, modifiers: UInt32) {
        let hotKeyID = EventHotKeyID(signature: OSType("SNAI".fourCharCodeValue), id: UInt32(HotKeyID.capture.rawValue))
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    private func unregisterCurrent() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    func registerSelectionHotKeys() {
        unregisterSelectionHotKeys()

        let copyID = EventHotKeyID(signature: OSType("SNAI".fourCharCodeValue), id: UInt32(HotKeyID.selectionCopy.rawValue))
        RegisterEventHotKey(UInt32(kVK_ANSI_C), UInt32(cmdKey), copyID, GetApplicationEventTarget(), 0, &selectionCopyHotKeyRef)

        let cancelID = EventHotKeyID(signature: OSType("SNAI".fourCharCodeValue), id: UInt32(HotKeyID.selectionCancel.rawValue))
        RegisterEventHotKey(UInt32(kVK_Escape), 0, cancelID, GetApplicationEventTarget(), 0, &selectionCancelHotKeyRef)
    }

    func unregisterSelectionHotKeys() {
        if let ref = selectionCopyHotKeyRef {
            UnregisterEventHotKey(ref)
            selectionCopyHotKeyRef = nil
        }
        if let ref = selectionCancelHotKeyRef {
            UnregisterEventHotKey(ref)
            selectionCancelHotKeyRef = nil
        }
    }
    
    static func convertToCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        return modifiers
    }
    
    static func shortcutString(modifiers: NSEvent.ModifierFlags, characters: String?, keyCode: UInt32) -> String {
        var string = ""
        if modifiers.contains(.control) { string += "⌃" }
        if modifiers.contains(.option) { string += "⌥" }
        if modifiers.contains(.shift) { string += "⇧" }
        if modifiers.contains(.command) { string += "⌘" }
        
        if let chars = characters?.uppercased(), !chars.isEmpty {
             // Handle some special keys if needed, otherwise use chars
             // A better approach is using the key code to map to display strings for special keys
             string += keyString(for: keyCode) ?? chars
        }
        
        return string
    }
    
    private static func keyString(for keyCode: UInt32) -> String? {
        // Partial mapping for common special keys
        switch Int(keyCode) {
        case kVK_Return: return "↩"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "Esc"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return nil
        }
    }
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for char in utf8.prefix(4) {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
}
