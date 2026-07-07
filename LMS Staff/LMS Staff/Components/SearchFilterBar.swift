import SwiftUI

/// Combined search bar + filter chips for list views
struct SearchFilterBar: View {
    @Binding var searchText: String
    var placeholder: String = "Search..."
    var filters: [FilterOption] = []
    @Binding var selectedFilter: String?

    struct FilterOption: Identifiable {
        let id: String
        let label: String
        let icon: String?

        init(id: String, label: String, icon: String? = nil) {
            self.id = id
            self.label = label
            self.icon = icon
        }
    }

    var body: some View {
        VStack(spacing: StaffSpacing.md) {
            // Search bar
            HStack(spacing: StaffSpacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .foregroundColor(.staffTextTertiary)

                TextField(placeholder, text: $searchText)
                    .font(.staffBody)
                    .foregroundColor(.staffTextPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundColor(.staffTextTertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.staffSurfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: StaffCorner.md))
            .overlay(
                RoundedRectangle(cornerRadius: StaffCorner.md)
                    .stroke(Color.staffBorder, lineWidth: 0.5)
            )

            // Filter chips
            if !filters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: StaffSpacing.sm) {
                        // "All" chip
                        FilterChip(
                            label: "All",
                            icon: nil,
                            isSelected: selectedFilter == nil,
                            action: { selectedFilter = nil }
                        )

                        ForEach(filters) { filter in
                            FilterChip(
                                label: filter.label,
                                icon: filter.icon,
                                isSelected: selectedFilter == filter.id,
                                action: { selectedFilter = filter.id }
                            )
                        }
                    }
                }
            }
        }
    }
}

/// Individual filter chip
struct FilterChip: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(label)
                    .font(.staffBadge)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.staffAccent : Color.staffSurfaceLight)
            .foregroundColor(isSelected ? .white : .staffTextSecondary)
            .clipShape(Capsule())
        }
    }
}
