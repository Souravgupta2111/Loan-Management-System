import SwiftUI

// MARK: - Typography (design.md §3)
// Font Family: SF Pro (system default)

// Every token is built on a system TextStyle so it scales with the user's
// Dynamic Type setting (Settings ▸ Accessibility ▸ Larger Text). Weight and
// rounded design are preserved to keep the original visual hierarchy.
extension Font {
    /// Dashboard total amount — scales from ~large title
    static let heroAmount   = Font.system(.largeTitle, design: .rounded).weight(.bold)
    /// Loan amount, EMI amount
    static let largeAmount  = Font.system(.title, design: .rounded).weight(.bold)
    /// Screen titles
    static let sectionTitle = Font.system(.title, design: .default).weight(.bold)
    /// Card headings
    static let cardTitle    = Font.system(.title2, design: .default).weight(.semibold)
    /// Primary body text
    static let bodyLarge    = Font.system(.body, design: .default).weight(.medium)
    /// Standard body text
    static let bodyRegular  = Font.system(.subheadline, design: .default).weight(.regular)
    /// Form labels, captions
    static let label        = Font.system(.footnote, design: .default).weight(.medium)
    /// Timestamps, footnotes
    static let caption2     = Font.system(.caption, design: .default).weight(.regular)
    /// Status badges, tags
    static let badge        = Font.system(.caption2, design: .default).weight(.semibold)
    /// Decimal places on amounts (superscript)
    static let amountSuper  = Font.system(.callout, design: .default).weight(.medium)
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
