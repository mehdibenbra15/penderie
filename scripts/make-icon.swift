// Draws AppIcon.icns. Usage: swiftc scripts/make-icon.swift -o /tmp/mkicon && /tmp/mkicon /tmp/AppIcon.iconset && iconutil -c icns /tmp/AppIcon.iconset -o AppIcon.icns
import AppKit
let out = CommandLine.arguments[1]
func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let inset = s * 0.1
    let r = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: r, xRadius: r.width * 0.225, yRadius: r.width * 0.225)
    NSGraphicsContext.current!.cgContext.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    NSGradient(colors: [NSColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 1), NSColor(red: 0.93, green: 0.27, blue: 0.47, alpha: 1)])!.draw(in: path, angle: -70)
    NSGraphicsContext.current!.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
    // rod
    let rod = NSBezierPath(roundedRect: CGRect(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.27, width: r.width * 0.76, height: r.height * 0.045), xRadius: r.height * 0.0225, yRadius: r.height * 0.0225)
    NSColor.white.withAlphaComponent(0.95).setFill(); rod.fill()
    // two hanging cards
    for (i, dx) in [CGFloat(-0.17), 0.17].enumerated() {
        let cx = r.midX + r.width * dx
        let card = CGRect(x: cx - r.width * 0.15, y: r.minY + r.height * 0.2 + CGFloat(i) * r.height * 0.06, width: r.width * 0.3, height: r.height * 0.36 - CGFloat(i) * r.height * 0.06)
        NSGraphicsContext.current!.cgContext.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.025, color: NSColor.black.withAlphaComponent(0.25).cgColor)
        NSColor.white.setFill(); NSBezierPath(roundedRect: card, xRadius: s * 0.025, yRadius: s * 0.025).fill()
        NSGraphicsContext.current!.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        let hanger = NSBezierPath()
        hanger.lineWidth = s * 0.018; hanger.lineCapStyle = .round; hanger.lineJoinStyle = .round
        let rodY = r.maxY - r.height * 0.2475
        hanger.move(to: CGPoint(x: cx, y: rodY))
        hanger.line(to: CGPoint(x: cx + r.width * 0.12, y: card.maxY + r.height * 0.05))
        hanger.line(to: CGPoint(x: cx - r.width * 0.12, y: card.maxY + r.height * 0.05))
        hanger.close()
        NSColor.white.withAlphaComponent(0.95).setStroke(); hanger.stroke()
        for cdx in [CGFloat(-0.09), 0.09] {
            NSColor(white: 0.18, alpha: 1).setFill()
            NSBezierPath(roundedRect: CGRect(x: cx + r.width * cdx - s * 0.012, y: card.maxY - s * 0.03, width: s * 0.024, height: s * 0.08), xRadius: s * 0.006, yRadius: s * 0.006).fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
let fm = FileManager.default
try? fm.createDirectory(atPath: out, withIntermediateDirectories: true)
for (name, px) in [("16x16",16),("16x16@2x",32),("32x32",32),("32x32@2x",64),("128x128",128),("128x128@2x",256),("256x256",256),("256x256@2x",512),("512x512",512),("512x512@2x",1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
