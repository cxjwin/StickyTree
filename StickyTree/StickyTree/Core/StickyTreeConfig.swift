import UIKit

public struct StickyTreeConfig<Item: Hashable> {
    public var isBranch:       (Item) -> Bool
    public var title:          (Item) -> String
    public var subtitle:       (Item) -> String?
    public var levelHeight:    CGFloat
    public var indentPerLevel: CGFloat

    public init(
        isBranch: @escaping (Item) -> Bool,
        title: @escaping (Item) -> String,
        subtitle: @escaping (Item) -> String? = { _ in nil },
        levelHeight: CGFloat = 44,
        indentPerLevel: CGFloat = 14
    ) {
        self.isBranch = isBranch
        self.title = title
        self.subtitle = subtitle
        self.levelHeight = levelHeight
        self.indentPerLevel = indentPerLevel
    }
}
