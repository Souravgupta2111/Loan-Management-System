import SwiftUI

// MARK: - Typography (design.md §3)
// Font Family: SF Pro (system default)

extension Font {
    /// 48pt Bold — Dashboard total amount
    static let heroAmount   = Font.system(size: 48, weight: .bold, design: .rounded)
    /// 34pt Bold — Loan amount, EMI amount
    static let largeAmount  = Font.system(size: 34, weight: .bold, design: .rounded)
    /// 28pt Bold — Screen titles
    static let sectionTitle = Font.system(size: 28, weight: .bold)
    /// 22pt Semibold — Card headings
    static let cardTitle    = Font.system(size: 22, weight: .semibold)
    /// 17pt Medium — Primary body text
    static let bodyLarge    = Font.system(size: 17, weight: .medium)
    /// 15pt Regular — Standard body text
    static let bodyRegular  = Font.system(size: 15, weight: .regular)
    /// 13pt Medium — Form labels, captions
    static let label        = Font.system(size: 13, weight: .medium)
    /// 12pt Regular — Timestamps, footnotes
    static let caption2     = Font.system(size: 12, weight: .regular)
    /// 11pt Semibold — Status badges, tags
    static let badge        = Font.system(size: 11, weight: .semibold)
    /// 16pt Medium — Decimal places on amounts (superscript)
    static let amountSuper  = Font.system(size: 16, weight: .medium)
}

// MARK: - Spacing (design.md §4)

enum Spacing {
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 24
    static let xxxl: CGFloat = 32
}

enum Corner {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let pill:  CGFloat = 999
}
