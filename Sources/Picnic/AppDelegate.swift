import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        appState.start()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Picnic")
        }

        let menu = NSMenu()
        let captureItem = NSMenuItem(title: "Capture", action: #selector(handleCapture), keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(handlePreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About Benjamin Thorstensen", action: #selector(handleAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Picnic", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func handlePreferences() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 150),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Picnic Preferences"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleAbout() {
        let alert = NSAlert()
        alert.messageText = "About Benjamin Thorstensen"
        alert.informativeText = ""

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10

        if let logo = loadPicnicLogo() {
            let imageView = NSImageView(image: logo)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 72),
                imageView.heightAnchor.constraint(equalToConstant: 72)
            ])
            stack.addArrangedSubview(imageView)
        }

        let label = NSTextField(labelWithString: "✨ Hi! Say hello anytime.\n🌐 kylo.at")
        label.alignment = .center
        label.maximumNumberOfLines = 0
        stack.addArrangedSubview(label)

        alert.accessoryView = stack
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func loadPicnicLogo() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "picniclogo", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    @objc private func handleCapture() {
        appState.triggerCapture()
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }
}
