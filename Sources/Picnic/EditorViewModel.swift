import AppKit
import CoreGraphics
import SwiftUI

final class EditorViewModel: ObservableObject {
    enum Tool {
        case select
        case crop
        case arrow
        case text
    }

    private struct WindowCandidate {
        let bounds: CGRect
        let ownerName: String
    }

    @Published var tool: Tool = .select {
        didSet {
            if tool != .select {
                clearHoveredWindow()
            }
        }
    }
    @Published var cropRect: CGRect?
    @Published var arrows: [ArrowAnnotation] = []
    @Published var texts: [TextAnnotation] = []
    @Published var editingTextID: UUID?
    @Published var currentArrow: ArrowAnnotation?
    @Published var selectedTextID: UUID?
    @Published var selectedArrowID: UUID?
    @Published var lastCursorPoint: CGPoint?
    @Published var hoveredWindowRect: CGRect?

    let image: NSImage
    private var viewSize: CGSize = .zero
    private var dragStart: CGPoint?
    private var movingTextID: UUID?
    private var movingArrowIndex: Int?
    private var movingTextOrigin: CGPoint = .zero
    private var movingArrowStart: CGPoint = .zero
    private var movingArrowEnd: CGPoint = .zero

    private static let textFont = NSFont.systemFont(ofSize: 20, weight: .semibold)
    private let screenFrame: CGRect
    private let displayScale: CGFloat
    private let excludedOwnerName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "Picnic"

    init(image: NSImage, screenFrame: CGRect, displayScale: CGFloat) {
        self.image = image
        self.screenFrame = screenFrame
        self.displayScale = displayScale
    }

    func beginDrag(at point: CGPoint) {
        dragStart = point
        if tool != .text {
            editingTextID = nil
        }
        switch tool {
        case .select:
            updateHoveredWindow(at: point)
            beginSelection(at: point)
        case .crop:
            cropRect = CGRect(origin: point, size: .zero)
        case .arrow:
            currentArrow = ArrowAnnotation(start: point, end: point)
        case .text:
            break
        }
    }

    func updateDrag(from start: CGPoint, to current: CGPoint) {
        switch tool {
        case .select:
            updateSelectionDrag(to: current)
        case .crop:
            cropRect = rect(from: start, to: current)
        case .arrow:
            currentArrow?.end = current
        case .text:
            break
        }
    }

    func endDrag(from start: CGPoint, to end: CGPoint, isClick: Bool) {
        switch tool {
        case .select:
            endSelectionDrag(isClick: isClick)
        case .crop:
            let rect = rect(from: start, to: end)
            if rect.width < 4 || rect.height < 4 {
                cropRect = nil
            } else {
                cropRect = rect
            }
        case .arrow:
            if let arrow = currentArrow {
                if distance(from: arrow.start, to: arrow.end) > 4 {
                    arrows.append(arrow)
                }
            }
            currentArrow = nil
        case .text:
            if isClick {
                if editingTextID != nil {
                    endTextEditing(switchToSelect: true)
                } else {
                    addText(at: end)
                }
            }
        }
        dragStart = nil
    }

    func selectTool(_ tool: Tool) {
        if tool == .text {
            startTextEntry()
        } else {
            if tool == .select {
                cropRect = nil
            }
            self.tool = tool
            editingTextID = nil
        }
    }

    func startTextEntry() {
        tool = .text
        if editingTextID != nil {
            return
        }
        let point = lastCursorPoint ?? defaultTextPoint()
        addText(at: point)
    }

    func addText(at point: CGPoint) {
        let annotation = TextAnnotation(point: point, text: "")
        texts.append(annotation)
        editingTextID = annotation.id
        selectedTextID = annotation.id
        selectedArrowID = nil
        DispatchQueue.main.async { [weak self] in
            self?.editingTextID = annotation.id
        }
    }

    func updateText(id: UUID, text: String) {
        guard let index = texts.firstIndex(where: { $0.id == id }) else { return }
        texts[index].text = text
    }

