#!/usr/bin/env swift
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let iconsetPath = "/tmp/MacOSLocalMCPServer.iconset"

try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for size in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let scale = CGFloat(size) / 1024.0

    // Background rounded rect
    let cornerRadius = CGFloat(size) * 0.22
    let bgRect = CGRect(x: 0, y: 0, width: size, height: size)
        .insetBy(dx: CGFloat(size) * 0.02, dy: CGFloat(size) * 0.02)
    let path = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)

    let bgColor1 = NSColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)
    let bgColor2 = NSColor(red: 0.09, green: 0.13, blue: 0.24, alpha: 1.0)
    let gradient = NSGradient(starting: bgColor1, ending: bgColor2)!
    gradient.draw(in: path, angle: -45)

    let glowColor = NSColor(red: 0.4, green: 0.5, blue: 0.9, alpha: 0.15)
    glowColor.setFill()
    path.fill()

    // Apple shape
    let appleScale = scale * 2.5
    let centerX = CGFloat(size) / 2.0
    let centerY = CGFloat(size) * 0.40

    ctx.saveGState()
    ctx.translateBy(x: centerX, y: centerY)
    ctx.scaleBy(x: appleScale, y: appleScale)

    let applePath = NSBezierPath()
    applePath.move(to: NSPoint(x: -40, y: 60))
    applePath.curve(to: NSPoint(x: 10, y: 80), controlPoint1: NSPoint(x: -15, y: 80), controlPoint2: NSPoint(x: 10, y: 80))
    applePath.curve(to: NSPoint(x: 55, y: 40), controlPoint1: NSPoint(x: 35, y: 80), controlPoint2: NSPoint(x: 55, y: 65))
    applePath.curve(to: NSPoint(x: 10, y: -65), controlPoint1: NSPoint(x: 55, y: 10), controlPoint2: NSPoint(x: 35, y: -30))
    applePath.curve(to: NSPoint(x: -35, y: -65), controlPoint1: NSPoint(x: -5, y: -50), controlPoint2: NSPoint(x: -20, y: -65))
    applePath.curve(to: NSPoint(x: -80, y: 40), controlPoint1: NSPoint(x: -60, y: -30), controlPoint2: NSPoint(x: -80, y: 10))
    applePath.curve(to: NSPoint(x: -40, y: 60), controlPoint1: NSPoint(x: -80, y: 65), controlPoint2: NSPoint(x: -60, y: 60))
    applePath.close()

    NSColor(red: 0.31, green: 0.67, blue: 1.0, alpha: 0.9).setFill()
    applePath.fill()

    let leafPath = NSBezierPath()
    leafPath.move(to: NSPoint(x: 10, y: 80))
    leafPath.curve(to: NSPoint(x: 45, y: 100), controlPoint1: NSPoint(x: 25, y: 105), controlPoint2: NSPoint(x: 45, y: 100))
    leafPath.curve(to: NSPoint(x: 10, y: 80), controlPoint1: NSPoint(x: 35, y: 85), controlPoint2: NSPoint(x: 20, y: 80))
    leafPath.close()
    NSColor(red: 0.0, green: 0.85, blue: 0.85, alpha: 0.8).setFill()
    leafPath.fill()

    ctx.restoreGState()

    // MCP text
    let fontSize = CGFloat(size) * 0.14
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let textAttributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .kern: CGFloat(size) * 0.015
    ]
    let text = "MCP" as NSString
    let textSize = text.size(withAttributes: textAttributes)
    let textX = (CGFloat(size) - textSize.width) / 2.0
    let textY = CGFloat(size) * 0.18
    text.draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttributes)

    image.unlockFocus()

    if let tiffData = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        let filepath = "\(iconsetPath)/icon_\(size)x\(size).png"
        try? pngData.write(to: URL(fileURLWithPath: filepath))
        if size <= 512, [16, 32, 64, 128, 256, 512].contains(size / 2) {
            let filepath2x = "\(iconsetPath)/icon_\(size/2)x\(size/2)@2x.png"
            try? pngData.write(to: URL(fileURLWithPath: filepath2x))
        }
    }
}

// Copy 1024 as 512@2x
let src = "\(iconsetPath)/icon_1024x1024.png"
let dst = "\(iconsetPath)/icon_512x512@2x.png"
try? FileManager.default.copyItem(atPath: src, toPath: dst)

// Convert to .icns
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetPath, "-o", "/tmp/MacOSLocalMCPServer.icns"]
try? task.run()
task.waitUntilExit()

print("Icon generated at /tmp/MacOSLocalMCPServer.icns")
