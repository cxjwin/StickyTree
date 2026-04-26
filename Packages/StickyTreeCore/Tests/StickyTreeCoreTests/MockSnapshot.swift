import Foundation
@testable import StickyTreeCore

/// 测试用 snapshot,显式持有父指针、层级、展开状态。
struct MockSnapshot<Item: Hashable>: SnapshotReading {
    var parents: [Item: Item] = [:]
    var levels: [Item: Int] = [:]
    var expandedItems: Set<Item> = []

    func parent(of item: Item) -> Item? { parents[item] }
    func level(of item: Item) -> Int? { levels[item] }
    func isExpanded(_ item: Item) -> Bool { expandedItems.contains(item) }
}

extension MockSnapshot {
    /// 便捷构造:按 [(子, 父, 层级)] 列表建树。
    static func tree(_ edges: [(child: Item, parent: Item?, level: Int)]) -> MockSnapshot {
        var m = MockSnapshot()
        for (child, parent, level) in edges {
            m.levels[child] = level
            if let p = parent { m.parents[child] = p }
        }
        return m
    }
}
