import Foundation

struct CoupleSettings: Codable, Sendable {
    var defaultSplitType: SplitType
    var categorySplits: [TransactionCategory: SplitType]  // Override per category

    static let defaultSettings = CoupleSettings(
        defaultSplitType: .equal,
        categorySplits: [:]
    )

    func splitFor(category: TransactionCategory) -> SplitType {
        categorySplits[category] ?? defaultSplitType
    }
}
