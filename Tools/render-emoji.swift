// Renders the emoji the prototype's fixed data uses into PNGs with the Mac's Apple Color Emoji, for simulators whose
// runtime cannot draw emoji (the app uses them only when the system font has no emoji glyphs).
// Usage: xcrun swift Tools/render-emoji.swift Resources/EmojiFallback
import AppKit
let out = CommandLine.arguments[1]
let emoji = ["🦫", "👀", "❤️", "🔥", "☀️"]
for (i, e) in emoji.enumerated() {
    let size = NSSize(width: 96, height: 96)
    let image = NSImage(size: size)
    image.lockFocus()
    let font = NSFont(name: "Apple Color Emoji", size: 90)!
    let s = NSAttributedString(string: e, attributes: [.font: font])
    let b = s.size()
    s.draw(at: NSPoint(x: (size.width - b.width) / 2, y: (size.height - b.height) / 2))
    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let png = rep.representation(using: .png, properties: [:])!
    let scalars = e.unicodeScalars.map { String(format: "%x", $0.value) }.joined(separator: "_")
    try! png.write(to: URL(fileURLWithPath: "\(out)/emoji_\(scalars).png"))
    _ = i
}
print("ok")
