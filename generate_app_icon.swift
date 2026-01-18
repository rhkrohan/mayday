#!/usr/bin/env swift

import AppKit
import Foundation

// App icon generator for Pigeon
// Run with: swift generate_app_icon.swift

let outputDir = "CapsuleMesh/Assets.xcassets/AppIcon.appiconset"

// Icon sizes needed for iOS (actual pixel dimensions)
let iconSizes: [(name: String, size: Int)] = [
    ("icon-20", 20),
    ("icon-20@2x", 40),
    ("icon-20@3x", 60),
    ("icon-20@2x-ipad", 40),
    ("icon-29", 29),
    ("icon-29@2x", 58),
    ("icon-29@3x", 87),
    ("icon-29@2x-ipad", 58),
    ("icon-40", 40),
    ("icon-40@2x", 80),
    ("icon-40@3x", 120),
    ("icon-40@2x-ipad", 80),
    ("icon-60@2x", 120),
    ("icon-60@3x", 180),
    ("icon-76", 76),
    ("icon-76@2x", 152),
    ("icon-83.5@2x", 167),
    ("icon-1024", 1024)
]

func generateIcon(size: Int) -> NSBitmapImageRep? {
    // Create bitmap with explicit pixel dimensions (no scaling)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }

    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        NSGraphicsContext.restoreGraphicsState()
        return nil
    }
    NSGraphicsContext.current = context

    // Black background
    NSColor.black.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

    // Draw bird symbol
    if let birdSymbol = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: nil) {
        // Calculate symbol size - about 50% of icon size
        let symbolPointSize = CGFloat(size) * 0.5
        let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .medium)

        if let configuredBird = birdSymbol.withSymbolConfiguration(config) {
            // Create a new image with the bird tinted white
            let birdSize = configuredBird.size
            let tintedBird = NSImage(size: birdSize)

            tintedBird.lockFocus()
            NSColor.white.set()
            let imageRect = NSRect(origin: .zero, size: birdSize)
            configuredBird.draw(in: imageRect)
            imageRect.fill(using: .sourceAtop)
            tintedBird.unlockFocus()

            // Center the bird in the icon
            let x = (CGFloat(size) - birdSize.width) / 2
            let y = (CGFloat(size) - birdSize.height) / 2

            tintedBird.draw(
                in: NSRect(x: x, y: y, width: birdSize.width, height: birdSize.height),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
        }
    }

    NSGraphicsContext.restoreGraphicsState()

    return bitmap
}

func saveBitmap(_ bitmap: NSBitmapImageRep, to path: String) -> Bool {
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return false
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        return true
    } catch {
        print("Error saving \(path): \(error)")
        return false
    }
}

print("Generating Pigeon app icons (white bird on black background)...")

for (name, size) in iconSizes {
    if let bitmap = generateIcon(size: size) {
        let path = "\(outputDir)/\(name).png"
        if saveBitmap(bitmap, to: path) {
            print("✓ Generated \(name).png (\(size)x\(size))")
        } else {
            print("✗ Failed to save \(name).png")
        }
    } else {
        print("✗ Failed to generate \(name).png")
    }
}

print("\nDone! App icons have been generated in \(outputDir)")
