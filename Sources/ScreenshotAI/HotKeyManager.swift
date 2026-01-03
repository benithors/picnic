import Carbon
import Foundation

final class HotKeyManager {
    enum HotKeyID: Int {
        case capturePrimary = 1
        case captureFallback = 2
    }

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?
    var onCapture: (() -> Void)?

    func registerHotKeys() {
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
                if hotKeyID.id == HotKeyID.capturePrimary.rawValue || hotKeyID.id == HotKeyID.captureFallback.rawValue {
                    manager.onCapture?()
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

        registerHotKey(keyCode: UInt32(kVK_Help), modifiers: UInt32(controlKey), id: .capturePrimary)
        registerHotKey(keyCode: UInt32(kVK_ANSI_5), modifiers: UInt32(controlKey | shiftKey), id: .captureFallback)
    }

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: HotKeyID) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType("SNAI".fourCharCodeValue), id: UInt32(id.rawValue))
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        hotKeyRefs.append(hotKeyRef)
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
