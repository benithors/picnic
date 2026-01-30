import AppKit
import CoreGraphics

enum ScreenInfo {
    static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return number.uint32Value == displayID
        }
    }

    static func frame(for displayID: CGDirectDisplayID) -> CGRect {
        screen(for: displayID)?.frame ?? NSScreen.main?.frame ?? .zero
    }

    static func scale(for displayID: CGDirectDisplayID) -> CGFloat {
        if let screen = screen(for: displayID) {
            let displayBounds = CGDisplayBounds(displayID)
            let pointWidth = screen.frame.width
            if pointWidth > 0 {
                let scale = displayBounds.width / pointWidth
                if scale > 0 {
                    return scale
                }
            }
            return screen.backingScaleFactor
        }
        return NSScreen.main?.backingScaleFactor ?? 1.0
    }
}
