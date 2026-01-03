import AppKit
import CoreGraphics

enum ImageComposer {
    static func render(
        image: NSImage,
        cropRect: CGRect?,
        arrows: [ArrowAnnotation],
        texts: [TextAnnotation]
    ) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let fullSize = image.size
        let outputRect = cropRect ?? CGRect(origin: .zero, size: fullSize)
        let outputSize = outputRect.size
        let flippedOutputRect = flipRect(outputRect, height: fullSize.height)

        let pixelWidth = Int(outputSize.width * scale)
        let pixelHeight = Int(outputSize.height * scale)
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -flippedOutputRect.origin.x, y: -flippedOutputRect.origin.y)

        context.draw(cgImage, in: CGRect(origin: .zero, size: fullSize))

        context.setLineWidth(4)
        context.setStrokeColor(NSColor.systemRed.cgColor)
        context.setLineCap(.round)

        for arrow in arrows.map({ flipArrow($0, height: fullSize.height) }) {
            drawArrow(context: context, start: arrow.start, end: arrow.end)
        }

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        let font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        let baselineOffset = font.ascender
        for text in texts {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.black.withAlphaComponent(0.35)
            ]
            let attributed = NSAttributedString(string: text.text, attributes: attributes)
            let flippedPoint = flipPoint(text.point, height: fullSize.height)
            let drawPoint = CGPoint(x: flippedPoint.x, y: flippedPoint.y - baselineOffset)
            attributed.draw(at: drawPoint)
        }

        NSGraphicsContext.restoreGraphicsState()

        guard let outputImage = context.makeImage() else { return nil }
        return NSImage(cgImage: outputImage, size: outputSize)
    }

    private static func drawArrow(context: CGContext, start: CGPoint, end: CGPoint) {
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength: CGFloat = 14
        let headAngle: CGFloat = .pi / 6

        let point1 = CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        )
        let point2 = CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        )

        context.beginPath()
        context.move(to: end)
        context.addLine(to: point1)
        context.move(to: end)
        context.addLine(to: point2)
        context.strokePath()
    }

    private static func flipPoint(_ point: CGPoint, height: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: height - point.y)
    }

    private static func flipRect(_ rect: CGRect, height: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    private static func flipArrow(_ arrow: ArrowAnnotation, height: CGFloat) -> ArrowAnnotation {
        ArrowAnnotation(
            start: flipPoint(arrow.start, height: height),
            end: flipPoint(arrow.end, height: height)
        )
    }
}
