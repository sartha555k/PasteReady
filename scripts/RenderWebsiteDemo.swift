import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// A reproducible illustrated workflow, not a recording of a user's desktop.
let width = 1200, height = 900, fps = 30, seconds = 12
let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "website/dist/assets")
let source = URL(fileURLWithPath: "website/dist/assets/product.png")
guard let panel = NSImage(contentsOf: source) else { fatalError("Render the native product capture first.") }
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let movie = output.appendingPathComponent("pasteready-demo.mp4")
let encoder = Process(), input = Pipe()
encoder.executableURL = URL(fileURLWithPath: "/usr/bin/env")
encoder.arguments = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-f", "rawvideo", "-pixel_format", "bgra", "-video_size", "\(width)x\(height)", "-framerate", "\(fps)", "-i", "pipe:0", "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "23", "-pix_fmt", "yuv420p", "-movflags", "+faststart", movie.path]
encoder.standardInput = input
encoder.standardError = FileHandle.standardError
try encoder.run()
let ink = NSColor(srgbRed: 0.14, green: 0.18, blue: 0.15, alpha: 1)
let muted = NSColor(srgbRed: 0.38, green: 0.42, blue: 0.38, alpha: 1)
let line = NSColor(srgbRed: 0.84, green: 0.87, blue: 0.83, alpha: 1)
let paper = NSColor(srgbRed: 0.95, green: 0.96, blue: 0.94, alpha: 1)
let url = "https://www.linkedin.com/in/your-profile/"
let panelRect = NSRect(x: 320, y: 23, width: 560, height: 591)

func ease(_ x: Double) -> Double { 1 - pow(1 - max(0, min(1, x)), 3) }
func box(_ rect: NSRect, _ color: NSColor, radius: CGFloat = 10, stroke: NSColor? = nil) {
    let p = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill(); p.fill()
    if let stroke { stroke.setStroke(); p.lineWidth = 1; p.stroke() }
}
func text(_ string: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = ink, centered: Bool = false) {
    let style = NSMutableParagraphStyle()
    style.alignment = centered ? .center : .left
    style.lineBreakMode = .byTruncatingTail
    (string as NSString).draw(in: NSRect(x: x, y: y, width: width, height: size * 2), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style])
}
func pointer(_ x: CGFloat, _ y: CGFloat, click: Double = 0) {
    if click > 0 {
        NSColor(srgbRed: 0.23, green: 0.43, blue: 0.31, alpha: click * 0.2).setFill()
        NSBezierPath(ovalIn: NSRect(x: x - 20, y: y - 20, width: 40, height: 40)).fill()
    }
    let p = NSBezierPath()
    p.move(to: NSPoint(x: x, y: y)); p.line(to: NSPoint(x: x + 2, y: y + 30))
    p.line(to: NSPoint(x: x + 10, y: y + 23)); p.line(to: NSPoint(x: x + 17, y: y + 37))
    p.line(to: NSPoint(x: x + 23, y: y + 34)); p.line(to: NSPoint(x: x + 16, y: y + 20))
    p.line(to: NSPoint(x: x + 27, y: y + 20)); p.close()
    NSColor.white.setStroke(); p.lineWidth = 3; p.stroke(); ink.setFill(); p.fill()
}
func keycap(_ label: String, x: CGFloat, y: CGFloat) {
    box(NSRect(x: x, y: y, width: 84, height: 46), ink, radius: 9)
    text(label, x: x, y: y + 9, width: 84, size: 23, weight: .medium, color: .white, centered: true)
}
func window(_ title: String, x: CGFloat, y: CGFloat) {
    box(NSRect(x: x, y: y, width: 480, height: 263), .white, radius: 14, stroke: line)
    box(NSRect(x: x + 22, y: y + 23, width: 8, height: 8), line, radius: 4)
    box(NSRect(x: x + 38, y: y + 23, width: 8, height: 8), line, radius: 4)
    box(NSRect(x: x + 54, y: y + 23, width: 8, height: 8), line, radius: 4)
    text(title, x: x + 22, y: y + 60, width: 430, size: 24, weight: .medium)
}

