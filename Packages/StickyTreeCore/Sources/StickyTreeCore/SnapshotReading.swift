import Foundation

/// 对树形 snapshot 的只读视图。让算法层与 `NSDiffableDataSourceSectionSnapshot` 解耦,
/// 从而可在 macOS 上 `swift test`,并允许测试注入 MockSnapshot。
public protocol SnapshotReading {
    associatedtype Item: Hashable

    /// 返回 item 的直接父节点;根节点返回 nil。
    func parent(of item: Item) -> Item?

    /// 返回 item 在树中的层级(根为 0 或 1,具体由实现决定,算法层只依赖相对大小)。
    func level(of item: Item) -> Int?

    /// 该 item 当前是否展开。叶子节点可返回 false。
    func isExpanded(_ item: Item) -> Bool
}
