import UIKit
import StickyTreeCore

public final class StickyTreeViewController<Item: Hashable>: UIViewController, UICollectionViewDelegate {

    public nonisolated enum Section: Hashable, Sendable { case main }

    private let config: StickyTreeConfig<Item>
    private let pinViewProvider: (Item, DrawInstruction<Item>) -> UIView
    private let cellProvider: (UICollectionViewCell, Item, Int, Bool) -> Void
    private let initialSnapshot: NSDiffableDataSourceSectionSnapshot<Item>

    /// 居于 safe area 之下的容器,collectionView 和 overlay 都是它的子 view。
    /// 好处:collectionView 不用再管 nav bar / status bar 的 safe area,
    ///      contentInsetAdjustmentBehavior 直接 .never,contentOffset.y=0 就是 rest 状态。
    private let container = UIView()
    private var collectionView: UICollectionView!
    private var overlay: StickyOverlayView<Item>!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var currentSnapshot: NSDiffableDataSourceSectionSnapshot<Item>
    private var computer: StickyChainComputer<DiffableTreeSnapshot<Item>>!

    public init(
        initialSnapshot: NSDiffableDataSourceSectionSnapshot<Item>,
        config: StickyTreeConfig<Item>,
        pinViewProvider: @escaping (Item, DrawInstruction<Item>) -> UIView,
        cellProvider: @escaping (UICollectionViewCell, Item, Int, Bool) -> Void
    ) {
        self.initialSnapshot = initialSnapshot
        self.currentSnapshot = initialSnapshot
        self.config = config
        self.pinViewProvider = pinViewProvider
        self.cellProvider = cellProvider
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupContainer()
        setupCollectionView()
        setupOverlay()
        setupDataSource()

        applyInitialSnapshot()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        container.frame = CGRect(
            x: 0,
            y: view.safeAreaInsets.top,
            width: view.bounds.width,
            height: view.bounds.height - view.safeAreaInsets.top
        )
        collectionView.frame = container.bounds
        overlay.frame = CGRect(
            x: 0, y: 0,
            width: container.bounds.width,
            height: config.levelHeight * 6
        )
    }

    private func setupContainer() {
        view.addSubview(container)
    }

    private func setupCollectionView() {
        var listConfig = UICollectionLayoutListConfiguration(appearance: .plain)
        listConfig.showsSeparators = false     // 由 RowView 自绘,保持 cell 与 pin 一致
        let layout = UICollectionViewCompositionalLayout.list(using: listConfig)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        // container 已经位于 safe area 之下,CV 不需要再自适应 safe area。
        collectionView.contentInsetAdjustmentBehavior = .never
        // 底部留一大块空 inset,让"滚到最底部"之后还能继续向上推,方便调试 sticky。
        collectionView.contentInset.bottom = 400
        collectionView.delegate = self
        container.addSubview(collectionView)
    }

    private func setupOverlay() {
        overlay = StickyOverlayView<Item>(frame: .zero)
        overlay.viewProvider = pinViewProvider
        overlay.tapHandler = { [weak self] item in self?.toggle(item) }
        container.addSubview(overlay)
    }

