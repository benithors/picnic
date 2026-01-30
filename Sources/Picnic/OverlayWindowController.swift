import AppKit
import CoreGraphics
import SwiftUI

final class OverlayWindowController {
    private let window: NSWindow
    private let onClose: () -> Void
    private let viewModel: EditorViewModel

    init(image: NSImage, initialCropRect: CGRect? = nil, onClose: @escaping () -> Void) {
        self.onClose = onClose
        let displayID = CGMainDisplayID()
        let screenFrame = ScreenInfo.frame(for: displayID)
        let displayScale = ScreenInfo.scale(for: displayID)
        self.viewModel = EditorViewModel(image: image, screenFrame: screenFrame, displayScale: displayScale)
        if let initialCropRect {
            self.viewModel.cropRect = initialCropRect
        }

        let window = OverlayWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.isMovable = false
        window.isReleasedWhenClosed = false

        self.window = window

        let rootView = EditorView(
            model: viewModel,
            onSave: { [weak self] in self?.handleSave() },
            onCopy: { [weak self] in self?.handleCopy() },
            onClose: { [weak self] in self?.close() }
        )

        window.contentView = NSHostingView(rootView: rootView)
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleSave() {
        guard let image = viewModel.renderFinalImage() else {
            AlertPresenter.showErrorAlert(message: "Failed to render the screenshot.")
            return
        }
        do {
            _ = try OutputManager.savePNG(image)
            close()
        } catch {
            AlertPresenter.showErrorAlert(message: "Failed to save the screenshot.")
        }
    }

    private func handleCopy() {
        let override = viewModel.cropRect == nil ? viewModel.hoveredWindowRect : nil
        guard let image = viewModel.renderFinalImage(cropOverride: override) else {
            AlertPresenter.showErrorAlert(message: "Failed to render the screenshot.")
            return
        }
        OutputManager.copyToPasteboard(image)
        close()
    }

    private func close() {
        window.orderOut(nil)
        window.close()
        onClose()
    }
}
