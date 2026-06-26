import SwiftUI

// MARK: - Typography (iPad-optimized scale)
// Larger sizes suited for iPad display density

extension Font {
    /// 56pt Bold — Dashboard hero numbers
    static let staffHeroAmount   = Font.system(size: 56, weight: .bold, design: .rounded)
    /// 40pt Bold — Large metric values
    static let staffLargeAmount  = Font.system(size: 40, weight: .bold, design: .rounded)
    /// 32pt Bold — Screen titles
    static let staffTitle        = Font.system(size: 32, weight: .bold)
    /// 24pt Semibold — Section headings
    static let staffSectionTitle = Font.system(size: 24, weight: .semibold)
    /// 20pt Semibold — Card titles
    static let staffCardTitle    = Font.system(size: 20, weight: .semibold)
    /// 17pt Medium — Primary body text
    static let staffBody         = Font.system(size: 17, weight: .medium)
    /// 15pt Regular — Standard body text
    static let staffBodyRegular  = Font.system(size: 15, weight: .regular)
    /// 14pt Medium — Form labels
    static let staffLabel        = Font.system(size: 14, weight: .medium)
    /// 13pt Regular — Captions, timestamps
    static let staffCaption      = Font.system(size: 13, weight: .regular)
    /// 12pt Semibold — Status badges, tags
    static let staffBadge        = Font.system(size: 12, weight: .semibold)
    /// 11pt Regular — Fine print
    static let staffFinePrint    = Font.system(size: 11, weight: .regular)
    /// 16pt Semibold — Button text
    static let staffButton       = Font.system(size: 16, weight: .semibold)
    /// 18pt Medium — Sidebar items
    static let staffSidebar      = Font.system(size: 16, weight: .medium)
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
