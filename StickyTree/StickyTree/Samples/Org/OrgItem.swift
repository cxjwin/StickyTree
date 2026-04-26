import Foundation

/// 部门。`code` 形如 "A" / "AA" / "AAC",字母个数即层级。
struct Dept {
    let code: String
}

/// 员工。`code` 形如 "A1" / "AAC2",字母前缀即所属部门。
struct Contact {
    let code: String
}

enum OrgItem {
    case dept(Dept)
    case contact(Contact)

    var code: String {
        switch self {
        case .dept(let d):    return d.code
        case .contact(let c): return c.code
        }
    }
}

// MARK: - Hashable & Sendable
// conformance 放在 nonisolated extension 里,满足
// NSDiffableDataSourceSectionSnapshot 对 ItemIdentifierType: Sendable 的要求
// (否则默认 main-actor-isolated 无法通过 Swift 6 检查)

nonisolated extension Dept: Hashable, Sendable {}
nonisolated extension Contact: Hashable, Sendable {}
nonisolated extension OrgItem: Hashable, Sendable {}
