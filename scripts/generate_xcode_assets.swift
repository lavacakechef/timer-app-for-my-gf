#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsRoot = root.appendingPathComponent("XcodeSupport/CozyTime/Assets.xcassets")

func ensureDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

extension NSColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

func writePNG(size: Int, to url: URL, draw: (CGFloat) -> Void) throws {
    let rep = NSBitmapImageRep(
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
    )!
    rep.size = NSSize(width: size, height: size)
    let context = NSGraphicsContext(bitmapImageRep: rep)!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    draw(CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url, options: [.atomic])
}

func drawClockBadge(size: CGFloat, accent: NSColor) {
    let badgeRect = NSRect(x: size * 0.60, y: size * 0.61, width: size * 0.25, height: size * 0.25)
    drawClockBadge(size: size, accent: accent, badgeRect: badgeRect)
}

func drawClockBadge(size: CGFloat, accent: NSColor, badgeRect: NSRect) {
    NSColor.white.withAlphaComponent(0.94).setFill()
    NSBezierPath(ovalIn: badgeRect).fill()
    accent.setStroke()
    let ring = NSBezierPath(ovalIn: badgeRect.insetBy(dx: size * 0.025, dy: size * 0.025))
    ring.lineWidth = size * 0.022
    ring.stroke()

    let center = NSPoint(x: badgeRect.midX, y: badgeRect.midY)
    let hand = NSBezierPath()
    hand.move(to: center)
    hand.line(to: NSPoint(x: center.x, y: center.y + size * 0.065))
    hand.line(to: NSPoint(x: center.x + size * 0.052, y: center.y + size * 0.018))
    hand.lineCapStyle = .round
    hand.lineWidth = size * 0.018
    hand.stroke()
}

func drawStar(center: NSPoint, outerRadius: CGFloat, innerRadius: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    for index in 0..<10 {
        let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
        let angle = CGFloat(index) * .pi / 5 + .pi / 2
        let point = NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        index == 0 ? path.move(to: point) : path.line(to: point)
    }
    path.close()
    color.setFill()
    path.fill()
}

func drawCuteStarBuddy(center: NSPoint, outerRadius: CGFloat, color: NSColor, faceColor: NSColor = NSColor(hex: "#2B2420")) {
    NSColor.black.withAlphaComponent(0.12).setFill()
    let shadow = NSBezierPath(ovalIn: NSRect(
        x: center.x - outerRadius * 0.75,
        y: center.y - outerRadius * 0.88,
        width: outerRadius * 1.5,
        height: outerRadius * 0.42
    ))
    shadow.fill()

    drawStar(
        center: center,
        outerRadius: outerRadius,
        innerRadius: outerRadius * 0.46,
        color: color
    )

    faceColor.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - outerRadius * 0.26, y: center.y - outerRadius * 0.04, width: outerRadius * 0.10, height: outerRadius * 0.10)).fill()
    NSBezierPath(ovalIn: NSRect(x: center.x + outerRadius * 0.16, y: center.y - outerRadius * 0.04, width: outerRadius * 0.10, height: outerRadius * 0.10)).fill()
    NSColor(hex: "#F2AFC5").withAlphaComponent(0.74).setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - outerRadius * 0.43, y: center.y - outerRadius * 0.19, width: outerRadius * 0.18, height: outerRadius * 0.11)).fill()
    NSBezierPath(ovalIn: NSRect(x: center.x + outerRadius * 0.29, y: center.y - outerRadius * 0.19, width: outerRadius * 0.18, height: outerRadius * 0.11)).fill()

    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: center.x - outerRadius * 0.08, y: center.y - outerRadius * 0.21))
    smile.curve(
        to: NSPoint(x: center.x + outerRadius * 0.10, y: center.y - outerRadius * 0.21),
        controlPoint1: NSPoint(x: center.x - outerRadius * 0.02, y: center.y - outerRadius * 0.31),
        controlPoint2: NSPoint(x: center.x + outerRadius * 0.05, y: center.y - outerRadius * 0.31)
    )
    smile.lineWidth = max(1.2, outerRadius * 0.09)
    smile.lineCapStyle = .round
    faceColor.withAlphaComponent(0.72).setStroke()
    smile.stroke()
}

