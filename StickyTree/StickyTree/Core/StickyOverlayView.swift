import UIKit
import StickyTreeCore

public final class StickyOverlayView<Item: Hashable>: UIView {
    public var instructions: [DrawInstruction<Item>] = [] {
        didSet { rebuildPinViews() }
    }

    /// 外部注入的 pin 视图构造器。返回的 UIView 由 overlay 负责 add/remove 和 frame 布局。
    /// 典型实现:`UICollectionViewListCell` 配相同的 cellProvider 配置,保证 pin 和 cell 外观完全一致。
    public var viewProvider: (Item, DrawInstruction<Item>) -> UIView = { _, _ in UIView() }

    /// pin 被 tap 时回调。Overlay 自身不改 snapshot。
    public var tapHandler: (Item) -> Void = { _ in }

    private var pinViews: [UIView] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func rebuildPinViews() {
        // 每次 instructions 变化重建 —— demo 量级下性能无压力。
        // Z-order:根在顶、最深在底。push-out 时最深 pin 从自己的 slot 上滑,
        // 应该"滑到父 pin 后面"消失,而不是覆盖父 pin。所以按 reversed 顺序 addSubview
        // (最深先加、在底;根最后加、在顶)。
        for v in pinViews { v.removeFromSuperview() }
        pinViews = instructions.reversed().map { instr in
            let v = viewProvider(instr.item, instr)
            v.frame = instr.frame
            v.isUserInteractionEnabled = false   // 触摸由 overlay 自己处理
            addSubview(v)
            return v
        }
    }

    /// 只吞 pin 矩形内的触摸,其余透传 —— 用户能继续滚下面的 collectionView。
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return instructions.contains { $0.frame.contains(point) }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        // 两层重叠时,视觉上父 pin 在上(z-order),tap 也应该命中父 pin —— 取 level 最浅的。
        let hit = instructions.filter { $0.frame.contains(p) }
                              .min(by: { $0.level < $1.level })
        if let item = hit?.item { tapHandler(item) }
    }
}
