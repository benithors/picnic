import AppKit
import CoreGraphics
import QuartzCore

struct WindowSelectionInfo: Equatable {
    let windowID: CGWindowID
    let bounds: CGRect
}

final class WindowSelectionOverlayController {
    private struct WindowCandidate {
        let windowID: Int
        let bounds: CGRect
        let ownerName: String
        let windowName: String
    }

    private let window: NSWindow
    private let overlayView: WindowSelectionOverlayView
    private let onCapture: (CGRect) -> Void
    private let onClose: () -> Void
    private let hotKeyManager = HotKeyManager.shared
    private let screenFrame: CGRect
    private let displayScale: CGFloat
    private var hoveredWindow: WindowSelectionInfo?
    private var updateTimer: Timer?
    private let excludedWindowNumbers: Set<Int>
    private let excludedOwnerName: String
    private let showDebug = true

    init(onCapture: @escaping (CGRect) -> Void, onClose: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onClose = onClose
        let displayID = CGMainDisplayID()
        self.screenFrame = ScreenInfo.frame(for: displayID)
        self.displayScale = ScreenInfo.scale(for: displayID)
        self.excludedOwnerName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "Picnic"

        let window = OverlayWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.isMovable = false
        window.isReleasedWhenClosed = false

        let overlayView = WindowSelectionOverlayView(frame: CGRect(origin: .zero, size: screenFrame.size))
        overlayView.autoresizingMask = [.width, .height]
        window.contentView = overlayView

        self.window = window
        self.overlayView = overlayView
        self.excludedWindowNumbers = [window.windowNumber]
    }

    func show() {
        window.orderFrontRegardless()
        startMonitoring()
    }

    private func startMonitoring() {
        hotKeyManager.onSelectionCopy = { [weak self] in
            self?.captureSelection()
        }
        hotKeyManager.onSelectionCancel = { [weak self] in
            self?.close()
        }
        hotKeyManager.registerSelectionHotKeys()

        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updateHover()
        }
        updateHover()
    }

    private func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
        hotKeyManager.unregisterSelectionHotKeys()
        hotKeyManager.onSelectionCopy = nil
        hotKeyManager.onSelectionCancel = nil
    }

    private func updateHover() {
        let mouseLocation = NSEvent.mouseLocation
        let (nextWindow, debugText) = windowInfo(at: mouseLocation)
        if nextWindow != hoveredWindow {
            hoveredWindow = nextWindow
            if let bounds = nextWindow?.bounds {
                let highlightRect = convertToViewRect(bounds)
                overlayView.updateHighlight(highlightRect)
            } else {
                overlayView.updateHighlight(nil)
            }
        }
        if showDebug {
            overlayView.updateDebug(debugText)
        }
    }

    private func windowInfo(at point: CGPoint) -> (WindowSelectionInfo?, String) {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return (nil, "window list unavailable")
        }

        let scale = displayScale > 0 ? displayScale : 1.0
        let screenPoint = CGPoint(
            x: screenFrame.origin.x * scale + point.x * scale,
            y: screenFrame.origin.y * scale + screenFrame.height * scale - point.y * scale
        )

        var candidates: [WindowCandidate] = []
        var primary: WindowCandidate?
        var inspected = 0
        for window in windowList {
            inspected += 1
            guard let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }
            let windowID = window[kCGWindowNumber as String] as? Int ?? 0
            if excludedWindowNumbers.contains(windowID) {
                continue
            }
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? ""
            if ownerName == excludedOwnerName || ownerName == "Dock" || ownerName == "Window Server" {
                continue
            }
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 {
                continue
            }
            let alpha = window[kCGWindowAlpha as String] as? Double ?? 1.0
            if alpha <= 0.01 {
                continue
            }
            let isOnscreen = window[kCGWindowIsOnscreen as String] as? Bool ?? true
            if !isOnscreen {
                continue
            }
            let ownerNameResolved = ownerName.isEmpty ? "Unknown" : ownerName
            let windowName = window[kCGWindowName as String] as? String ?? ""
            let candidate = WindowCandidate(windowID: windowID, bounds: bounds, ownerName: ownerNameResolved, windowName: windowName)
            candidates.append(candidate)
            if primary == nil, let hit = hitTestBounds(bounds, at: screenPoint) {
                primary = WindowCandidate(windowID: windowID, bounds: hit.rect, ownerName: ownerNameResolved, windowName: windowName)
            }
        }
        guard let primary else {
            let debug = "mouse \(formatPoint(point)) | no hit (windows \(inspected)) | screen \(formatRect(screenFrame))"
            return (nil, debug)
        }
        let resolvedBounds = resolveBounds(primary: primary, from: candidates)
        let nameSuffix = primary.windowName.isEmpty ? "" : " \"\(primary.windowName)\""
        let info = WindowSelectionInfo(windowID: CGWindowID(primary.windowID), bounds: resolvedBounds)
        let debug = "mouse \(formatPoint(point)) | hit \(primary.ownerName)\(nameSuffix) id \(primary.windowID) | bounds \(formatRect(resolvedBounds))"
        return (info, debug)
    }

    private func hitTestBounds(_ bounds: CGRect, at point: CGPoint) -> (rect: CGRect, usesFlip: Bool)? {
        if bounds.contains(point) {
            return (bounds, false)
        }
        return nil
    }

    private func resolveBounds(primary: WindowCandidate, from candidates: [WindowCandidate]) -> CGRect {
        var best = primary.bounds
        for candidate in candidates {
            guard candidate.ownerName == primary.ownerName else { continue }
            guard candidate.bounds != primary.bounds else { continue }
            guard candidate.bounds.contains(best) else { continue }
            if isTitlebarContainer(container: candidate.bounds, content: best) {
                best = candidate.bounds
                break
            }
        }
        for candidate in candidates {
            guard candidate.ownerName == primary.ownerName else { continue }
            guard candidate.bounds != best else { continue }
            if isTitlebarAttachment(above: candidate.bounds, content: best) {
                best = best.union(candidate.bounds)
                break
            }
        }
        return best
    }

    private func isTitlebarContainer(container: CGRect, content: CGRect) -> Bool {
        let tolerance: CGFloat = 2
        let leftAligned = abs(container.minX - content.minX) <= tolerance
        let rightAligned = abs(container.maxX - content.maxX) <= tolerance
        let bottomAligned = abs(container.minY - content.minY) <= tolerance
        let heightDelta = container.height - content.height
        return leftAligned && rightAligned && bottomAligned && heightDelta > 6 && heightDelta < 140
    }

    private func isTitlebarAttachment(above candidate: CGRect, content: CGRect) -> Bool {
        let tolerance: CGFloat = 3
        let leftAligned = abs(candidate.minX - content.minX) <= tolerance
        let rightAligned = abs(candidate.maxX - content.maxX) <= tolerance
        let verticalJoin = abs(candidate.minY - content.maxY) <= tolerance
        let heightDelta = candidate.height
        return leftAligned && rightAligned && verticalJoin && heightDelta > 6 && heightDelta < 140
    }

    private func formatRect(_ rect: CGRect) -> String {
        let x = Int(rect.origin.x.rounded())
        let y = Int(rect.origin.y.rounded())
        let w = Int(rect.width.rounded())
        let h = Int(rect.height.rounded())
        return "\(x),\(y),\(w),\(h)"
    }

    private func formatPoint(_ point: CGPoint) -> String {
        let x = Int(point.x.rounded())
        let y = Int(point.y.rounded())
        return "\(x),\(y)"
    }

    private func convertToViewRect(_ rect: CGRect) -> CGRect {
        let scale = displayScale > 0 ? displayScale : 1.0
        let x = (rect.origin.x - screenFrame.origin.x * scale) / scale
        let y = (rect.origin.y - screenFrame.origin.y * scale) / scale
        return CGRect(x: x, y: y, width: rect.width / scale, height: rect.height / scale)
    }

    private func captureSelection() {
        guard let hoveredWindow else {
            NSSound.beep()
            return
        }
        let selectionRect = convertToViewRect(hoveredWindow.bounds)
        close()
        DispatchQueue.main.async { [onCapture] in
            onCapture(selectionRect)
        }
    }

    func close() {
        stopMonitoring()
        window.orderOut(nil)
        window.close()
        onClose()
    }
}

