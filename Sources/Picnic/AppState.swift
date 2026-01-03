import AppKit

final class AppState {
    private let hotKeyManager = HotKeyManager.shared
    private var overlayController: OverlayWindowController?

    func start() {
        hotKeyManager.onCapture = { [weak self] in
            DispatchQueue.main.async {
                self?.triggerCapture()
            }
        }
        hotKeyManager.registerHotKeys()
    }

    func triggerCapture() {
        guard overlayController == nil else { return }

        switch CaptureManager.ensureScreenRecordingPermission() {
        case .granted:
            break
        case .requested:
            return
        case .denied:
            AlertPresenter.showPermissionAlert()
            return
        }

        guard let image = CaptureManager.captureMainDisplay() else {
            AlertPresenter.showErrorAlert(message: "Failed to capture the main display.")
            return
        }
        playCaptureSound()

        overlayController = OverlayWindowController(image: image) { [weak self] in
            self?.overlayController = nil
        }
        overlayController?.show()
    }

    private func playCaptureSound() {
        if let shutter = NSSound(named: NSSound.Name("cameraShutter")) {
            shutter.play()
            return
        }
        if let fallback = NSSound(named: NSSound.Name("Glass")) {
            fallback.play()
            return
        }
        NSSound.beep()
    }
}

enum AlertPresenter {
    static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Picnic"
        alert.informativeText = "Screen Recording permission is required. Enable Picnic in System Settings > Privacy & Security > Screen Recording. You may need to quit and relaunch after enabling."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }

    static func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Picnic"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
