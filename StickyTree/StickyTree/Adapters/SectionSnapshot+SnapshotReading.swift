import UIKit
import StickyTreeCore

/// 把 UIKit 的 NSDiffableDataSourceSectionSnapshot 适配成 SnapshotReading。
/// 不直接写 conformance extension 是为了避开 Swift 里扩展方法遮蔽同签名
/// 实例方法导致的无限递归问题(我们的 parent(of:) 会把 UIKit 的 parent(of:)
/// 挡掉,然后自己调自己)。用 wrapper 显式委托,清晰可读。
public struct DiffableTreeSnapshot<Item: Hashable>: SnapshotReading {
    public let underlying: NSDiffableDataSourceSectionSnapshot<Item>

    public init(_ underlying: NSDiffableDataSourceSectionSnapshot<Item>) {
        self.underlying = underlying
    }

    public func parent(of item: Item) -> Item? {
        underlying.parent(of: item)
    }

    public func level(of item: Item) -> Int? {
        let lvl = underlying.level(of: item)
        return lvl >= 0 ? lvl : nil
    }

    public func isExpanded(_ item: Item) -> Bool {
        underlying.isExpanded(item)
    }
}