func drawSymbolBadge(size: CGFloat, accent: NSColor, symbol: String) {
    let badgeRect = NSRect(x: size * 0.59, y: size * 0.61, width: size * 0.27, height: size * 0.22)
    NSColor.white.withAlphaComponent(0.94).setFill()
    NSBezierPath(roundedRect: badgeRect, xRadius: size * 0.08, yRadius: size * 0.08).fill()
    accent.withAlphaComponent(0.2).setStroke()
    let outline = NSBezierPath(roundedRect: badgeRect, xRadius: size * 0.08, yRadius: size * 0.08)
    outline.lineWidth = size * 0.012
    outline.stroke()

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.145, weight: .bold),
        .foregroundColor: accent
    ]
    let textSize = symbol.size(withAttributes: attributes)
    symbol.draw(
        at: NSPoint(x: badgeRect.midX - textSize.width / 2, y: badgeRect.midY - textSize.height / 2),
        withAttributes: attributes
    )
}

func drawCloud(size: CGFloat, accent: NSColor, badge: String?, background: NSColor = NSColor(hex: "#FFF7ED"), hasDeepBackdrop: Bool = false) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    background.setFill()
    NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.05, dy: size * 0.05), xRadius: size * 0.23, yRadius: size * 0.23).fill()

    if hasDeepBackdrop {
        NSColor(hex: "#8CB8D0").withAlphaComponent(0.24).setFill()
        NSBezierPath(ovalIn: NSRect(x: size * 0.10, y: size * 0.08, width: size * 0.68, height: size * 0.72)).fill()
        NSColor(hex: "#F2AFC5").withAlphaComponent(0.22).setFill()
        NSBezierPath(ovalIn: NSRect(x: size * 0.50, y: size * 0.38, width: size * 0.34, height: size * 0.34)).fill()
        drawStar(
            center: NSPoint(x: size * 0.76, y: size * 0.74),
            outerRadius: size * 0.055,
            innerRadius: size * 0.024,
            color: NSColor(hex: "#FFD7B8")
        )
    }

    accent.withAlphaComponent(hasDeepBackdrop ? 0.24 : 0.18).setFill()
    NSBezierPath(ovalIn: rect.insetBy(dx: size * 0.10, dy: size * 0.10)).fill()
    NSColor(hex: "#FFD7B8").withAlphaComponent(0.35).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.12, y: size * 0.15, width: size * 0.18, height: size * 0.18)).fill()

    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: size * 0.20, y: size * 0.31, width: size * 0.60, height: size * 0.28), xRadius: size * 0.14, yRadius: size * 0.14).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.17, y: size * 0.42, width: size * 0.30, height: size * 0.30)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.38, y: size * 0.49, width: size * 0.35, height: size * 0.35)).fill()

    NSColor(hex: "#2B2420").setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.39, y: size * 0.45, width: size * 0.045, height: size * 0.045)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.56, y: size * 0.45, width: size * 0.045, height: size * 0.045)).fill()

    NSColor(hex: "#F2AFC5").withAlphaComponent(0.72).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.33, y: size * 0.40, width: size * 0.055, height: size * 0.04)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.61, y: size * 0.40, width: size * 0.055, height: size * 0.04)).fill()

    let mouth = NSBezierPath()
    mouth.move(to: NSPoint(x: size * 0.47, y: size * 0.405))
    mouth.curve(
        to: NSPoint(x: size * 0.53, y: size * 0.405),
        controlPoint1: NSPoint(x: size * 0.49, y: size * 0.375),
        controlPoint2: NSPoint(x: size * 0.51, y: size * 0.375)
    )
    mouth.lineCapStyle = .round
    mouth.lineWidth = max(1.4, size * 0.017)
    NSColor(hex: "#2B2420").withAlphaComponent(0.72).setStroke()
    mouth.stroke()

    if let badge {
        if badge == "timer" {
            drawClockBadge(size: size, accent: accent)
        } else {
            drawSymbolBadge(size: size, accent: accent, symbol: badge)
        }
    }
}

