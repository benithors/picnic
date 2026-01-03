import AppKit
import Foundation

enum OutputManager {
    static let folderName = "Picnic"

    static func savePNG(_ image: NSImage) throws -> URL {
        let folderURL = try outputDirectory()
        let fileURL = uniqueFileURL(in: folderURL)

        guard let data = pngData(from: image) else {
            throw OutputError.encodeFailed
        }
        try data.write(to: fileURL)
        return fileURL
    }

    static func copyToPasteboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    private static func outputDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first ??
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        let folder = base.appendingPathComponent(folderName)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private static func uniqueFileURL(in folder: URL) -> URL {
        let baseName = "Picnic-" + timestampString()
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension("png")
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName)-\(counter)").appendingPathExtension("png")
            counter += 1
        }
        return candidate
    }

    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH.mm.ss"
        return formatter.string(from: Date())
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    enum OutputError: Error {
        case encodeFailed
    }
}
