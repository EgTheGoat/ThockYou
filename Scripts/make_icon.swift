import AppKit
import CoreText
import Foundation

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make_icon <output.png>\n".utf8))
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let size: CGFloat = 1024
let emoji = "🖕"

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    FileHandle.standardError.write(Data("failed to create bitmap context\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let inset: CGFloat = size * (100.0 / 1024.0)
let iconRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let cornerRadius = iconRect.width * 0.2237
let roundedRect = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

NSColor.black.setFill()
roundedRect.fill()

roundedRect.addClip()

let font = NSFont(name: "Apple Color Emoji", size: size * 0.62) ?? NSFont.systemFont(ofSize: size * 0.62)
let attributes: [NSAttributedString.Key: Any] = [.font: font]
let attributed = NSAttributedString(string: emoji, attributes: attributes)

let line = CTLineCreateWithAttributedString(attributed)
let visualBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

let cg = context.cgContext
cg.textMatrix = .identity
let originX = (size - visualBounds.width) / 2 - visualBounds.minX
let originY = (size - visualBounds.height) / 2 - visualBounds.minY
cg.textPosition = CGPoint(x: originX, y: originY)
CTLineDraw(line, cg)

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to encode png\n".utf8))
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