func drawAppIcon(size: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let iconRect = rect.insetBy(dx: size * 0.05, dy: size * 0.05)
    let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: size * 0.24, yRadius: size * 0.24)
    NSGradient(colors: [NSColor(hex: "#244F48"), NSColor(hex: "#6E4C77")])?.draw(in: iconPath, angle: -35)

    NSColor(hex: "#8CB8D0").withAlphaComponent(0.20).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.10, y: size * 0.10, width: size * 0.72, height: size * 0.72)).fill()
    NSColor(hex: "#F2AFC5").withAlphaComponent(0.16).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.45, y: size * 0.46, width: size * 0.36, height: size * 0.30)).fill()
    NSColor(hex: "#FFD7B8").withAlphaComponent(0.24).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.12, y: size * 0.14, width: size * 0.17, height: size * 0.17)).fill()

    NSColor.black.withAlphaComponent(0.18).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.24, y: size * 0.22, width: size * 0.56, height: size * 0.16)).fill()

    drawMaltese(size: size, accent: NSColor(hex: "#2F6F64"), accessory: "clock")
}

func drawMaltese(size: CGFloat, accent: NSColor, accessory: String?) {
    NSColor(hex: "#FFF5EA").setFill()
    NSBezierPath(roundedRect: NSRect(x: size * 0.29, y: size * 0.23, width: size * 0.45, height: size * 0.28), xRadius: size * 0.14, yRadius: size * 0.14).fill()

    NSColor.white.withAlphaComponent(0.98).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.20, y: size * 0.34, width: size * 0.24, height: size * 0.42)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.56, y: size * 0.34, width: size * 0.24, height: size * 0.42)).fill()
    NSColor(hex: "#F2E4DA").setFill()
    NSBezierPath(roundedRect: NSRect(x: size * 0.19, y: size * 0.34, width: size * 0.20, height: size * 0.42), xRadius: size * 0.10, yRadius: size * 0.10).fill()
    NSBezierPath(roundedRect: NSRect(x: size * 0.61, y: size * 0.34, width: size * 0.20, height: size * 0.42), xRadius: size * 0.10, yRadius: size * 0.10).fill()

    NSColor.white.withAlphaComponent(0.99).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.24, y: size * 0.34, width: size * 0.54, height: size * 0.54)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.32, y: size * 0.62, width: size * 0.16, height: size * 0.16)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.45, y: size * 0.68, width: size * 0.18, height: size * 0.18)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.58, y: size * 0.62, width: size * 0.16, height: size * 0.16)).fill()
    NSColor.white.withAlphaComponent(0.38).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.39, y: size * 0.60, width: size * 0.26, height: size * 0.12)).fill()

    NSColor(hex: "#2B2420").setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.39, y: size * 0.51, width: size * 0.048, height: size * 0.048)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.57, y: size * 0.51, width: size * 0.048, height: size * 0.048)).fill()
    NSBezierPath(roundedRect: NSRect(x: size * 0.49, y: size * 0.455, width: size * 0.055, height: size * 0.038), xRadius: size * 0.02, yRadius: size * 0.02).fill()
    NSColor(hex: "#F2AFC5").withAlphaComponent(0.78).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.32, y: size * 0.45, width: size * 0.064, height: size * 0.043)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.65, y: size * 0.45, width: size * 0.064, height: size * 0.043)).fill()

    let mouth = NSBezierPath()
    mouth.move(to: NSPoint(x: size * 0.47, y: size * 0.42))
    mouth.curve(
        to: NSPoint(x: size * 0.54, y: size * 0.42),
        controlPoint1: NSPoint(x: size * 0.49, y: size * 0.38),
        controlPoint2: NSPoint(x: size * 0.52, y: size * 0.38)
    )
    mouth.lineCapStyle = .round
    mouth.lineWidth = max(1.4, size * 0.018)
    NSColor(hex: "#2B2420").withAlphaComponent(0.72).setStroke()
    mouth.stroke()

    drawCuteStarBuddy(
        center: NSPoint(x: size * 0.73, y: size * 0.73),
        outerRadius: size * 0.095,
        color: NSColor(hex: "#FFD7B8")
    )
    if accessory == "clock" {
        drawClockBadge(size: size, accent: accent, badgeRect: NSRect(x: size * 0.61, y: size * 0.21, width: size * 0.24, height: size * 0.24))
    } else if accessory == "check" {
        drawSymbolBadge(size: size, accent: NSColor(hex: "#A8512D"), symbol: "✓")
    }
}

