import AppKit
import CoreGraphics

enum ScreenRecordingAccess {
    case granted
    case requested
    case denied
}

enum CaptureManager {
    private static let screenRecordingRequestedKey = "Picnic.ScreenRecordingRequested"

    static func ensureScreenRecordingPermission() -> ScreenRecordingAccess {
        if CGPreflightScreenCaptureAccess() {
            return .granted
        }

        let defaults = UserDefaults.standard
        if defaults.bool(forKey: screenRecordingRequestedKey) == false {
            defaults.set(true, forKey: screenRecordingRequestedKey)
            _ = CGRequestScreenCaptureAccess()
            return .requested
        }

        return .denied
    }

    static func captureMainDisplay() -> NSImage? {
        let displayID = CGMainDisplayID()
        guard let cgImage = CGDisplayCreateImage(displayID) else { return nil }
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let size = CGSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale)
        return NSImage(cgImage: cgImage, size: size)
    }
}
