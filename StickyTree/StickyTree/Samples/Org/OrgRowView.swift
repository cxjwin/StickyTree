import UIKit

/// 自定义部门/联系人行视图。cell 和 overlay pin 共用同一个 UIView 类,
/// 所有布局细节(缩进、箭头、人数右对齐、分隔线)一处定义,两处一致。
final class OrgRowView: UIView {

    // MARK: Subviews

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevronView = UIImageView()
    private let separator = UIView()

    // MARK: State

    private var item: OrgItem?
    private var level: Int = 1
    private var isExpanded: Bool = true

    // MARK: Constants

    private let leadingPadding: CGFloat   = 16
    private let trailingPadding: CGFloat  = 16
    private let indentPerLevel: CGFloat   = 14
    private let chevronSize: CGFloat      = 16
    private let chevronGap: CGFloat       = 8
    private let titleSubtitleGap: CGFloat = 8
    // branchHeight 必须等于 StickyTreeConfig.levelHeight,见 CLAUDE.md 的"Layout invariant"。
    // leaf 高度自由,这里 50 用于和部门作视觉区分。
    private let branchHeight: CGFloat     = 44
    private let leafHeight: CGFloat       = 50

    // MARK: Init

    init() {
        super.init(frame: .zero)
        backgroundColor = .systemBackground

        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textAlignment = .right
        subtitleLabel.numberOfLines = 1

        chevronView.tintColor = .tertiaryLabel
        chevronView.contentMode = .center

        separator.backgroundColor = .separator

        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(chevronView)
        addSubview(separator)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: Intrinsic size

    override var intrinsicContentSize: CGSize {
        let isBranch = item.map(OrgRenderer.isBranch) ?? true
        return CGSize(width: UIView.noIntrinsicMetric, height: isBranch ? branchHeight : leafHeight)
    }

    // MARK: Configure

    func configure(with item: OrgItem, level: Int, isExpanded: Bool) {
        self.item = item
        self.level = level
        self.isExpanded = isExpanded

        titleLabel.text = OrgRenderer.title(for: item)
        subtitleLabel.text = OrgRenderer.subtitle(for: item)
        subtitleLabel.isHidden = (OrgRenderer.subtitle(for: item) == nil)

        if OrgRenderer.isBranch(item) {
            titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
            titleLabel.textColor = .label
            chevronView.isHidden = false
            let name = isExpanded ? "chevron.down" : "chevron.right"
            chevronView.image = UIImage(systemName: name)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        } else {
            titleLabel.font = .systemFont(ofSize: 14)
            titleLabel.textColor = .systemBlue
            chevronView.isHidden = true
            chevronView.image = nil
        }

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        // snapshot.level 是 0-indexed(根 = 0),所以缩进直接乘 level,不要再 -1。
        let leftInset  = leadingPadding + CGFloat(max(0, level)) * indentPerLevel
        let rightInset = trailingPadding
        let showChevron = !chevronView.isHidden
        let chevronX = bounds.width - rightInset - chevronSize
        let contentRightEdge = showChevron ? chevronX - chevronGap : bounds.width - rightInset

        subtitleLabel.sizeToFit()
        let subtitleWidth = subtitleLabel.isHidden ? 0 : subtitleLabel.frame.width
        let titleMaxX = subtitleLabel.isHidden
            ? contentRightEdge
            : contentRightEdge - subtitleWidth - titleSubtitleGap

        titleLabel.frame = CGRect(
            x: leftInset,
            y: 0,
            width: max(0, titleMaxX - leftInset),
            height: bounds.height
        )

        if !subtitleLabel.isHidden {
            subtitleLabel.frame = CGRect(
                x: contentRightEdge - subtitleWidth,
                y: 0,
                width: subtitleWidth,
                height: bounds.height
            )
        }

        if showChevron {
            chevronView.frame = CGRect(
                x: chevronX,
                y: (bounds.height - chevronSize) / 2,
                width: chevronSize,
                height: chevronSize
            )
        }

        separator.frame = CGRect(
            x: leftInset,
            y: bounds.height - 0.5,
            width: bounds.width - leftInset,
            height: 0.5
        )
    }
}
