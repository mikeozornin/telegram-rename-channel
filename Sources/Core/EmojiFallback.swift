import UIKit
import CoreText

/// Some simulator runtimes cannot draw Apple Color Emoji (missing-glyph boxes). Only then, emoji in the prototype's
/// fixed data are drawn from Resources/EmojiFallback (rendered on the Mac by Tools/render-emoji.swift). On a device
/// or a healthy simulator `isNeeded` is false and text is left untouched.
enum EmojiFallback {
    static let isNeeded: Bool = {
        #if targetEnvironment(simulator)
        // The iOS 26.3 simulator runtime here draws missing-glyph boxes for every emoji, although the font
        // resolves and CoreGraphics probes look fine, so the simulator always takes the fallback.
        return true
        #endif
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, 17.0, nil)
        let name = CTFontCopyPostScriptName(font) as String
        if name != "AppleColorEmoji" { return true }
        var chars: [UniChar] = Array("🦫".utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        let ok = CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count)
        if !ok || glyphs[0] == 0 { return true }
        // The font may resolve and still draw nothing: render a glyph and look for colour.
        let size = CGSize(width: 24.0, height: 24.0)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            ("🦫" as NSString).draw(at: .zero, withAttributes: [.font: UIFont.systemFont(ofSize: 18.0)])
        }
        guard let cg = image.cgImage, let data = cg.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return false }
        let length = CFDataGetLength(data)
        var colored = 0
        var i = 0
        while i + 3 < length {
            let r = Int(ptr[i]), g = Int(ptr[i + 1]), b = Int(ptr[i + 2]), a = Int(ptr[i + 3])
            if a > 40 && (abs(r - g) > 25 || abs(g - b) > 25) { colored += 1 }
            i += 4
        }
        return colored < 6
    }()

    private static func image(for grapheme: String) -> UIImage? {
        let name = "emoji_" + grapheme.unicodeScalars.map { String(format: "%x", $0.value) }.joined(separator: "_")
        if let path = Bundle.main.path(forResource: name, ofType: "png") {
            return UIImage(contentsOfFile: path)
        }
        return nil
    }

    static func apply(_ text: NSAttributedString) -> NSAttributedString {
        guard self.isNeeded else { return text }
        let result = NSMutableAttributedString(attributedString: text)
        let string = text.string as NSString
        var replacements: [(NSRange, NSAttributedString)] = []
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: .byComposedCharacterSequences) { sub, range, _, _ in
            guard let sub, sub.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || $0.value == 0x2764 || $0.value == 0x2600 }), let image = self.image(for: sub) else { return }
            let attrs = text.attributes(at: range.location, effectiveRange: nil)
            let font = attrs[.font] as? UIFont ?? UIFont.systemFont(ofSize: 17.0)
            let side = ceil(font.pointSize * 1.25)
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(x: 0.0, y: font.descender - 0.5, width: side, height: side)
            let s = NSMutableAttributedString(attachment: attachment)
            s.addAttributes(attrs, range: NSRange(location: 0, length: s.length))
            replacements.append((range, s))
        }
        for (range, s) in replacements.reversed() {
            result.replaceCharacters(in: range, with: s)
        }
        return result
    }
}

extension UILabel {
    /// Re-applies the emoji fallback to the label's current text.
    func applyEmojiFallback() {
        guard EmojiFallback.isNeeded else { return }
        if let a = self.attributedText, a.length > 0 {
            self.attributedText = EmojiFallback.apply(a)
        }
    }
}
