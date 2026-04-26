import CoreGraphics

/// 单条吸顶指令。`StickyChainComputer` 产出一组此类型,`StickyOverlayView` 消费。
public struct DrawInstruction<Item: Hashable>: Hashable {
    public let item: Item
    /// Overlay 坐标系下的 frame(原点 0,0 在 overlay 左上角)。
    public let frame: CGRect
    /// 该 item 在 snapshot 中的层级。
    public let level: Int
    /// 是否在下方绘制分隔线。与展开状态关联。
    public let hasSeparator: Bool

    public init(item: Item, frame: CGRect, level: Int, hasSeparator: Bool) {
        self.item = item
        self.frame = frame
        self.level = level
        self.hasSeparator = hasSeparator
    }
}