    func endTextEditing(switchToSelect: Bool) {
        editingTextID = nil
        if switchToSelect && tool == .text {
            tool = .select
        }
    }

    func renderFinalImage(cropOverride: CGRect? = nil) -> NSImage? {
        let safeCrop = clampedCropRect(cropOverride)
        let scale = scaleFactors()
        let scaledCrop = safeCrop.map { scaleRect($0, scale: scale) }
        let scaledArrows = arrows.map { scaleArrow($0, scale: scale) }
        let scaledTexts = texts.map { scaleText($0, scale: scale) }
        let scaledCurrentArrow = currentArrow.map { scaleArrow($0, scale: scale) }
        return ImageComposer.render(
            image: image,
            cropRect: scaledCrop,
            arrows: scaledArrows + (scaledCurrentArrow.map { [$0] } ?? []),
            texts: scaledTexts
        )
    }

    func updateViewSize(_ size: CGSize) {
        if size != .zero {
            viewSize = size
        }
    }

    private func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func clampedCropRect(_ override: CGRect? = nil) -> CGRect? {
        guard let cropRect = override ?? cropRect else { return nil }
        let bounds = CGRect(origin: .zero, size: image.size)
        return cropRect.intersection(bounds)
    }

    private func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }

    private func scaleFactors() -> CGSize {
        guard viewSize.width > 0, viewSize.height > 0 else {
            return CGSize(width: 1, height: 1)
        }
        return CGSize(
            width: image.size.width / viewSize.width,
            height: image.size.height / viewSize.height
        )
    }

    private func scalePoint(_ point: CGPoint, scale: CGSize) -> CGPoint {
        CGPoint(x: point.x * scale.width, y: point.y * scale.height)
    }

    private func scaleRect(_ rect: CGRect, scale: CGSize) -> CGRect {
        CGRect(
            x: rect.origin.x * scale.width,
            y: rect.origin.y * scale.height,
            width: rect.size.width * scale.width,
            height: rect.size.height * scale.height
        )
    }

    private func scaleArrow(_ arrow: ArrowAnnotation, scale: CGSize) -> ArrowAnnotation {
        ArrowAnnotation(
            start: scalePoint(arrow.start, scale: scale),
            end: scalePoint(arrow.end, scale: scale)
        )
    }

    private func scaleText(_ text: TextAnnotation, scale: CGSize) -> TextAnnotation {
        TextAnnotation(point: scalePoint(text.point, scale: scale), text: text.text)
    }

    private func defaultTextPoint() -> CGPoint {
        let size = viewSize == .zero ? image.size : viewSize
        return CGPoint(x: size.width * 0.5, y: size.height * 0.5)
    }

    func updateCursorPoint(_ point: CGPoint) {
        lastCursorPoint = point
    }

    func updateHoveredWindow(at point: CGPoint) {
        guard tool == .select else {
            clearHoveredWindow()
            return
        }
        if point.y <= 2, viewSize != .zero {
            let fullRect = CGRect(origin: .zero, size: viewSize)
            if hoveredWindowRect != fullRect {
                hoveredWindowRect = fullRect
            }
            return
        }
        let nextRect = windowRect(at: point)
        if hoveredWindowRect != nextRect {
            hoveredWindowRect = nextRect
        }
    }

    func clearHoveredWindow() {
        if hoveredWindowRect != nil {
            hoveredWindowRect = nil
        }
    }

    private func windowRect(at point: CGPoint) -> CGRect? {
        guard screenFrame != .zero else { return nil }
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let scale = displayScale > 0 ? displayScale : 1.0
        let screenPoint = CGPoint(
            x: screenFrame.origin.x * scale + point.x * scale,
            y: screenFrame.origin.y * scale + point.y * scale
        )

        var candidates: [WindowCandidate] = []
        var primary: WindowCandidate?
        for window in windowList {
            guard let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
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
            let candidate = WindowCandidate(bounds: bounds, ownerName: ownerName)
            candidates.append(candidate)
            if primary == nil, let hitBounds = hitTestBounds(bounds, at: screenPoint) {
                primary = WindowCandidate(bounds: hitBounds, ownerName: ownerName)
            }
        }
        guard let primary else { return nil }
        let resolvedBounds = resolveBounds(primary: primary, from: candidates)
        return convertToViewRect(resolvedBounds)
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

    private func hitTestBounds(_ bounds: CGRect, at point: CGPoint) -> CGRect? {
        if bounds.contains(point) {
            return bounds
        }
        return nil
    }

    private func convertToViewRect(_ rect: CGRect) -> CGRect {
        let scale = displayScale > 0 ? displayScale : 1.0
        let x = (rect.origin.x - screenFrame.origin.x * scale) / scale
        let y = (rect.origin.y - screenFrame.origin.y * scale) / scale
        return CGRect(x: x, y: y, width: rect.width / scale, height: rect.height / scale)
    }

    private func beginSelection(at point: CGPoint) {
        if let textIndex = hitTestText(at: point) {
            let text = texts[textIndex]
            movingTextID = text.id
            movingTextOrigin = text.point
            selectedTextID = text.id
            selectedArrowID = nil
            return
        }
        if let arrowIndex = hitTestArrow(at: point) {
            let arrow = arrows[arrowIndex]
            movingArrowIndex = arrowIndex
            movingArrowStart = arrow.start
            movingArrowEnd = arrow.end
            selectedArrowID = arrow.id
            selectedTextID = nil
            return
        }
        selectedTextID = nil
        selectedArrowID = nil
    }

    private func updateSelectionDrag(to current: CGPoint) {
        guard let start = dragStart else { return }
        let delta = CGPoint(x: current.x - start.x, y: current.y - start.y)
        if let movingTextID, let index = texts.firstIndex(where: { $0.id == movingTextID }) {
            texts[index].point = CGPoint(x: movingTextOrigin.x + delta.x, y: movingTextOrigin.y + delta.y)
        } else if let movingArrowIndex, arrows.indices.contains(movingArrowIndex) {
            arrows[movingArrowIndex].start = CGPoint(x: movingArrowStart.x + delta.x, y: movingArrowStart.y + delta.y)
            arrows[movingArrowIndex].end = CGPoint(x: movingArrowEnd.x + delta.x, y: movingArrowEnd.y + delta.y)
        }
    }

    private func endSelectionDrag(isClick: Bool) {
        if isClick, selectedTextID == nil, selectedArrowID == nil {
            if cropRect == nil, let hoveredWindowRect {
                cropRect = hoveredWindowRect
            }
            endTextEditing(switchToSelect: true)
        }
        movingTextID = nil
        movingArrowIndex = nil
    }

    private func hitTestText(at point: CGPoint) -> Int? {
        for (index, text) in texts.enumerated().reversed() {
            if textBounds(for: text).contains(point) {
                return index
            }
        }
        return nil
    }

    private func textBounds(for text: TextAnnotation) -> CGRect {
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.textFont]
        let size = (text.text as NSString).size(withAttributes: attributes)
        let padding = CGSize(width: 12, height: 8)
        return CGRect(
            x: text.point.x,
            y: text.point.y,
            width: size.width + padding.width,
            height: size.height + padding.height
        )
    }

    private func hitTestArrow(at point: CGPoint) -> Int? {
        let threshold: CGFloat = 12
        for (index, arrow) in arrows.enumerated().reversed() {
            if distanceFromPoint(point, toSegmentStart: arrow.start, end: arrow.end) <= threshold {
                return index
            }
        }
        return nil
    }

    private func distanceFromPoint(_ point: CGPoint, toSegmentStart start: CGPoint, end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        if dx == 0 && dy == 0 {
            return distance(from: point, to: start)
        }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return distance(from: point, to: projection)
    }
}

struct ArrowAnnotation: Identifiable {
    let id = UUID()
    var start: CGPoint
    var end: CGPoint
}

struct TextAnnotation: Identifiable {
    let id = UUID()
    var point: CGPoint
    var text: String
}