final class WindowSelectionOverlayView: NSView {
    private let borderLayer = CAShapeLayer()
    private let debugLabel = NSTextField(labelWithString: "")

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.strokeColor = NSColor(calibratedRed: 0.15, green: 0.82, blue: 0.72, alpha: 0.9).cgColor
        borderLayer.lineWidth = 4
        borderLayer.lineJoin = .round
        borderLayer.isHidden = true
        layer?.addSublayer(borderLayer)

        debugLabel.textColor = .white
        debugLabel.font = .systemFont(ofSize: 12, weight: .medium)
        debugLabel.drawsBackground = true
        debugLabel.backgroundColor = NSColor.black.withAlphaComponent(0.6)
        debugLabel.isBordered = false
        debugLabel.isEditable = false
        debugLabel.lineBreakMode = .byTruncatingMiddle
        debugLabel.maximumNumberOfLines = 1
        debugLabel.translatesAutoresizingMaskIntoConstraints = true
        addSubview(debugLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        borderLayer.frame = bounds
        borderLayer.contentsScale = window?.backingScaleFactor ?? 2.0
        let margin: CGFloat = 12
        let height: CGFloat = 18
        debugLabel.frame = CGRect(x: margin, y: margin, width: bounds.width - margin * 2, height: height)
    }

    func updateHighlight(_ rect: CGRect?) {
        if borderLayer.frame != bounds {
            borderLayer.frame = bounds
        }
        if let rect {
            borderLayer.isHidden = false
            borderLayer.path = CGPath(rect: rect, transform: nil)
        } else {
            borderLayer.isHidden = true
            borderLayer.path = nil
        }
    }

    func updateDebug(_ text: String) {
        debugLabel.stringValue = text
    }
}
