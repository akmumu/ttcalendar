import AppKit
import Foundation

let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("GeneratedIcon.appiconset")

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let sizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

for size in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocusFlipped(false)

    guard let context = NSGraphicsContext.current?.cgContext else { continue }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    drawIcon(in: context, rect: rect)
    image.unlockFocus()

    if let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try png.write(to: outputDir.appendingPathComponent("icon_\(size)x\(size).png"))
    }
}

func drawIcon(in ctx: CGContext, rect: CGRect) {
    let colorspace = CGColorSpaceCreateDeviceRGB()
    ctx.saveGState()
    ctx.setFillColor(NSColor.clear.cgColor)
    ctx.fill(rect)

    let path = CGPath(roundedRect: rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06), cornerWidth: rect.width * 0.19, cornerHeight: rect.height * 0.19, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    let bgColors = [
        NSColor(calibratedRed: 0.99, green: 0.89, blue: 0.91, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.98, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.89, green: 0.94, blue: 0.99, alpha: 1).cgColor
    ] as CFArray
    let bgLocations: [CGFloat] = [0, 0.58, 1]
    if let gradient = CGGradient(colorsSpace: colorspace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    }

    ctx.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.55).cgColor)
    ctx.setLineWidth(max(1, rect.width * 0.014))
    ctx.addPath(path)
    ctx.strokePath()

    let pad = rect.width * 0.11
    let calendarRect = CGRect(x: pad, y: pad * 1.1, width: rect.width - pad * 2, height: rect.height - pad * 1.6)

    let shadow = NSShadow()
    shadow.shadowBlurRadius = rect.width * 0.03
    shadow.shadowOffset = CGSize(width: 0, height: -rect.width * 0.01)
    shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.18)
    shadow.set()

    let cardPath = CGPath(roundedRect: calendarRect, cornerWidth: rect.width * 0.07, cornerHeight: rect.width * 0.07, transform: nil)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.addPath(cardPath)
    ctx.fillPath()

    ctx.setShadow(offset: .zero, blur: 0)
    ctx.setStrokeColor(NSColor(calibratedWhite: 0.85, alpha: 1).cgColor)
    ctx.setLineWidth(max(0.8, rect.width * 0.006))
    ctx.addPath(cardPath)
    ctx.strokePath()

    let topBar = CGRect(x: calendarRect.minX, y: calendarRect.maxY - calendarRect.height * 0.24, width: calendarRect.width, height: calendarRect.height * 0.24)
    let topPath = CGPath(roundedRect: topBar, cornerWidth: rect.width * 0.07, cornerHeight: rect.width * 0.07, transform: nil)
    ctx.setFillColor(NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.82, alpha: 1).cgColor)
    ctx.addPath(topPath)
    ctx.fillPath()

    let weekX = calendarRect.minX + calendarRect.width * 0.08
    let weekY = calendarRect.maxY - calendarRect.height * 0.14
    drawText("周", at: CGPoint(x: weekX, y: weekY), size: rect.width * 0.07, color: NSColor(calibratedRed: 0.90, green: 0.38, blue: 0.42, alpha: 1), weight: .semibold, centered: false)

    let dayX = calendarRect.minX + calendarRect.width * 0.18
    let dayY = calendarRect.minY + calendarRect.height * 0.24
    drawText("15", at: CGPoint(x: dayX, y: dayY), size: rect.width * 0.22, color: NSColor(calibratedRed: 0.26, green: 0.28, blue: 0.33, alpha: 1), weight: .bold, centered: false)

    let lunarX = calendarRect.minX + calendarRect.width * 0.10
    let lunarY = calendarRect.minY + calendarRect.height * 0.10
    drawText("农历", at: CGPoint(x: lunarX, y: lunarY), size: rect.width * 0.08, color: NSColor(calibratedRed: 0.88, green: 0.44, blue: 0.48, alpha: 1), weight: .medium, centered: false)

    let accentDotRect = CGRect(x: calendarRect.maxX - rect.width * 0.16, y: calendarRect.minY + rect.height * 0.13, width: rect.width * 0.08, height: rect.width * 0.08)
    ctx.setFillColor(NSColor(calibratedRed: 0.96, green: 0.50, blue: 0.55, alpha: 1).cgColor)
    ctx.fillEllipse(in: accentDotRect)
    ctx.restoreGState()
}

func drawText(_ string: String, at point: CGPoint, size: CGFloat, color: NSColor, weight: NSFont.Weight, centered: Bool) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let text = NSAttributedString(string: string, attributes: attrs)
    let bounds = text.size()
    let origin = centered
        ? CGPoint(x: point.x - bounds.width / 2, y: point.y - bounds.height / 2)
        : CGPoint(x: point.x, y: point.y)
    text.draw(at: origin)
}
