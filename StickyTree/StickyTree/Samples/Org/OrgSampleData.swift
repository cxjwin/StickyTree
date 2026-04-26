import UIKit
import StickyTreeCore

/// Mock 数据用"字母+数字"记法构造,日志里的 code 直接对应
/// `docs/superpowers/specs/2026-04-18-tree-notation.md` 的层级。
///
/// 初始可见形态(↓ 展开 / → 收起):
/// ```
/// A ↓
///   A1..A5
///   AA ↓
///     AA1..AA4
///     AAA →
///     AAB →
///     AAC ↓
///       AAC1..AAC4
///       AACA →
///     AAD →
///   AB →
///   AC →
/// B →
/// C ↓
///   CA →
///   CB →
///   CC ↓
///     CCA ↓
///       CCA1..CCA2
///       CCAA →
///     CCB →
///   CD →
/// ```
/// 所有 → 分支下都预置了子节点(部分还有下级分支),展开可见完整结构。
enum OrgSampleData {
    static func makeSnapshot() -> NSDiffableDataSourceSectionSnapshot<OrgItem> {
        var snap = NSDiffableDataSourceSectionSnapshot<OrgItem>()

        // Root: A / B / C
        let A = dept("A"), B = dept("B"), C = dept("C")
        snap.append([A, B, C])

        // A 下
        let AA = dept("AA"), AB = dept("AB"), AC = dept("AC")
        snap.append(
            contacts("A1", "A2", "A3", "A4", "A5") + [AA, AB, AC],
            to: A
        )

        // AA 下
        let AAA = dept("AAA"), AAB = dept("AAB"), AAC = dept("AAC"), AAD = dept("AAD")
        snap.append(
            contacts("AA1", "AA2", "AA3", "AA4") + [AAA, AAB, AAC, AAD],
            to: AA
        )

        // AAA 下(收起,不可见)
        let AAAA = dept("AAAA"), AAAB = dept("AAAB")
        snap.append(
            contacts("AAA1", "AAA2", "AAA3") + [AAAA, AAAB],
            to: AAA
        )
        snap.append(contacts("AAAA1", "AAAA2", "AAAA3", "AAAA4"), to: AAAA)
        snap.append(contacts("AAAB1", "AAAB2", "AAAB3"), to: AAAB)

        // AAB 下(收起,不可见)
        snap.append(contacts("AAB1", "AAB2", "AAB3", "AAB4", "AAB5"), to: AAB)

        // AAC 下
        let AACA = dept("AACA")
        snap.append(
            contacts("AAC1", "AAC2", "AAC3", "AAC4") + [AACA],
            to: AAC
        )
        // AACA 下(收起,不可见)
        snap.append(contacts("AACA1", "AACA2", "AACA3", "AACA4"), to: AACA)

        // AAD 下(收起,不可见)
        snap.append(contacts("AAD1", "AAD2", "AAD3"), to: AAD)

        // AB 下(收起,不可见)
        let ABA = dept("ABA")
        snap.append(contacts("AB1", "AB2", "AB3") + [ABA], to: AB)
        snap.append(contacts("ABA1", "ABA2", "ABA3"), to: ABA)

        // AC 下(收起,不可见)
        snap.append(contacts("AC1", "AC2", "AC3", "AC4"), to: AC)

        // B 下(收起,不可见)
        let BA = dept("BA"), BB = dept("BB")
        snap.append(
            contacts("B1", "B2", "B3", "B4", "B5", "B6") + [BA, BB],
            to: B
        )
        snap.append(contacts("BA1", "BA2", "BA3", "BA4"), to: BA)
        snap.append(contacts("BB1", "BB2", "BB3"), to: BB)

        // C 下
        let CA = dept("CA"), CB = dept("CB"), CC = dept("CC"), CD = dept("CD")
        snap.append([CA, CB, CC, CD], to: C)
        snap.append(contacts("CA1", "CA2", "CA3", "CA4"), to: CA)
        snap.append(contacts("CB1", "CB2", "CB3"), to: CB)

        // CC 下
        let CCA = dept("CCA"), CCB = dept("CCB")
        snap.append([CCA, CCB], to: CC)

        // CCA 下
        let CCAA = dept("CCAA")
        snap.append(contacts("CCA1", "CCA2") + [CCAA], to: CCA)
        snap.append(contacts("CCAA1", "CCAA2", "CCAA3", "CCAA4"), to: CCAA)

        // CCB 下(收起,不可见)
        snap.append(contacts("CCB1", "CCB2", "CCB3"), to: CCB)

        // CD 下(收起,不可见)
        snap.append(contacts("CD1", "CD2", "CD3", "CD4", "CD5"), to: CD)

        // 初始展开:A, AA, AAC, C, CC, CCA
        snap.expand([A, AA, AAC, C, CC, CCA])

        return snap
    }

    // MARK: helpers

    private static func dept(_ code: String) -> OrgItem {
        .dept(Dept(code: code))
    }

    private static func contact(_ code: String) -> OrgItem {
        .contact(Contact(code: code))
    }

    private static func contacts(_ codes: String...) -> [OrgItem] {
        codes.map { .contact(Contact(code: $0)) }
    }
}
