#!/usr/bin/env swift
// Finds the green pixels of the YabaiBar menu bar icon in a screenshot.
// Usage: swift Scripts/find_icon.swift <screenshot.png>

import CoreGraphics
import Foundation
import ImageIO

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    exit(1)
}

let width = image.width
let height = image.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let context = CGContext(
    data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

var minX = width, maxX = 0, minY = height, maxY = 0, count = 0
// The context is drawn with Y pointing up, so the top of the image lives in the
// last rows of the buffer.
for y in (height - 80)..<height {
    for x in 0..<width {
        let offset = (y * width + x) * 4
        let r = Int(pixels[offset]), g = Int(pixels[offset + 1]), b = Int(pixels[offset + 2])
        // The running-state green of the menu bar glyph.
        if g > 150 && r < 120 && b < 120 && g - r > 70 && g - b > 70 {
            count += 1
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
}

print("image \(width)x\(height)")
print("green pixels: \(count)")
if count > 0 {
    print("bbox: x \(minX)...\(maxX)  y \(minY)...\(maxY)")
    print("center: x=\((minX + maxX) / 2) y=\((minY + maxY) / 2)")
}
