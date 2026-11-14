import Foundation

extension Sequence where Element: Hashable {
    // The elements in order, each kept only the first time it appears.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Set {
    mutating func toggle(_ member: Element) {
        if contains(member) { remove(member) } else { insert(member) }
    }
}
