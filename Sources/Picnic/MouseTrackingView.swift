import AppKit
import SwiftUI

struct MouseTrackingView: NSViewRepresentable {
    let tool: EditorViewModel.Tool
    let onMove: (CGPoint) -> Void

    func makeNSView(context: Context) -> TrackingView {
        TrackingView(tool: tool, onMove: onMove)
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onMove = onMove
        nsView.tool = tool
    }
}

final class TrackingView: NSView {
    var tool: EditorViewModel.Tool {
        didSet {
            if oldValue != tool {
                updateCursor()
            }
        }
    }
    var onMove: (CGPoint) -> Void
    private var trackingArea: NSTrackingArea?

    init(tool: EditorViewModel.Tool, onMove: @escaping (CGPoint) -> Void) {
        self.tool = tool
        self.onMove = onMove
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onMove(point)
        updateCursor()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func updateCursor() {
        if tool == .crop {
            NSCursor.crosshair.set()
        } else {
            NSCursor.arrow.set()
        }
    }
}