func drawMenuBarCloudClock(size: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    NSColor.black.setStroke()
    let lineWidth = max(1.5, size * 0.105)
    let body = NSBezierPath()
    body.lineWidth = lineWidth
    body.lineCapStyle = .round
    body.lineJoinStyle = .round
    body.move(to: NSPoint(x: size * 0.22, y: size * 0.42))
    body.curve(
        to: NSPoint(x: size * 0.43, y: size * 0.58),
        controlPoint1: NSPoint(x: size * 0.21, y: size * 0.54),
        controlPoint2: NSPoint(x: size * 0.31, y: size * 0.62)
    )
    body.curve(
        to: NSPoint(x: size * 0.68, y: size * 0.47),
        controlPoint1: NSPoint(x: size * 0.49, y: size * 0.74),
        controlPoint2: NSPoint(x: size * 0.70, y: size * 0.67)
    )
    body.curve(
        to: NSPoint(x: size * 0.80, y: size * 0.36),
        controlPoint1: NSPoint(x: size * 0.75, y: size * 0.47),
        controlPoint2: NSPoint(x: size * 0.82, y: size * 0.43)
    )
    body.line(to: NSPoint(x: size * 0.25, y: size * 0.36))
    body.stroke()

    let clockRect = NSRect(x: size * 0.55, y: size * 0.43, width: size * 0.28, height: size * 0.28)
    let clock = NSBezierPath(ovalIn: clockRect)
    clock.lineWidth = max(1.2, size * 0.075)
    clock.stroke()

    let center = NSPoint(x: clockRect.midX, y: clockRect.midY)
    let hands = NSBezierPath()
    hands.lineCapStyle = .round
    hands.lineWidth = max(1.1, size * 0.065)
    hands.move(to: center)
    hands.line(to: NSPoint(x: center.x, y: center.y + size * 0.09))
    hands.move(to: center)
    hands.line(to: NSPoint(x: center.x + size * 0.075, y: center.y))
    hands.stroke()
}

func drawMenuBarPawTimer(size: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    NSColor.black.setFill()
    let toeSize = size * 0.18
    NSBezierPath(ovalIn: NSRect(x: size * 0.19, y: size * 0.53, width: toeSize, height: toeSize)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.38, y: size * 0.63, width: toeSize, height: toeSize)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.58, y: size * 0.53, width: toeSize, height: toeSize)).fill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.34, y: size * 0.25, width: size * 0.34, height: size * 0.29)).fill()

    NSColor.clear.setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.46, y: size * 0.34, width: size * 0.34, height: size * 0.34)).fill()

    NSColor.black.setStroke()
    let clockRect = NSRect(x: size * 0.48, y: size * 0.35, width: size * 0.32, height: size * 0.32)
    let clock = NSBezierPath(ovalIn: clockRect)
    clock.lineWidth = max(1.2, size * 0.075)
    clock.stroke()

    let center = NSPoint(x: clockRect.midX, y: clockRect.midY)
    let hands = NSBezierPath()
    hands.lineCapStyle = .round
    hands.lineWidth = max(1.0, size * 0.06)
    hands.move(to: center)
    hands.line(to: NSPoint(x: center.x, y: center.y + size * 0.085))
    hands.move(to: center)
    hands.line(to: NSPoint(x: center.x + size * 0.070, y: center.y))
    hands.stroke()
}

func drawStarSticker(size: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()
    NSColor(hex: "#FFD7B8").setFill()
    NSBezierPath(ovalIn: rect.insetBy(dx: size * 0.08, dy: size * 0.08)).fill()

    let center = NSPoint(x: size / 2, y: size / 2)
    let path = NSBezierPath()
    for index in 0..<10 {
        let radius = index.isMultiple(of: 2) ? size * 0.31 : size * 0.13
        let angle = CGFloat(index) * .pi / 5 + .pi / 2
        let point = NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        index == 0 ? path.move(to: point) : path.line(to: point)
    }
    path.close()
    NSColor(hex: "#A8512D").setFill()
    path.fill()
}

func drawTimerSkin(size: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()
    NSColor(hex: "#DDEDE7").setFill()
    NSBezierPath(ovalIn: rect.insetBy(dx: size * 0.09, dy: size * 0.09)).fill()
    NSColor(hex: "#2F6F64").setStroke()
    let ring = NSBezierPath(ovalIn: rect.insetBy(dx: size * 0.17, dy: size * 0.17))
    ring.lineWidth = size * 0.05
    ring.stroke()
    let hand = NSBezierPath()
    hand.move(to: NSPoint(x: size / 2, y: size / 2))
    hand.line(to: NSPoint(x: size / 2, y: size * 0.74))
    hand.line(to: NSPoint(x: size * 0.66, y: size * 0.58))
    hand.lineWidth = size * 0.045
    hand.lineCapStyle = .round
    hand.stroke()
}

