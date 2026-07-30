#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

private struct IconPalette {
    let background: CGColor
    let lattice: CGColor
    let top: CGColor
    let left: CGColor
    let right: CGColor
    let focus: CGColor
}

private struct Face {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint
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
    background: color("#201A63"),
    lattice: color("#FFF8EA"),
    top: color("#F7F5EE"),
    left: color("#27B477"),
    right: color("#F05A67"),
    focus: color("#55D7F2")
)

private let darkPalette = IconPalette(
    background: color("#090A22"),
    lattice: color("#F3F0FF"),
    top: color("#D7D2FF"),
    left: color("#6758DD"),
    right: color("#45BED5"),
    focus: color("#A99CFF")
)

private let tintedPalette = IconPalette(
    background: color("#171821"),
    lattice: color("#F5F5FA"),
    top: color("#E7E7EE"),
    left: color("#BFC0CB"),
    right: color("#D2D3DC"),
    focus: color("#FFFFFF")
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

    let top = Face(
        topLeft: CGPoint(x: 512, y: 142),
        topRight: CGPoint(x: 828, y: 324),
        bottomRight: CGPoint(x: 512, y: 506),
        bottomLeft: CGPoint(x: 196, y: 324)
    )
    let left = Face(
        topLeft: top.bottomLeft,
        topRight: top.bottomRight,
        bottomRight: CGPoint(x: 512, y: 878),
        bottomLeft: CGPoint(x: 196, y: 696)
    )
    let right = Face(
        topLeft: top.bottomRight,
        topRight: top.topRight,
        bottomRight: CGPoint(x: 828, y: 696),
        bottomLeft: CGPoint(x: 512, y: 878)
    )

    for face in [top, left, right] {
        fillPolygon(face.points, color: palette.lattice, in: context)
    }

    drawFace(top, cellColor: palette.top, in: context)
    drawFace(left, cellColor: palette.left, in: context)
    drawFace(right, cellColor: palette.right, in: context)

    // The outlined outer layer represents a turn target. It communicates
    // deliberate practice without the auto-solve arrows/checkmarks used by
    // generic cube utilities.
    for row in 0 ..< 3 {
        let focusedSticker = inset(
            cell(on: right, row: row, column: 2),
            scale: 0.70
        )
        strokePolygon(
            focusedSticker,
            color: palette.focus,
            width: 14,
            in: context
        )
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.pngEncodingFailed
    }
    try png.write(to: outputURL, options: .atomic)
}

private func drawFace(
    _ face: Face,
    cellColor: CGColor,
    in context: CGContext
) {
    for row in 0 ..< 3 {
        for column in 0 ..< 3 {
            let sticker = inset(
                cell(on: face, row: row, column: column),
                scale: 0.84
            )
            fillPolygon(sticker, color: cellColor, in: context)
        }
    }
}

private func cell(
    on face: Face,
    row: Int,
    column: Int
) -> [CGPoint] {
    let rowStart = CGFloat(row) / 3
    let rowEnd = CGFloat(row + 1) / 3
    let columnStart = CGFloat(column) / 3
    let columnEnd = CGFloat(column + 1) / 3

    return [
        interpolate(face: face, row: rowStart, column: columnStart),
        interpolate(face: face, row: rowStart, column: columnEnd),
        interpolate(face: face, row: rowEnd, column: columnEnd),
        interpolate(face: face, row: rowEnd, column: columnStart),
    ]
}

private func interpolate(
    face: Face,
    row: CGFloat,
    column: CGFloat
) -> CGPoint {
    let top = lerp(face.topLeft, face.topRight, amount: column)
    let bottom = lerp(face.bottomLeft, face.bottomRight, amount: column)
    return lerp(top, bottom, amount: row)
}

private func lerp(
    _ start: CGPoint,
    _ end: CGPoint,
    amount: CGFloat
) -> CGPoint {
    CGPoint(
        x: start.x + (end.x - start.x) * amount,
        y: start.y + (end.y - start.y) * amount
    )
}

private func inset(
    _ points: [CGPoint],
    scale: CGFloat
) -> [CGPoint] {
    let center = points.reduce(CGPoint.zero) {
        CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
    }
    let centroid = CGPoint(
        x: center.x / CGFloat(points.count),
        y: center.y / CGFloat(points.count)
    )

    return points.map {
        CGPoint(
            x: centroid.x + ($0.x - centroid.x) * scale,
            y: centroid.y + ($0.y - centroid.y) * scale
        )
    }
}

private func fillPolygon(
    _ points: [CGPoint],
    color: CGColor,
    in context: CGContext
) {
    guard let first = points.first else { return }
    let path = CGMutablePath()
    path.move(to: first)
    for point in points.dropFirst() {
        path.addLine(to: point)
    }
    path.closeSubpath()
    context.addPath(path)
    context.setFillColor(color)
    context.fillPath()
}

private func strokePolygon(
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
    path.closeSubpath()
    context.addPath(path)
    context.setStrokeColor(color)
    context.setLineWidth(width)
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

private extension Face {
    var points: [CGPoint] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }
}

private enum IconGenerationError: Error {
    case bitmapCreationFailed
    case contextCreationFailed
    case pngEncodingFailed
}
