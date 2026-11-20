#!/usr/bin/env swift
//
//  make_icon.swift
//  Generates the YabaiBar application icon.
//
//  The icon is drawn from scratch with CoreGraphics so it stays crisp at every
//  size macOS asks for, and so the project carries no binary asset that cannot
//  be regenerated.
//
//  Usage: swift Scripts/make_icon.swift <output-icns-path>
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Geometry helpers

/// A superellipse ("squircle"), the shape Apple uses for app icons since
/// Big Sur. `n = 5` is close enough to the real thing.
func superellipsePath(
    center: CGPoint,
    size: CGSize,
    exponent n: CGFloat = 5,
    in context: CGContext
) -> CGPath {
    let a = size.width / 2
    let b = size.height / 2
    let steps = 256
    let power = 2 / n

    let path = CGMutablePath()
    for step in 0...steps {
        let t = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let cosT = cos(t)
        let sinT = sin(t)
        let x = center.x + a * copysign(pow(abs(cosT), power), cosT)
        let y = center.y + b * copysign(pow(abs(sinT), power), sinT)
        if step == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
    path.closeSubpath()
    return path
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// MARK: - Palette

private enum Palette {
    static let backgroundTop = CGColor(red: 0.13, green: 0.16, blue: 0.23, alpha: 1)
    static let backgroundBottom = CGColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1)
    static let glyphTop = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    static let glyphBottom = CGColor(red: 0.83, green: 0.87, blue: 0.94, alpha: 1)
    static let accent = CGColor(red: 0.21, green: 0.72, blue: 0.42, alpha: 1)
}

// MARK: - Drawing

/// Draws the icon into a square context of `size` pixels.
func renderIcon(size: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let side = CGFloat(size)
    // Work in a 1024 point space with Y growing downwards.
    // The three calls below compose into: reflect, then translate, then scale.
    let scale = side / 1024
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    // Apple reserves a margin around the icon body: 824 of 1024 points.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyCenter = CGPoint(x: body.midX, y: body.midY)

    // 1. Soft drop shadow under the body.
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: 18),
        blur: 46,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45)
    )
    context.setFillColor(Palette.backgroundTop)
    context.addPath(superellipsePath(center: bodyCenter, size: body.size, in: context))
    context.fillPath()
    context.restoreGState()

    // 2. Gradient body.
    context.saveGState()
    context.addPath(superellipsePath(center: bodyCenter, size: body.size, in: context))
    context.clip()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [Palette.backgroundTop, Palette.backgroundBottom] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: body.minX, y: body.minY),
        end: CGPoint(x: body.maxX, y: body.maxY),
        options: []
    )

    // 3. Gloss on the upper half, the way a physical surface catches light.
    let gloss = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.10),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gloss,
        start: CGPoint(x: body.midX, y: body.minY),
        end: CGPoint(x: body.midX, y: body.minY + body.height * 0.55),
        options: []
    )

    // 4. A faint accent glow in the lower right, so the icon is not flat.
    let glow = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 0.21, green: 0.72, blue: 0.42, alpha: 0.30),
            CGColor(red: 0.21, green: 0.72, blue: 0.42, alpha: 0.0)
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: body.maxX - 90, y: body.maxY - 90),
        startRadius: 0,
        endCenter: CGPoint(x: body.maxX - 90, y: body.maxY - 90),
        endRadius: 420,
        options: []
    )
    context.restoreGState()

    // 5. Hairline border, the way macOS icons separate from a busy wallpaper.
    context.saveGState()
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.14))
    context.setLineWidth(2)
    context.addPath(superellipsePath(center: bodyCenter, size: body.size, in: context))
    context.strokePath()
    context.restoreGState()

    // 6. The glyph: a binary space partitioning layout.
    let glyphSize = body.width * 0.56
    let glyphRect = CGRect(
        x: body.midX - glyphSize / 2,
        y: body.midY - glyphSize / 2,
        width: glyphSize,
        height: glyphSize
    )
    let gap = glyphSize * 0.075
    let leftWidth = (glyphSize - gap) * 0.44
    let rightWidth = glyphSize - gap - leftWidth
    let rightX = glyphRect.minX + leftWidth + gap
    let halfHeight = (glyphSize - gap) / 2

    let panes: [(CGRect, CGFloat)] = [
        (CGRect(x: glyphRect.minX, y: glyphRect.minY, width: leftWidth, height: glyphSize), 1.0),
        (CGRect(x: rightX, y: glyphRect.minY, width: rightWidth, height: halfHeight), 0.52),
        (CGRect(x: rightX, y: glyphRect.minY + halfHeight + gap, width: rightWidth, height: halfHeight), 0.32)
    ]

    let paneRadius = glyphSize * 0.055
    for (rect, opacity) in panes {
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: 6),
            blur: 18,
            color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
        )
        context.addPath(roundedRect(rect, radius: paneRadius))
        context.clip()

        let paneGradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                Palette.glyphTop.copy(alpha: opacity) ?? Palette.glyphTop,
                Palette.glyphBottom.copy(alpha: opacity) ?? Palette.glyphBottom
            ] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            paneGradient,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.minX, y: rect.maxY),
            options: []
        )
        context.restoreGState()
    }

    // 7. A small green status dot: yabai is running.
    let dotRadius = body.width * 0.052
    let dotCenter = CGPoint(x: body.maxX - body.width * 0.165, y: body.maxY - body.width * 0.165)
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: 3),
        blur: 12,
        color: CGColor(red: 0.05, green: 0.35, blue: 0.18, alpha: 0.8)
    )
    context.setFillColor(Palette.accent)
    context.addEllipse(in: CGRect(
        x: dotCenter.x - dotRadius,
        y: dotCenter.y - dotRadius,
        width: dotRadius * 2,
        height: dotRadius * 2
    ))
    context.fillPath()
    context.restoreGState()

    return context.makeImage()
}

// MARK: - Output

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { return }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: make_icon.swift <output-icns>\n".utf8))
    exit(1)
}

let outputPath = URL(fileURLWithPath: arguments[1])
let iconsetPath = outputPath.deletingPathExtension().appendingPathExtension("iconset")

try? FileManager.default.createDirectory(
    at: iconsetPath, withIntermediateDirectories: true
)

// The exact set macOS expects inside an .iconset.
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024)
]

for variant in variants {
    guard let image = renderIcon(size: variant.pixels) else {
        FileHandle.standardError.write(Data("failed to render \(variant.name)\n".utf8))
        exit(1)
    }
    writePNG(image, to: iconsetPath.appendingPathComponent("\(variant.name).png"))
}

print("iconset written to \(iconsetPath.path)")
