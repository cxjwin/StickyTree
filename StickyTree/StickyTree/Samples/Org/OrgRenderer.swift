import UIKit
import StickyTreeCore

enum OrgRenderer {
    static func title(for item: OrgItem) -> String {
        item.code
    }

    static func subtitle(for item: OrgItem) -> String? {
        nil
    }

    static func isBranch(_ item: OrgItem) -> Bool {
        if case .dept = item { return true } else { return false }
    }

    /// 把一个 OrgRowView 装进 cell.contentView(首次装入时创建并 pin 到四边,
    /// 后续 reuse 直接复用已有的 rowView)。
    static func configure(
        cell: UICollectionViewCell,
        for item: OrgItem,
        level: Int,
        isExpanded: Bool
    ) {
        let row = rowView(in: cell)
        row.configure(with: item, level: level, isExpanded: isExpanded)
    }

    /// Overlay pin —— 一个独立的 OrgRowView,frame 由 overlay 直接设置。
    /// 这是和 cell 用的完全同一份 UIView 类,一模一样的布局。
    static func makePin(for item: OrgItem, instr: DrawInstruction<OrgItem>) -> UIView {
        let row = OrgRowView()
        // DrawInstruction.hasSeparator 本就承载 snapshot.isExpanded(item),
        // 让 pin 的 chevron 方向和实际展开状态一致(而不是硬编码 true)。
        row.configure(with: item, level: instr.level, isExpanded: instr.hasSeparator)
        return row
    }

    private static func rowView(in cell: UICollectionViewCell) -> OrgRowView {
        if let existing = cell.contentView.subviews.first(where: { $0 is OrgRowView }) as? OrgRowView {
            return existing
        }
        let row = OrgRowView()
        row.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
        ])
        return row
    }
}
