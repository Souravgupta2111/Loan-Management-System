import SwiftUI

// MARK: - Typography (iPad-optimized scale)
// Larger sizes suited for iPad display density

// Every token is built on a system TextStyle so it scales with the user's
// Dynamic Type setting (Settings ▸ Accessibility ▸ Larger Text). Weight and
// rounded design are preserved to keep the original iPad-scaled hierarchy.
extension Font {
    /// Dashboard hero numbers
    static let staffHeroAmount   = Font.system(.largeTitle, design: .rounded).weight(.bold)
    /// Large metric values
    static let staffLargeAmount  = Font.system(.title, design: .rounded).weight(.bold)
    /// Screen titles
    static let staffTitle        = Font.system(.title, design: .default).weight(.bold)
    /// Section headings
    static let staffSectionTitle = Font.system(.title2, design: .default).weight(.semibold)
    /// Card titles
    static let staffCardTitle    = Font.system(.title3, design: .default).weight(.semibold)
    /// Primary body text
    static let staffBody         = Font.system(.body, design: .default).weight(.medium)
    /// Standard body text
    static let staffBodyRegular  = Font.system(.callout, design: .default).weight(.regular)
    /// Form labels
    static let staffLabel        = Font.system(.subheadline, design: .default).weight(.medium)
    /// Captions, timestamps
    static let staffCaption      = Font.system(.footnote, design: .default).weight(.regular)
    /// Status badges, tags
    static let staffBadge        = Font.system(.caption, design: .default).weight(.semibold)
    /// Fine print
    static let staffFinePrint    = Font.system(.caption2, design: .default).weight(.regular)
    /// Button text
    static let staffButton       = Font.system(.body, design: .default).weight(.semibold)
    /// Sidebar items
    static let staffSidebar      = Font.system(.body, design: .default).weight(.medium)
}

// MARK: - Spacing (iPad-optimized)

enum StaffSpacing {
    static let xs:    CGFloat = 4
    static let sm:    CGFloat = 8
    static let md:    CGFloat = 12
    static let lg:    CGFloat = 16
    static let xl:    CGFloat = 20
    static let xxl:   CGFloat = 24
    static let xxxl:  CGFloat = 32
    static let xxxxl: CGFloat = 40
    static let mega:  CGFloat = 48
}

// MARK: - Corner Radius

enum StaffCorner {
    static let xs:   CGFloat = 6
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 24
    static let pill: CGFloat = 999
}

// MARK: - Shadow Presets

enum StaffShadow {
    static let light = Color.black.opacity(0.15)
    static let medium = Color.black.opacity(0.25)
    static let strong = Color.black.opacity(0.4)
}
