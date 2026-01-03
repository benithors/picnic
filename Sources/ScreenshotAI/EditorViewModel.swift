import AppKit
import SwiftUI

final class EditorViewModel: ObservableObject {
    enum Tool {
        case select
        case crop
        case arrow
        case text
    }

    @Published var tool: Tool = .crop
    @Published var cropRect: CGRect?
    @Published var arrows: [ArrowAnnotation] = []
    @Published var texts: [TextAnnotation] = []
    @Published var editingTextID: UUID?
    @Published var currentArrow: ArrowAnnotation?
    @Published var selectedTextID: UUID?
    @Published var selectedArrowID: UUID?
    @Published var lastCursorPoint: CGPoint?

    let image: NSImage
    private var viewSize: CGSize = .zero
    private var dragStart: CGPoint?
    private var movingTextID: UUID?
    private var movingArrowIndex: Int?
    private var movingTextOrigin: CGPoint = .zero
    private var movingArrowStart: CGPoint = .zero
    private var movingArrowEnd: CGPoint = .zero

    private static let textFont = NSFont.systemFont(ofSize: 20, weight: .semibold)

    init(image: NSImage) {
        self.image = image
    }

    func beginDrag(at point: CGPoint) {
        dragStart = point
        if tool != .text {
            editingTextID = nil
        }
        switch tool {
        case .select:
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

    func renderFinalImage() -> NSImage? {
        let safeCrop = clampedCropRect()
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

    private func clampedCropRect() -> CGRect? {
        guard let cropRect else { return nil }
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
