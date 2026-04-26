import CoreGraphics

public struct StickyChainComputer<Snapshot: SnapshotReading> {
    public typealias Item = Snapshot.Item

    public let levelHeight: CGFloat
    public let overlayWidth: CGFloat

    public init(levelHeight: CGFloat, overlayWidth: CGFloat) {
        self.levelHeight = levelHeight
        self.overlayWidth = overlayWidth
    }

    public func compute(
        snapshot: Snapshot,
        visibleItemsOrdered: [Item],
        rectForItem: (Item) -> CGRect?,
        contentOffset: CGPoint,
        pinLineOffset: CGFloat = 0,     // overlay 顶部在 CV 坐标中相对 contentOffset.y 的偏移
        isBranch: (Item) -> Bool
    ) -> [DrawInstruction<Item>] {

        // "锁线" = overlay 顶部在 CV 坐标中的位置。cell.minY ≤ pinLineY 即视为已滚至/滚过 overlay 顶。
        // 默认 pinLineOffset=0 表示 overlay 就在 CV 顶(无 nav bar 等遮挡)。
        let pinLineY = contentOffset.y + pinLineOffset

        // Gate: 还没开始"视觉滚动"(pinLineY ≤ 0 等价于 visualScroll ≤ 0)→ 整块 overlay 不画。
        if pinLineY < 0.001 { return [] }

        // Step 1: 选锚点
        //   主路径:最后一个 rect.minY ≤ pinLineY 的分支("最深已吸顶的 branch",chain 从它起)
        //   回退:  视口首行(第一个 maxY > pinLineY 的 item)。覆盖两类情况:
        //          a) 视口首行是叶子,其祖先 branch 已完全滚出可见区
        //          b) 视口内所有可见 branch 的 minY 都 > pinLineY,尚未吸顶
        //          此时 chain 从"锚点的最近已吸顶祖先"开始(见 Step 2 的 cursor 初始化)。
        let anchorIdx: Int = {
            if let idx = visibleItemsOrdered.lastIndex(where: {
                guard isBranch($0), let r = rectForItem($0) else { return false }
                return r.minY <= pinLineY
            }) { return idx }
            if let idx = visibleItemsOrdered.firstIndex(where: {
                guard let r = rectForItem($0) else { return false }
                return r.maxY > pinLineY
            }) { return idx }
            return -1
        }()
        guard anchorIdx >= 0 else { return [] }
        let topItem = visibleItemsOrdered[anchorIdx]
        let topIdx = anchorIdx

        // Step 2: 爬父链(根在前,叶在后)
        // cursor 起点:
        //   - topItem 是已越过 pin 线的 branch → 从它本身起
        //   - topItem 是叶子 / 未越过 pin 线的 branch → 从它的 parent 起
        //     (fallback 会挑到"branch 但 minY > pinLineY"的情况,不能把它算进 chain,
        //      否则会把尚未吸顶的自己画到 overlay 上,和下面的 cell 重复显示)
        var chain: [Item] = []
        var cursor: Item? = {
            if isBranch(topItem),
               let r = rectForItem(topItem),
               r.minY <= pinLineY {
                return topItem
            }
            return snapshot.parent(of: topItem)
        }()
        while let c = cursor {
            chain.append(c)
            cursor = snapshot.parent(of: c)
        }
        chain.reverse()

        guard !chain.isEmpty else { return [] }

        // Step 2.5: 迭代下钻 — 把"cell 顶已进入当前 pin 区"的直系子孙分支纳入链。
        // 判定:branch.minY ∈ [pinLineY, regionBottom](顶进入即可,不要求 cell 完全在区里)。
        //
        // 之所以不要求 cell 整个在 pin 区里:那样会漏掉"branch 顶已在 pin 区、
        // 但底部还在 overlay 下方"的常见情况,导致 overlay 缺一层。
        var extensionCursorIdx = topIdx    // push-out 时也以这个更新后的 idx 为锚
        while let deepest = chain.last {
            let regionBottom = pinLineY + CGFloat(chain.count) * levelHeight
            let candidateIdx = visibleItemsOrdered.firstIndex { item in
                guard isBranch(item),
                      !chain.contains(item),
                      snapshot.parent(of: item) == deepest,
                      let r = rectForItem(item),
                      r.minY >= pinLineY,
                      r.minY <= regionBottom else { return false }
                return true
            }
            guard let idx = candidateIdx else { break }
            chain.append(visibleItemsOrdered[idx])
            extensionCursorIdx = idx
        }

        // Step 3: 给每层分配 overlay 坐标下的 slot
        var frames: [CGRect] = chain.enumerated().map { idx, _ in
            CGRect(
                x: 0,
                y: CGFloat(idx) * levelHeight,
                width: overlayWidth,
                height: levelHeight
            )
        }

        // Step 4: 推顶修正(迭代)—— 处理"多级连锁 push":
        //   - 同级兄弟全推 → swap chain[last]=peer,advance tail,继续用新 deepest 对下个 peer 判定
        //   - 上级 peer 全推 → removeLast,chain 缩短,继续用新 deepest 对同一 peer 判定
        //   - 部分 push  → 位移 frames[last],break(后续 peer 离得更远,不累加)
        //
        // 典型场景:chain=[A, AA, AAA, AAAA],AAAB(AAAA 兄弟)触发 sibling swap 后,
        // AAB(AAA 兄弟)还能继续对新 deepest=AAAB 做 partial push。
        var effectiveTopIdx = extensionCursorIdx
        while chain.count >= 1, effectiveTopIdx + 1 < visibleItemsOrdered.count {
            guard let deepest = chain.last,
                  let deepestLevel = snapshot.level(of: deepest) else { break }

            let pinnedBottomY = pinLineY + CGFloat(chain.count) * levelHeight
            let tailStart = effectiveTopIdx + 1

            guard let peerIdx = visibleItemsOrdered[tailStart...].firstIndex(where: { item in
                guard isBranch(item), let lvl = snapshot.level(of: item) else { return false }
                return lvl <= deepestLevel
            }) else { break }

            let peer = visibleItemsOrdered[peerIdx]
            guard let peerRect = rectForItem(peer), peerRect.minY < pinnedBottomY else { break }

            let collisionDistance = peerRect.minY - pinnedBottomY   // 负值
            if collisionDistance <= -levelHeight {
                let peerParent = snapshot.parent(of: peer)
                let deepestParent = snapshot.parent(of: deepest)
                let peerLevel = snapshot.level(of: peer)
                if peerLevel == deepestLevel, peerParent == deepestParent {
                    // 同级兄弟:peer 接替 deepest 的 slot(frame 不动),tail 前进
                    chain[chain.count - 1] = peer
                    effectiveTopIdx = peerIdx
                    continue
                } else {
                    // 非同级:chain 缩短,effectiveTopIdx 不动(同一 peer 继续对新 deepest 作用)
                    chain.removeLast()
                    frames.removeLast()
                    continue
                }
            } else {
                // 部分 push:位移 deepest frame,结束
                frames[frames.count - 1].origin.y += collisionDistance
                break
            }
        }

        // Step 5: 组装 instructions
        return zip(chain, frames).map { item, frame in
            DrawInstruction(
                item: item,
                frame: frame,
                level: snapshot.level(of: item) ?? 0,
                hasSeparator: snapshot.isExpanded(item)
            )
        }
    }
}
