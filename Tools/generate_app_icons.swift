#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

private struct IconPalette {
    let background: CGColor
    let mark: CGColor
}

private let canvasSize = 1_024
private let outputDirectory = URL(
    fileURLWithPath: FileManager.default.currentDirectoryPath
)
.appendingPathComponent(
    "CubeCoachApp/Resources/Assets.xcassets/AppIcon.appiconset",
    isDirectory: true
)

private let standardPalette = IconPalette(
    background: color("#075E79"),
    mark: color("#FFFDF8")
)

private let darkPalette = IconPalette(
    background: color("#071E22"),
    mark: color("#F1E6D2")
)

private let tintedPalette = IconPalette(
    background: color("#171821"),
    mark: color("#FFFFFF")
)

try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

try renderIcon(
    palette: standardPalette,
    to: outputDirectory.appendingPathComponent("AppIcon.png")
)
try renderIcon(
    palette: darkPalette,
    to: outputDirectory.appendingPathComponent("AppIcon-Dark.png")
)
try renderIcon(
    palette: tintedPalette,
    to: outputDirectory.appendingPathComponent("AppIcon-Tinted.png")
)

print("Generated CubeCoach app icons in \(outputDirectory.path)")

private func renderIcon(palette: IconPalette, to outputURL: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: canvasSize,
        pixelsHigh: canvasSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconGenerationError.bitmapCreationFailed
    }

    bitmap.size = NSSize(width: canvasSize, height: canvasSize)
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw IconGenerationError.contextCreationFailed
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    let context = graphicsContext.cgContext
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.translateBy(x: 0, y: CGFloat(canvasSize))
    context.scaleBy(x: 1, y: -1)

    context.setFillColor(palette.background)
    context.fill(
        CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
    )

    let top = CGPoint(x: 512, y: 202)
    let upperRight = CGPoint(x: 790, y: 362)
    let lowerRight = CGPoint(x: 790, y: 674)
    let bottom = CGPoint(x: 512, y: 834)
    let lowerLeft = CGPoint(x: 234, y: 674)
    let upperLeft = CGPoint(x: 234, y: 362)
    let center = CGPoint(x: 512, y: 522)

    // One continuous outline plus three internal edges is enough to identify
    // a cube at notification size. No face colors or solve-state symbols.
    strokePolyline(
        [top, upperRight, lowerRight, bottom, lowerLeft, upperLeft, top],
        color: palette.mark,
        width: 58,
        in: context
    )
    for edge in [
        [upperLeft, center],
        [upperRight, center],
        [center, bottom],
    ] {
        strokePolyline(
            edge,
            color: palette.mark,
            width: 58,
            in: context
        )
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.pngEncodingFailed
    }
    try png.write(to: outputURL, options: .atomic)
}

private func strokePolyline(
    _ points: [CGPoint],
    color: CGColor,
    width: CGFloat,
    in context: CGContext
) {
    guard let first = points.first else { return }
    let path = CGMutablePath()
    path.move(to: first)
    for point in points.dropFirst() {
        path.addLine(to: point)
    }
    context.addPath(path)
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()
}

private func color(_ hex: String) -> CGColor {
    let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    precondition(value.count == 6)
    let red = CGFloat(Int(value.prefix(2), radix: 16)!) / 255
    let green = CGFloat(Int(value.dropFirst(2).prefix(2), radix: 16)!) / 255
    let blue = CGFloat(Int(value.dropFirst(4).prefix(2), radix: 16)!) / 255
    return CGColor(
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        components: [red, green, blue, 1]
    )!
}

private enum IconGenerationError: Error {
    case bitmapCreationFailed
    case contextCreationFailed
    case pngEncodingFailed
}
