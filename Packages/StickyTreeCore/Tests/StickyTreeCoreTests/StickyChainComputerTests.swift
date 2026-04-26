import XCTest
import CoreGraphics
@testable import StickyTreeCore

final class StickyChainComputerTests: XCTestCase {
    let computer = StickyChainComputer<MockSnapshot<String>>(
        levelHeight: 44,
        overlayWidth: 375
    )

    // Case 1: 可见列表为空 → 无 pin
    func test_empty_visibleItems_returnsEmptyInstructions() {
        let snap = MockSnapshot<String>()
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: [],
            rectForItem: { _ in nil },
            contentOffset: .zero,
            isBranch: { _ in true }
        )
        XCTAssertEqual(result.count, 0)
    }

    // Case 2: 只有一个根分支在最顶部,chain 长度 = 1
    func test_singleRootBranch_atTop_returnsOnePin() {
        let snap = MockSnapshot<String>.tree([
            ("root", nil, 1)
        ])
        let rects: [String: CGRect] = [
            "root": CGRect(x: 0, y: 0, width: 375, height: 44)
        ]
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["root"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 10),   // 滚了 10pt
            isBranch: { _ in true }
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].item, "root")
        XCTAssertEqual(result[0].frame, CGRect(x: 0, y: 0, width: 375, height: 44))
        XCTAssertEqual(result[0].level, 1)
    }

    // Case 3: 3 层深的分支,根、child 已滚过,grand 已经开始滚
    func test_midLevelBranch_atTop_returnsFullAncestorChain() {
        let snap = MockSnapshot<String>.tree([
            ("root", nil, 1),
            ("child", "root", 2),
            ("grand", "child", 3)
        ])
        let rects: [String: CGRect] = [
            "root":  CGRect(x: 0, y:  0,  width: 375, height: 44),
            "child": CGRect(x: 0, y: 44,  width: 375, height: 44),
            "grand": CGRect(x: 0, y: 88,  width: 375, height: 44)
        ]
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["root", "child", "grand"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 100),  // grand.minY=88 < 100,已滚进 pinned 区
            isBranch: { _ in true }
        )
        XCTAssertEqual(result.map(\.item), ["root", "child", "grand"])
        XCTAssertEqual(result[0].frame.origin.y, 0)
        XCTAssertEqual(result[1].frame.origin.y, 44)
        XCTAssertEqual(result[2].frame.origin.y, 88)
    }

    // Case 4: 叶子在顶(contact 属于某部门),chain 只含祖先分支
    func test_leafAtTop_returnsAncestorBranchesOnly() {
        let snap = MockSnapshot<String>.tree([
            ("deptA", nil, 1),
            ("personX", "deptA", 2)
        ])
        let rects: [String: CGRect] = [
            "deptA":    CGRect(x: 0, y:  0, width: 375, height: 44),
            "personX":  CGRect(x: 0, y: 44, width: 375, height: 44)
        ]
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["deptA", "personX"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 50),    // deptA 半滚出,personX 在顶
            isBranch: { $0 == "deptA" }              // personX 是叶子
        )
        XCTAssertEqual(result.map(\.item), ["deptA"])
    }

    // Case 5: 完全滚到顶(contentOffset.y = 0),cell 还在自然位置,不该画 pin
    func test_scrollAtTop_returnsEmptyChain() {
        let snap = MockSnapshot<String>.tree([
            ("root", nil, 1)
        ])
        let rects: [String: CGRect] = [
            "root": CGRect(x: 0, y: 0, width: 375, height: 44)
        ]
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["root"],
            rectForItem: { rects[$0] },
            contentOffset: .zero,
            isBranch: { _ in true }
        )
        XCTAssertEqual(result.count, 0, "初始状态 cell 未滚动,不显示 overlay")
    }

    // Case 6: 展开的分支 hasSeparator = true;收起的 = false
    func test_hasSeparator_reflectsExpansionState() {
        var snap = MockSnapshot<String>.tree([
            ("root", nil, 1)
        ])
        snap.expandedItems = ["root"]
        let rects: [String: CGRect] = [
            "root": CGRect(x: 0, y: 0, width: 375, height: 44)
        ]
        let expanded = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["root"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 10),
            isBranch: { _ in true }
        )
        XCTAssertTrue(expanded[0].hasSeparator)

        var collapsed = snap
        collapsed.expandedItems = []
        let result2 = computer.compute(
            snapshot: collapsed,
            visibleItemsOrdered: ["root"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 10),
            isBranch: { _ in true }
        )
        XCTAssertFalse(result2[0].hasSeparator)
    }

    // Case 7: 同级 peer 逼近,最深 pin 被连续推上(未完全推出)
    func test_pushOut_sameLevelPeer_partialPush() {
        let snap = MockSnapshot<String>.tree([
            ("root",    nil,    1),
            ("deptA",   "root", 2),
            ("deptB",   "root", 2)    // deptA 的同级兄弟
        ])
        let rects: [String: CGRect] = [
            "root":  CGRect(x: 0, y:  0, width: 375, height: 44),
            "deptA": CGRect(x: 0, y: 44, width: 375, height: 44),
            "deptB": CGRect(x: 0, y: 170, width: 375, height: 44)  // 开始逼近
        ]
        // contentOffset.y = 96 → pinnedBottomY = 96 + 2*44 = 184
        // deptB.minY = 170 < 184 → collisionDistance = 170 - 184 = -14
        // → deepest(deptA) frame.y = 44 - 14 = 30
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["root", "deptA", "deptB"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 96),
            isBranch: { _ in true }
        )
        XCTAssertEqual(result.map(\.item), ["root", "deptA"])
        XCTAssertEqual(result[0].frame.origin.y, 0, "root pin 不动")
        XCTAssertEqual(result[1].frame.origin.y, 30, accuracy: 0.01, "deptA 被 deptB 推上 14pt")
    }

    // Case 8: 上级 peer 逼近(子树结束),最深 pin 被推出
    func test_pushOut_ancestorLevelPeer_pushes() {
        let snap = MockSnapshot<String>.tree([
            ("rootA",   nil,    1),
            ("deptA1",  "rootA", 2),
            ("rootB",   nil,    1)     // 爷爷辈 peer
        ])
        let rects: [String: CGRect] = [
            "rootA":  CGRect(x: 0, y:  0, width: 375, height: 44),
            "deptA1": CGRect(x: 0, y: 44, width: 375, height: 44),
            "rootB":  CGRect(x: 0, y: 120, width: 375, height: 44)
        ]
        // contentOffset.y = 50 → pinnedBottomY = 50 + 88 = 138
        // rootB.minY = 120 < 138 → collisionDistance = 120 - 138 = -18
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["rootA", "deptA1", "rootB"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 50),
            isBranch: { _ in true }
        )
        XCTAssertEqual(result.map(\.item), ["rootA", "deptA1"])
        XCTAssertEqual(result[1].frame.origin.y, 44 - 18, accuracy: 0.01)
    }

    // Case 9: 紧跟的是子孙,不推(deepest.level < 子孙.level)
    func test_pushOut_descendantFollowing_doesNotPush() {
        let snap = MockSnapshot<String>.tree([
            ("root",   nil,    1),
            ("child",  "root", 2)
        ])
        let rects: [String: CGRect] = [
            "root":  CGRect(x: 0, y:   0, width: 375, height: 44),
            "child": CGRect(x: 0, y: 200, width: 375, height: 44)   // 放远,避开 Step 2.5 扩链区
        ]
        // chain = [root],pinnedBottomY = 10 + 44 = 54
        // child.minY = 200 > 54 → Step 2.5 不扩链
        // Step 4:child.level(2) > deepest.level(1),跳过 peer 筛选,无 push
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["root", "child"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 10),
            isBranch: { _ in true }
        )
        XCTAssertEqual(result.map(\.item), ["root"])
        XCTAssertEqual(result[0].frame.origin.y, 0, "无推顶,稳定在 slot 顶")
    }

    // Case: Step 4 迭代 —— sibling swap 后,上级 peer 还能继续对新 deepest 做 partial push
    // 复现用户报告:offset=768.7,chain=[A, AA, AAA, AAAA] → swap 成 [..., AAAB] →
    // 需要进一步用 AAB(AAA 的兄弟,level 2)对 AAAB partial push。
    func test_pushOut_siblingSwapThenAncestorPartialPush() {
        let snap = MockSnapshot<String>.tree([
            ("A",     nil,   0),
            ("AA",    "A",   1),
            ("AAA",   "AA",  2),
            ("AAAA",  "AAA", 3),
            ("AAAA2", "AAAA",4),   // leaf,fallback 锚点
            ("AAAB",  "AAA", 3),   // AAAA 的同级兄弟
            ("AAB",   "AA",  2)    // AAA 的同级兄弟(上级 peer 对 AAAB)
        ])
        let rects: [String: CGRect] = [
            "AAAA2": CGRect(x: 0, y: 748, width: 375, height: 44),
            "AAAB":  CGRect(x: 0, y: 880, width: 375, height: 44),
            "AAB":   CGRect(x: 0, y: 924, width: 375, height: 44)
        ]
        // pinLineY=768.7,锚点 fallback=AAAA2,chain=[A, AA, AAA, AAAA]
        // pinnedBottomY = 768.7 + 4*44 = 944.7
        // Iter 1: peer=AAAB,collision=880-944.7=-64.7 ≤ -44,同级(parent=AAA)→ swap → chain[3]=AAAB
        // Iter 2: peer=AAB,collision=924-944.7=-20.7(partial)→ shift frames[3] by -20.7
        //         → frames[3].y = 132 - 20.7 = 111.3
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["AAAA2", "AAAB", "AAB"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 768.7),
            isBranch: { ["A", "AA", "AAA", "AAAA", "AAAB", "AAB"].contains($0) }
        )
        XCTAssertEqual(result.map(\.item), ["A", "AA", "AAA", "AAAB"], "swap 后 chain 长度不变")
        XCTAssertEqual(result[3].frame.origin.y, 111.3, accuracy: 0.01, "AAAB 被 AAB 继续 partial push 20.7pt")
    }

    // Case: Step 2.5 — 子分支顶已进入 pin 区即应扩链(不要求 cell 完全在区内)
    // 复现用户报告:offset=419.3,AB 已 pin,ABA(AB 的子分支)顶在 pin 区内,
    // chain 应扩到 [A, AB, ABA],而不是停在 [A, AB]。
    func test_step25_extendsChain_whenBranchTopEntersRegion() {
        let snap = MockSnapshot<String>.tree([
            ("A",    nil,  0),
            ("AB",   "A",  1),
            ("AB2",  "AB", 2),    // leaf,fallback 锚点
            ("ABA",  "AB", 2)     // AB 的子分支
        ])
        let rects: [String: CGRect] = [
            "AB2":  CGRect(x: 0, y: 396, width: 375, height: 44),
            "ABA":  CGRect(x: 0, y: 484, width: 375, height: 44)
        ]
        // pinLineY=419.3,锚点 fallback=AB2 → chain=[A, AB]
        // regionBottom = 419.3 + 2*44 = 507.3
        // ABA.minY=484(在区内) ✓;ABA.maxY=528 > 507.3(旧 criteria 会漏)
        // 新 criteria 看 minY → 纳入 → chain=[A, AB, ABA]
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["AB2", "ABA"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 419.3),
            isBranch: { $0 == "A" || $0 == "AB" || $0 == "ABA" }
        )
        XCTAssertEqual(result.map(\.item), ["A", "AB", "ABA"])
        XCTAssertEqual(result[2].frame.origin.y, 88, "ABA 在 slot 2(88pt)")
    }

    // Case 10: 最后 item 就是 topItem,后面没有 peer → 不推,chain 稳定
    func test_noPeerAfter_topItem_doesNotCrash() {
        let snap = MockSnapshot<String>.tree([
            ("root", nil, 1)
        ])
        let rects: [String: CGRect] = [
            "root": CGRect(x: 0, y: 0, width: 375, height: 44)
        ]
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["root"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 10),
            isBranch: { _ in true }
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].frame.origin.y, 0)
    }

    // Case: push-out 完全推出时,若 peer 是同级兄弟,应接替 deepest 的 slot
    // (而不是直接 removeLast 让 chain 缩短,导致 peer 也不在 overlay 里)
    // 复现用户场景:offset.y=1163.7,chain=[A, AA, AAB],peer=AAC
    func test_pushOut_siblingFullPush_swapsPeerIntoChain() {
        let snap = MockSnapshot<String>.tree([
            ("A",    nil,  0),
            ("AA",   "A",  1),
            ("AAB",  "AA", 2),
            ("AAB5", "AAB", 3),   // leaf,作为 fallback 锚点
            ("AAC",  "AA", 2)     // AAB 的同级兄弟
        ])
        let rects: [String: CGRect] = [
            "AAB5": CGRect(x: 0, y: 1144, width: 375, height: 44),
            "AAC":  CGRect(x: 0, y: 1188, width: 375, height: 44)
        ]
        // pinLineY=1163.7,锚点 fallback 取 AAB5 → chain=[A, AA, AAB]
        // pinnedBottomY = 1163.7 + 3*44 = 1295.7
        // AAC.minY=1188 < 1295.7 → collision = -107.7 ≤ -44 → 同级兄弟 swap
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["AAB5", "AAC"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 1163.7),
            isBranch: { $0 == "A" || $0 == "AA" || $0 == "AAB" || $0 == "AAC" }
        )
        XCTAssertEqual(result.map(\.item), ["A", "AA", "AAC"], "AAC 接替 AAB 占 deepest slot")
        XCTAssertEqual(result[2].frame.origin.y, 88, "AAC 停在原 slot(不位移)")
    }

    // Case: push-out 完全推出时,若 peer 是上级兄弟(跨子树结束),仍应 removeLast
    func test_pushOut_ancestorSiblingFullPush_shrinksChain() {
        let snap = MockSnapshot<String>.tree([
            ("A",    nil,  0),
            ("AA",   "A",  1),
            ("AA1",  "AA", 2),   // leaf,锚点
            ("B",    nil,  0)    // A 的兄弟(上级 peer)
        ])
        let rects: [String: CGRect] = [
            "AA1": CGRect(x: 0, y: 44, width: 375, height: 44),
            "B":   CGRect(x: 0, y: 88, width: 375, height: 44)
        ]
        // pinLineY=50,chain=[A, AA],pinnedBottomY = 50 + 88 = 138
        // B.minY=88 < 138 → collision = -50 ≤ -44 → 上级 peer,removeLast
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["AA1", "B"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 50),
            isBranch: { $0 == "A" || $0 == "AA" || $0 == "B" }
        )
        XCTAssertEqual(result.map(\.item), ["A"], "跨子树时 chain 缩短,不 swap")
    }

    // Case 11: 视口首行是叶子,祖先 branch 已完全滚出可见区 —— 仍应显示祖先链
    // Regression for VSCode-comparison 的 anchor 差异:主路径命中不到时,
    // fallback 必须覆盖"可见区里仍有 branch、但全在 pin 线下方"的情形。
    func test_leafAtTop_ancestorsOffScreen_returnsAncestorChain() {
        let snap = MockSnapshot<String>.tree([
            ("A",    nil,  1),
            ("AA",   "A",  2),
            ("AA1",  "AA", 3),   // leaf
            ("AAA",  "AA", 3),   // branch sibling of AA1
            ("AAB",  "AA", 3)    // branch sibling
        ])
        // 视口布局:A 和 AA 都已滚出可见区,视口首行是 AA1,
        //          可见区里还有 AAA / AAB(都是 branch,但 minY > pinLineY)。
        let rects: [String: CGRect] = [
            "AA1": CGRect(x: 0, y: 308, width: 375, height: 44),
            "AAA": CGRect(x: 0, y: 484, width: 375, height: 44),
            "AAB": CGRect(x: 0, y: 528, width: 375, height: 44)
        ]
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["AA1", "AAA", "AAB"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 338.7),   // pinLineY = 338.7
            isBranch: { $0 == "A" || $0 == "AA" || $0 == "AAA" || $0 == "AAB" }
        )
        XCTAssertEqual(result.map(\.item), ["A", "AA"], "叶子的父链 = A → AA")
        XCTAssertEqual(result[0].frame.origin.y, 0)
        XCTAssertEqual(result[1].frame.origin.y, 44)
    }

    // Case 12: 视口首行本身是 branch 但尚未越过 pin 线 —— 不能把它画到 overlay
    // (否则 overlay 上的自己会和下面的 cell 重复)
    func test_topIsBranchBelowPinLine_doesNotStickSelf() {
        let snap = MockSnapshot<String>.tree([
            ("root", nil, 1)
        ])
        // root.minY = 40,pinLineY = 20,root 还差 20pt 才到顶。
        let rects: [String: CGRect] = [
            "root": CGRect(x: 0, y: 40, width: 375, height: 44)
        ]
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["root"],
            rectForItem: { rects[$0] },
            contentOffset: CGPoint(x: 0, y: 20),
            isBranch: { _ in true }
        )
        XCTAssertEqual(result.count, 0, "branch 未到 pin 线不该吸顶")
    }

    func test_rectForItem_nilForItem_isSkipped() {
        let snap = MockSnapshot<String>.tree([
            ("root", nil, 1)
        ])
        // 模拟只有 root 可见但尚未布局完成,所有 rect 返 nil
        let result = computer.compute(
            snapshot: snap,
            visibleItemsOrdered: ["root"],
            rectForItem: { _ in nil },
            contentOffset: CGPoint(x: 0, y: 10),
            isBranch: { _ in true }
        )
        XCTAssertEqual(result.count, 0, "无布局 → 无 topItem → 空输出")
    }
}