for frame in 0..<(fps * seconds) {
    try autoreleasepool {
        let t = Double(frame) / Double(fps)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { fatalError("No drawing context") }
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        paper.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        text("Example workflow", x: 32, y: 22, width: 260, size: 16, color: muted)
        box(NSRect(x: 520, y: -12, width: 160, height: 39), .black, radius: 15)
        window("Your profile", x: 60, y: 290)
        window("Application form", x: 660, y: 330)
        text("LinkedIn profile", x: 84, y: 402, width: 420, size: 16, color: muted)
        let selected = t >= 0.7 && t < 1.7
        box(NSRect(x: 84, y: 435, width: 432, height: 55), selected ? NSColor(srgbRed: 0.88, green: 0.93, blue: 0.99, alpha: 1) : paper, radius: 7, stroke: line)
        text(url, x: 98, y: 454, width: 405, size: 16)
        text("LinkedIn URL", x: 684, y: 443, width: 420, size: 16, color: muted)
        box(NSRect(x: 684, y: 476, width: 432, height: 55), .white, radius: 7, stroke: t >= 6.5 ? ink : line)
        let pasted = t >= 7.3
        text(pasted ? url : "Paste your profile link", x: 699, y: 495, width: 402, size: 16, color: pasted ? ink : muted)
        if t >= 1.25 && t < 2.25 { text("Copied", x: 84, y: 505, width: 420, size: 16, weight: .medium) }
        if t >= 0.9 && t < 1.5 { keycap("⌘ C", x: 430, y: 503) }
        if t >= 6.7 && t < 7.7 { keycap("⌘ V", x: 1006, y: 548) }
        if pasted { text("Your link, ready to use.", x: 684, y: 549, width: 420, size: 16, color: muted) }
        if t >= 6.5 && t < 7.3 && Int(t * 3) % 2 == 0 {
            box(NSRect(x: 699, y: 491, width: 1.5, height: 26), ink, radius: 0)
        }
        var reveal = ease((t - 2.65) / 0.32)
        if t >= 6.0 { reveal = 1 - ease((t - 6.0) / 0.2) }
        if reveal > 0 {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: NSRect(x: panelRect.minX, y: panelRect.minY, width: panelRect.width, height: panelRect.height * reveal)).addClip()
            panel.draw(in: panelRect, from: .zero, operation: .sourceOver, fraction: min(1, reveal * 2), respectFlipped: true, hints: nil)
            if t >= 4.8 {
                box(NSRect(x: 371, y: 502, width: 200, height: 23), .black, radius: 0)
                text("Copied to clipboard", x: 374, y: 506, width: 190, size: 11, color: .white)
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        var x = 210.0, y = 454.0
        if t >= 1.6 && t < 2.65 { let p = ease((t - 1.6) / 1.05); x += (600 - x) * p; y += (12 - y) * p }
        if t >= 2.65 && t < 3.6 { x = 600; y = 12 }
        if t >= 3.6 && t < 4.6 { let p = ease(t - 3.6); x = 600 + 165 * p; y = 12 + 296 * p }
        if t >= 4.6 && t < 5.25 { x = 765; y = 308 }
        if t >= 5.25 && t < 6.5 { let p = ease((t - 5.25) / 1.25); x = 765 + 170 * p; y = 308 + 192 * p }
        if t >= 6.5 { x = 935; y = 500 }
        let click = max(0, 1 - abs(t - 4.8) / 0.22) + max(0, 1 - abs(t - 6.6) / 0.18)
        pointer(x, y, click: click)
        let phase = t < 2.65 ? "Copy a link once." : t < 6.5 ? "Find it again at the notch." : "Paste it into your form."
        text(phase, x: 60, y: 710, width: 1080, size: 31, weight: .medium, centered: true)
        text("Sample text · illustrated walkthrough", x: 60, y: 771, width: 1080, size: 16, color: muted, centered: true)
        if t > 11.25 {
            NSColor(srgbRed: 0.95, green: 0.96, blue: 0.94, alpha: ease((t - 11.25) / 0.75)).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        if frame == 138, let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent("demo-poster.png") as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(destination, image, nil); CGImageDestinationFinalize(destination)
        }
        guard let bytes = context.data else { fatalError("No frame data") }
        try input.fileHandleForWriting.write(contentsOf: Data(bytes: bytes, count: width * height * 4))
    }
}
try input.fileHandleForWriting.close()
encoder.waitUntilExit()
guard encoder.terminationStatus == 0 else { fatalError("Video encoding failed") }
print("Rendered \(seconds)s silent walkthrough at \(width)×\(height), \(fps)fps: \(movie.path)")