func writeImageSet(name: String, draw: @escaping (CGFloat) -> Void) throws {
    let directory = assetsRoot.appendingPathComponent("\(name).imageset")
    try ensureDirectory(directory)
    try writePNG(size: 512, to: directory.appendingPathComponent("\(name).png"), draw: draw)
    try writePNG(size: 1024, to: directory.appendingPathComponent("\(name)@2x.png"), draw: draw)
    try writeImageContents(name: name, to: directory)
}

func writeImageContents(name: String, to directory: URL, template: Bool = false) throws {
    let properties = template
        ? ",\n  \"properties\" : { \"template-rendering-intent\" : \"template\" }"
        : ""
    let json = """
    {
      "images" : [
        { "filename" : "\(name).png", "idiom" : "universal", "scale" : "1x" },
        { "filename" : "\(name)@2x.png", "idiom" : "universal", "scale" : "2x" }
      ],
      "info" : { "author" : "xcode", "version" : 1 }\(properties)
    }

    """
    try json.write(to: directory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

func writeTemplateMenuBarImageSet(name: String, draw: @escaping (CGFloat) -> Void) throws {
    let directory = assetsRoot.appendingPathComponent("\(name).imageset")
    try ensureDirectory(directory)
    try writePNG(size: 18, to: directory.appendingPathComponent("\(name).png"), draw: draw)
    try writePNG(size: 36, to: directory.appendingPathComponent("\(name)@2x.png"), draw: draw)
    try writeImageContents(name: name, to: directory, template: true)
}

func writeColorSet(name: String, hex: String) throws {
    let directory = assetsRoot.appendingPathComponent("\(name).colorset")
    try ensureDirectory(directory)
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var value: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&value)
    let red = String(format: "0x%02X", (value >> 16) & 0xFF)
    let green = String(format: "0x%02X", (value >> 8) & 0xFF)
    let blue = String(format: "0x%02X", value & 0xFF)
    let json = """
    {
      "colors" : [
        {
          "color" : {
            "color-space" : "srgb",
            "components" : {
              "alpha" : "1.000",
              "blue" : "\(blue)",
              "green" : "\(green)",
              "red" : "\(red)"
            }
          },
          "idiom" : "universal"
        }
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }

    """
    try json.write(to: directory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

try ensureDirectory(assetsRoot)

let iconDirectory = assetsRoot.appendingPathComponent("AppIcon.appiconset")
try ensureDirectory(iconDirectory)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    try writePNG(size: size, to: iconDirectory.appendingPathComponent("AppIcon-\(size).png")) { canvas in
        drawAppIcon(size: canvas)
    }
}

try writeImageSet(name: "mascot-idle") { drawMaltese(size: $0, accent: NSColor(hex: "#8CB8D0"), accessory: nil) }
try writeImageSet(name: "mascot-focus") { drawMaltese(size: $0, accent: NSColor(hex: "#2F6F64"), accessory: "clock") }
try writeImageSet(name: "mascot-complete") { drawMaltese(size: $0, accent: NSColor(hex: "#A8512D"), accessory: "check") }
try writeImageSet(name: "sticker-tiny-win") { drawStarSticker(size: $0) }
try writeImageSet(name: "timer-skin-jade") { drawTimerSkin(size: $0) }
try writeTemplateMenuBarImageSet(name: "menubar-cloud-clock") { drawMenuBarCloudClock(size: $0) }
try writeTemplateMenuBarImageSet(name: "menubar-paw-timer") { drawMenuBarPawTimer(size: $0) }

try writeColorSet(name: "Canvas", hex: "#FFF9F7")
try writeColorSet(name: "Surface", hex: "#FFFFFF")
try writeColorSet(name: "Ink", hex: "#2E2623")
try writeColorSet(name: "MutedText", hex: "#746863")
try writeColorSet(name: "FocusJade", hex: "#2F6F64")
try writeColorSet(name: "MistBlue", hex: "#8CB8D0")
try writeColorSet(name: "SoftMint", hex: "#DDEDE7")
try writeColorSet(name: "Persimmon", hex: "#A8512D")
try writeColorSet(name: "Peach", hex: "#FFD7B8")
try writeColorSet(name: "StickerPink", hex: "#F2AFC5")

print("Generated CozyTime Xcode assets at \(assetsRoot.path)")
