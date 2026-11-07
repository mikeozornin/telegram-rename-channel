import Foundation

/// Search matching for the chat list: trimmed query, whitespace tokens ANDed, a quoted phrase is one token,
/// case- and diacritics-insensitive (NFKD), from the first character. Each token must match at least one field.
enum SearchMatcher {
    static func normalize(_ value: String) -> String {
        return value
            .decomposedStringWithCompatibilityMapping
            .unicodeScalars
            .filter { !(0x0300...0x036f).contains($0.value) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
            .lowercased()
    }

    static func tokens(_ query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for ch in trimmed {
            if ch == "\"" || ch == "“" || ch == "”" {
                if inQuotes {
                    if !current.isEmpty { result.append(current) }
                    current = ""
                    inQuotes = false
                } else {
                    if !current.isEmpty { result.append(current) }
                    current = ""
                    inQuotes = true
                }
            } else if ch.isWhitespace && !inQuotes {
                if !current.isEmpty { result.append(current) }
                current = ""
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty {
            result.append(inQuotes ? current.trimmingCharacters(in: .whitespaces) : current)
        }
        return result.map(normalize).filter { !$0.isEmpty }
    }

    /// True when every token occurs in at least one of the fields.
    static func matches(tokens: [String], fields: [String]) -> Bool {
        if tokens.isEmpty { return false }
        let normalized = fields.map(normalize)
        return tokens.allSatisfy { token in normalized.contains(where: { $0.contains(token) }) }
    }

    /// Ranges of `text` (in its own, non-normalized characters) that match any token, for highlighting.
    static func highlightRanges(in text: String, tokens: [String]) -> [NSRange] {
        // Map each original character to its normalized form so ranges can be reported in the original string.
        var normalized = ""
        var map: [Int] = [] // normalized utf16 offset -> original utf16 offset
        var originalOffset = 0
        for ch in text {
            let n = normalize(String(ch))
            for _ in n.utf16 { map.append(originalOffset) }
            normalized += n
            originalOffset += String(ch).utf16.count
        }
        map.append(originalOffset)
        let ns = normalized as NSString
        var ranges: [NSRange] = []
        for token in tokens {
            var search = NSRange(location: 0, length: ns.length)
            while true {
                let r = ns.range(of: token, options: [], range: search)
                if r.location == NSNotFound { break }
                let start = map[r.location]
                let end = map[min(r.location + r.length, map.count - 1)]
                ranges.append(NSRange(location: start, length: max(0, end - start)))
                let next = r.location + max(r.length, 1)
                if next >= ns.length { break }
                search = NSRange(location: next, length: ns.length - next)
            }
        }
        return ranges
    }
}