    private func setupDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewCell, Item>
            { [weak self] cell, _, item in
                guard let self = self else { return }
                let rawLevel = self.currentSnapshot.level(of: item)
                let level = rawLevel >= 0 ? rawLevel : 0
                let expanded = self.currentSnapshot.isExpanded(item)
                self.cellProvider(cell, item, level, expanded)
            }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView)
            { cv, indexPath, item in
                cv.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
            }

        computer = StickyChainComputer<DiffableTreeSnapshot<Item>>(
            levelHeight: config.levelHeight,
            overlayWidth: view.bounds.width
        )
    }

    private func applyInitialSnapshot() {
        var sectionsSnap = NSDiffableDataSourceSnapshot<Section, Item>()
        sectionsSnap.appendSections([.main])
        dataSource.apply(sectionsSnap, animatingDifferences: false)
        dataSource.apply(currentSnapshot, to: Section.main, animatingDifferences: false) { [weak self] in
            self?.refreshOverlay()
        }
    }

    // MARK: Toggle (单入口)

    private func toggle(_ item: Item) {
        guard config.isBranch(item) else { return }
        if currentSnapshot.isExpanded(item) {
            currentSnapshot.collapse([item])
        } else {
            currentSnapshot.expand([item])
        }
        applySnapshot(reconfiguring: [item], animated: true) { [weak self] in
            self?.refreshOverlay()
        }
    }

    /// 应用 section snapshot + 必要时对指定 items 触发 reconfigureItems。
    ///
    /// 为什么要两次 apply:expand/collapse 不改 Item 的 hash,diffable 只会增删变化的行,
    /// **不会**对"还在、但 isExpanded 变了"的 item 重跑 cellProvider。所以手动对被 toggle
    /// 的 item 调 reconfigureItems,让 chevron 方向跟着状态变。
    private func applySnapshot(
        reconfiguring items: [Item],
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        dataSource.apply(currentSnapshot, to: Section.main, animatingDifferences: animated) { [weak self] in
            guard let self = self else { return }
            guard !items.isEmpty else {
                completion?()
                return
            }
            var outer = self.dataSource.snapshot()
            let present = items.filter { outer.itemIdentifiers.contains($0) }
            guard !present.isEmpty else {
                completion?()
                return
            }
            outer.reconfigureItems(present)
            self.dataSource.apply(outer, animatingDifferences: false) {
                completion?()
            }
        }
    }

    // MARK: Refresh (单入口)

    private func refreshOverlay() {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems.sorted()
        let visibleItems = visibleIndexPaths.compactMap { dataSource.itemIdentifier(for: $0) }

        let wrapped = DiffableTreeSnapshot(currentSnapshot)

        // 容器改造后,CV 和 overlay 共享同一个坐标系(container 内),
        // 且 contentInsetAdjustmentBehavior=.never 让 contentOffset.y=0 对应 rest。
        // 所以 pinLineY = contentOffset.y,pinLineOffset 取默认 0。
        overlay.instructions = computer.compute(
            snapshot: wrapped,
            visibleItemsOrdered: visibleItems,
            rectForItem: { [weak self] item in
                guard let self = self,
                      let idx = self.dataSource.indexPath(for: item) else { return nil }
                return self.collectionView.layoutAttributesForItem(at: idx)?.frame
            },
            contentOffset: collectionView.contentOffset,
            isBranch: config.isBranch
        )
    }

    // MARK: UICollectionViewDelegate

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        refreshOverlay()
    }

    // MARK: Debug log — 滚动停止时打印 overlay 状态和可见 cell

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        logScrollState(trigger: "endDecelerating")
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { logScrollState(trigger: "endDragging") }
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        logScrollState(trigger: "endAnimation")
    }

    private func logScrollState(trigger: String) {
        let offset = collectionView.contentOffset
        let inset  = collectionView.contentInset
        var lines: [String] = []
        lines.append("[scroll \(trigger)] offset.y=\(fmtNum(offset.y)) "
                     + "contentSize.h=\(fmtNum(collectionView.contentSize.height)) "
                     + "inset.top/bottom=\(fmtNum(inset.top))/\(fmtNum(inset.bottom))")

        lines.append("  overlay pins (\(overlay.instructions.count)):")
        for (i, instr) in overlay.instructions.enumerated() {
            let title = config.title(instr.item)
            lines.append("    [\(i)] \"\(title)\" lvl=\(instr.level) frame=\(fmtRect(instr.frame))")
        }

        let ips = collectionView.indexPathsForVisibleItems.sorted()
        lines.append("  visible cells (\(ips.count)):")
        for (i, ip) in ips.enumerated() {
            guard let item = dataSource.itemIdentifier(for: ip) else { continue }
            let kind = config.isBranch(item) ? "dept   " : "contact"
            let title = config.title(item)
            let frame = collectionView.layoutAttributesForItem(at: ip)?.frame ?? .zero
            lines.append("    [\(i)] row=\(ip.row) \(kind) \"\(title)\" frame=\(fmtRect(frame))")
        }
        print(lines.joined(separator: "\n"))
    }

    private func fmtNum(_ v: CGFloat) -> String {
        String(format: "%.1f", Double(v))
    }

    private func fmtRect(_ r: CGRect) -> String {
        "(\(fmtNum(r.origin.x)),\(fmtNum(r.origin.y)) \(fmtNum(r.size.width))×\(fmtNum(r.size.height)))"
    }

    public func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        cv.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if config.isBranch(item) { toggle(item) }
    }

    // MARK: Public API — 滚动到指定节点,自动展开所有祖先

    public func scrollToItem(_ item: Item, animated: Bool = true) {
        var ancestors: [Item] = []
        var cursor: Item? = currentSnapshot.parent(of: item)
        while let c = cursor {
            ancestors.append(c)
            cursor = currentSnapshot.parent(of: c)
        }
        if !ancestors.isEmpty {
            currentSnapshot.expand(ancestors)
        }
        applySnapshot(reconfiguring: ancestors, animated: false) { [weak self] in
            guard let self = self,
                  let idx = self.dataSource.indexPath(for: item) else { return }
            self.collectionView.scrollToItem(at: idx, at: .top, animated: animated)
            self.refreshOverlay()
        }
    }
}
