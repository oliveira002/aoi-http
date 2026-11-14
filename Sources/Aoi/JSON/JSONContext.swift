import AppKit

// Where the cursor sits in a JSON body that may be half typed: which container, and whether a key or a value goes here.
struct JSONContext: Equatable {
    enum Kind: Equatable { case key, value(key: String?) }

    var path: [JSONStep]
    var kind: Kind
    var partial: String
    // What a completion replaces: the typed word or the whole string token around the cursor.
    var replace: NSRange
    var quoted: Bool
    // A key being edited that already has its colon, so only the name is replaced.
    var hasColon: Bool
    var siblings: Set<String>

    private struct Frame {
        enum Phase { case key, colon, value }
        let id: Int
        let isObject: Bool
        var phase: Phase
        var key: String?
        var keys: [String] = []
        // A value was written since the last comma, so nothing new goes right after it.
        var valueDone = false
    }

    static func at(_ cursor: Int, in text: String) -> JSONContext? {
        let chars = Array(text.utf16)
        var frames: [Frame] = []
        var nextID = 0
        var result: JSONContext?
        var target: Int?
        var editing: String?

        func snapshot(partial: String, replace: NSRange, quoted: Bool, hasColon: Bool, inToken: Bool = true) {
            guard result == nil, let top = frames.last, inToken || !top.valueDone else { return }
            let kind: Kind
            switch (top.isObject, top.phase) {
            case (true, .key): kind = .key
            case (true, .value): kind = .value(key: top.key)
            case (false, _): kind = .value(key: nil)
            default: return
            }
            let path = frames.dropLast().map { $0.isObject ? JSONStep.key($0.key ?? "") : .index }
            result = JSONContext(path: path, kind: kind, partial: partial, replace: replace, quoted: quoted, hasColon: hasColon, siblings: [])
            target = top.id
        }

        func colonFollows(_ index: Int) -> Bool {
            var k = index
            while k < chars.count, chars[k] == 32 || chars[k] == 9 || chars[k] == 10 || chars[k] == 13 { k += 1 }
            return k < chars.count && chars[k] == 58
        }

        func close() {
            guard let frame = frames.popLast() else { return }
            if frame.id == target { result?.siblings = Set(frame.keys) }
            finishValue()
        }

        func finishValue() {
            guard var top = frames.last, !top.isObject || top.phase == .value else { return }
            top.valueDone = true
            frames[frames.count - 1] = top
        }

        var i = 0
        while i < chars.count {
            if i == cursor { snapshot(partial: "", replace: NSRange(location: cursor, length: 0), quoted: false, hasColon: false, inToken: false) }
            let c = chars[i]
            switch c {
            case 34: // "
                // A raw newline cannot sit inside a JSON string, so an unclosed quote ends at the end of its line.
                var j = i + 1
                while j < chars.count, chars[j] != 34, chars[j] != 10, chars[j] != 13 {
                    j += chars[j] == 92 ? 2 : 1
                }
                let end = min(j, chars.count)
                let closed = j < chars.count && chars[j] == 34
                let content = String(decoding: chars[(i + 1)..<end], as: UTF16.self)
                if cursor > i, cursor <= end {
                    let typed = String(decoding: chars[(i + 1)..<cursor], as: UTF16.self)
                    let length = (closed ? j + 1 : end) - i
                    snapshot(partial: typed, replace: NSRange(location: i, length: length), quoted: true, hasColon: closed && colonFollows(j + 1))
                    if result != nil, editing == nil { editing = content }
                }
                // A key still being typed (no closing quote) is not a key yet, so the next line's key still counts.
                if !closed, frames.last?.isObject == true, frames.last?.phase == .key {
                    i = end
                    continue
                }
                if var top = frames.last, top.isObject, top.phase == .key {
                    top.key = content
                    top.keys.append(content)
                    top.phase = .colon
                    frames[frames.count - 1] = top
                } else {
                    finishValue()
                }
                i = closed ? j + 1 : end
                continue
            case 123, 91: // { [
                frames.append(Frame(id: nextID, isObject: c == 123, phase: c == 123 ? .key : .value))
                nextID += 1
            case 125, 93: // } ]
                close()
            case 58: // :
                if frames.last?.isObject == true { frames[frames.count - 1].phase = .value }
            case 44: // ,
                if frames.last?.isObject == true {
                    frames[frames.count - 1].phase = .key
                    frames[frames.count - 1].key = nil
                }
                if !frames.isEmpty { frames[frames.count - 1].valueDone = false }
            default:
                // A bare word, such as a key typed without quotes or true/false.
                if let scalar = Unicode.Scalar(c), CharacterSet.alphanumerics.contains(scalar) || c == 95 {
                    var j = i
                    while j < chars.count, let s = Unicode.Scalar(chars[j]), CharacterSet.alphanumerics.contains(s) || chars[j] == 95 || chars[j] == 45 || chars[j] == 46 { j += 1 }
                    if cursor > i, cursor <= j {
                        let typed = String(decoding: chars[i..<cursor], as: UTF16.self)
                        snapshot(partial: typed, replace: NSRange(location: i, length: j - i), quoted: false, hasColon: colonFollows(j))
                    }
                    if frames.last.map({ !$0.isObject || $0.phase == .value }) == true { finishValue() }
                    i = j
                    continue
                }
            }
            i += 1
        }
        if cursor >= chars.count { snapshot(partial: "", replace: NSRange(location: cursor, length: 0), quoted: false, hasColon: false, inToken: false) }
        // Still open at the end of the text: take the keys gathered so far.
        if let target, let frame = frames.first(where: { $0.id == target }) { result?.siblings = Set(frame.keys) }
        if let editing { result?.siblings.remove(editing) }
        return result
    }
}
