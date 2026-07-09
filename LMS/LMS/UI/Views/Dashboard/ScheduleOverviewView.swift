import SwiftUI
import Auth
import Supabase

// MARK: - ScheduleOverviewView

struct ScheduleOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    // Calendar entries built from all backend EMI schedule rows.
    @State private var emiEntries: [CalendarEMIEntry] = []
    @State private var isLoading = true

    // Calendar state — offset in months from "today's month"
    @State private var monthOffset: Int = 0

    // Selected date — always resets to today when view appears
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    // Date picker sheet
    @State private var showDatePicker: Bool = false
    @State private var pickerDate: Date = Calendar.current.startOfDay(for: Date())

    // MARK: - Computed helpers

    private var calendar: Calendar { Calendar.current }

    /// The month being displayed, derived from today + offset
    private var displayedMonth: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    /// All EMI items keyed by calendar day
    private var emisByDate: [Date: [CalendarEMIEntry]] {
        var map: [Date: [CalendarEMIEntry]] = [:]
        for entry in emiEntries {
            let day = calendar.startOfDay(for: entry.dueDate)
            map[day, default: []].append(entry)
        }
        return map
    }

    /// EMI entries for the currently selected date
    private var selectedDateEMIs: [CalendarEMIEntry] {
        emisByDate[calendar.startOfDay(for: selectedDate)] ?? []
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    calendarCard
                    selectedDateSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(
                LinearGradient(
                    colors: [Color.gradientMintStart, Color.gradientMintEnd, Color.gradientMintStart],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarBackButtonHidden(true)
            .navigationTitle("EMI Schedule")
            .navigationBarTitleDisplayMode(.large)
            // ── Bar button: calendar jump picker ─────────────────────────
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        pickerDate = selectedDate
                        showDatePicker = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(Color.accentGreen)
                    }
                }
            }
            // ── Sheet: full date / month / year picker ────────────────────
            .sheet(isPresented: $showDatePicker) {
                DateJumpSheet(pickerDate: $pickerDate) { chosen in
                    jumpToDate(chosen)
                }
            }
            .task { await loadScheduleEntries() }
            .refreshable { await loadScheduleEntries() }
            // Reset to today whenever this tab is re-visited
            .onAppear { resetToToday() }
            .onReceive(NotificationCenter.default.publisher(for: .loanDataDidChange)) { _ in
                Task { await loadScheduleEntries() }
            }
        }
    }

    // MARK: - Reset to today

    private func resetToToday() {
        let today = calendar.startOfDay(for: Date())
        selectedDate = today
        monthOffset  = 0
    }

    // MARK: - Jump to a chosen date

    private func jumpToDate(_ date: Date) {
        let today = calendar.startOfDay(for: Date())
        // Calculate how many months away the target is from today's base
        let targetComponents = calendar.dateComponents([.year, .month], from: today)
        let chosenComponents = calendar.dateComponents([.year, .month], from: date)
        let yearDiff  = (chosenComponents.year  ?? 0) - (targetComponents.year  ?? 0)
        let monthDiff = (chosenComponents.month ?? 0) - (targetComponents.month ?? 0)
        withAnimation(.easeInOut(duration: 0.3)) {
            monthOffset  = yearDiff * 12 + monthDiff
            selectedDate = calendar.startOfDay(for: date)
        }
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        VStack(spacing: 0) {
            monthHeader
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()
                .background(Color.black.opacity(0.06))

            weekdayLabelsRow
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                dateGrid
                    .padding(.horizontal, 8)
                    .padding(.bottom, 14)
            }
        }
        .liquidGlass(cornerRadius: 28)
        .gesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -40 {
                        withAnimation(.easeInOut(duration: 0.25)) { monthOffset += 1 }
                    } else if value.translation.width > 40 {
                        withAnimation(.easeInOut(duration: 0.25)) { monthOffset -= 1 }
                    }
                }
        )
    }

    // MARK: Month header

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { monthOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundColor(Color.accentGreen)
                    .frame(width: 34, height: 34)
                    .background(Color.accentGreenBg)
                    .clipShape(Circle())
            }

            Spacer()

            Text(monthYearString(displayedMonth))
                .font(.headline.weight(.bold)).fontDesign(.rounded)
                .foregroundColor(Color(hex: "#1A1A1A"))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) { monthOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(Color.accentGreen)
                    .frame(width: 34, height: 34)
                    .background(Color.accentGreenBg)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: Weekday labels

    private var weekdayLabelsRow: some View {
        let symbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return HStack(spacing: 0) {
            ForEach(symbols, id: \.self) { sym in
                Text(sym)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(hex: "#9E9E9E"))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Date grid

    private var dateGrid: some View {
        let days         = daysInMonth(displayedMonth)
        let firstWeekday = weekdayIndex(of: days.first ?? Date())
        let totalCells   = firstWeekday + days.count
        let rows         = Int(ceil(Double(totalCells) / 7.0))

        return VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIndex = row * 7 + col
                        let dayIndex  = cellIndex - firstWeekday
                        if dayIndex >= 0 && dayIndex < days.count {
                            dayCell(days[dayIndex])
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: cellHeight)
                        }
                    }
                }
            }
        }
    }

    // MARK: Single day cell

    private func dayCell(_ date: Date) -> some View {
        let today      = calendar.startOfDay(for: Date())
        let thisDay    = calendar.startOfDay(for: date)
        let isToday    = thisDay == today
        let isSelected = thisDay == calendar.startOfDay(for: selectedDate)
        let emis       = emisByDate[thisDay] ?? []
        let hasPaid     = emis.contains { $0.isPaid }
        let hasOverdue  = emis.contains { $0.isOverdue }
        let hasUpcoming = emis.contains { !$0.isPaid && !$0.isOverdue }

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedDate = date }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.accentGreen)
                            .frame(width: 34, height: 34)
                    } else if isToday {
                        Circle()
                            .fill(Color.accentGreenBg)
                            .frame(width: 34, height: 34)
                    }
                    Text("\(calendar.component(.day, from: date))")
                        .font(.body.weight(isToday || isSelected ? .bold : .regular)).fontDesign(.rounded)
                        .foregroundColor(
                            isSelected ? .white :
                            isToday    ? Color.accentGreen :
                                         Color(hex: "#1A1A1A")
                        )
                }
                .frame(width: 34, height: 34)

                HStack(spacing: 3) {
                    if hasPaid {
                        Circle().fill(Color.accentGreen).frame(width: 5, height: 5)
                    }
                    if hasOverdue {
                        Circle().fill(Color(hex: "#D94040")).frame(width: 5, height: 5)
                    }
                    if hasUpcoming {
                        Circle().fill(Color(hex: "#1A1A1A")).frame(width: 5, height: 5)
                    }
                    if emis.isEmpty {
                        Circle().fill(Color.clear).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var cellHeight: CGFloat { 52 }

    // MARK: - Selected Date Section

    private var selectedDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.accentGreen)
                Text(sectionDateLabel(selectedDate))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(hex: "#6B6B6B"))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text(selectedDateEMIs.isEmpty
                     ? "No EMIs"
                     : "\(selectedDateEMIs.count) EMI\(selectedDateEMIs.count > 1 ? "s" : "")")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color(hex: "#9E9E9E"))
            }
            .padding(.horizontal, 4)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if selectedDateEMIs.isEmpty {
                emptyDateState
            } else {
                VStack(spacing: 10) {
                    ForEach(selectedDateEMIs) { emiDetailRow($0) }
                }
            }
        }
    }

    private var emptyDateState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title)
                .foregroundColor(Color.themeGreen)
            Text("No EMIs on this date")
                .font(.body.weight(.semibold)).fontDesign(.rounded)
                .foregroundColor(Color(hex: "#1A1A1A"))
            Text("Tap any highlighted date to view EMI details.")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#6B6B6B"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .liquidGlass(cornerRadius: 24)
    }

    private func emiDetailRow(_ entry: CalendarEMIEntry) -> some View {
        let accentColor: Color = entry.isPaid   ? Color.accentGreen
                               : entry.isOverdue ? Color(hex: "#D94040")
                               :                   Color.accentGreen
        let bgColor: Color     = entry.isPaid   ? Color.accentGreenBg
                               : entry.isOverdue ? Color(hex: "#FDE8E8")
                               : entry.isDue    ? Color.accentGreenBg
                               :                   Color.clear
        let badgeTextColor: Color = entry.isPaid ? Color.accentGreen
                               : entry.isOverdue ? Color(hex: "#D94040")
                               : entry.isDue    ? Color.accentGreen
                               :                   Color(hex: "#1A1A1A")
        let statusText = entry.isPaid ? "Paid" : entry.isOverdue ? "Overdue" : entry.isDue ? "Due" : "Upcoming"
        let statusIcon = entry.isPaid ? "checkmark.circle.fill"
                       : entry.isOverdue ? "exclamationmark.triangle.fill"
                       : entry.isDue ? "bell.fill"
                       : "clock.fill"

        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(entry.isPaid ? Color.accentGreenBg : entry.isOverdue ? Color(hex: "#FDE8E8") : Color.accentGreenBg).frame(width: 42, height: 42)
                Image(systemName: loanIcon(entry.loanType))
                    .font(.body.weight(.semibold))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.loanName)
                    .font(.body.weight(.semibold)).fontDesign(.rounded)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .lineLimit(1)
                Text(entry.loanNumber)
                    .font(.caption.weight(.regular))
                    .foregroundColor(Color(hex: "#9E9E9E"))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(formatAmount(entry.emiAmount))")
                    .font(.headline.weight(.bold)).fontDesign(.rounded)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                HStack(spacing: 3) {
                    Image(systemName: statusIcon).font(.caption.weight(.bold))
                    Text(statusText).font(.caption.weight(.semibold))
                }
                .foregroundColor(badgeTextColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(bgColor)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .liquidGlass(
            cornerRadius: 22,
            borderColor: accentColor,
            borderOpacity: 0.22,
            shadowOpacity: 0.05,
            shadowRadius: 12,
            shadowY: 6
        )
    }

    // MARK: - Data Loading

    private func loadScheduleEntries() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let userId = authViewModel.currentUser?.id else { return }

            struct LoanScheduleResponse: Decodable {
                let id: UUID
                let loan_number: String?
                let status: String
                let principal_amount: Double
                let outstanding_principal: Double
                let total_payable: Double
                let loan_product: ProductSummary
                let emi_schedule: [EMIRow]

                struct ProductSummary: Decodable {
                    let name: String
                    let type: String
                }

                struct EMIRow: Decodable {
                    let id: UUID
                    let total_emi: Double
                    let penalty_amount: Double?
                    let status: String
                    let due_date: String
                }
            }

            let response: [LoanScheduleResponse] = try await SupabaseManager.shared.client
                .from("loans")
                .select("id, loan_number, principal_amount, outstanding_principal, total_payable, status, loan_product:loan_products(name, type), emi_schedule(id, total_emi, penalty_amount, status, due_date)")
                .eq("borrower_id", value: userId.uuidString)
                .eq("status", value: "active")
                .execute()
                .value

            let today = calendar.startOfDay(for: Date())
            emiEntries = response.flatMap { loan in
                let sortedEMIs = loan.emi_schedule.sorted { $0.due_date < $1.due_date }

                return sortedEMIs.enumerated().compactMap { index, emi -> CalendarEMIEntry? in
                    guard let dueDate = LoansListView.parseDateString(emi.due_date) else { return nil }

                    let dueDay = calendar.startOfDay(for: dueDate)
                    let isPaid = emi.status.lowercased() == "paid"
                    let isDue = (!isPaid && dueDay == today) || emi.status.lowercased() == "due"
                    return CalendarEMIEntry(
                        id: emi.id,
                        loanName: loan.loan_product.name,
                        loanType: loan.loan_product.type,
                        loanNumber: loan.loan_number ?? "N/A",
                        emiAmount: emi.total_emi + (emi.penalty_amount ?? 0),
                        dueDate: dueDate,
                        isPaid: isPaid,
                        isOverdue: (!isPaid && dueDay < today) || emi.status.lowercased() == "overdue",
                        isDue: isDue
                    )
                }
            }
            .sorted { $0.dueDate < $1.dueDate }
        } catch {
            print("ScheduleOverviewView: failed to load EMI schedule: \(error)")
            emiEntries = []
        }
    }

    // MARK: - Calendar Helpers

    private func daysInMonth(_ month: Date) -> [Date] {
        guard
            let range    = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstDay) }
    }

    private func weekdayIndex(of date: Date) -> Int {
        calendar.component(.weekday, from: date) - 1   // 0 = Sun … 6 = Sat
    }

    private func monthYearString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: date)
    }

    private func sectionDateLabel(_ date: Date) -> String {
        let today    = calendar.startOfDay(for: Date())
        let thisDay  = calendar.startOfDay(for: date)
        if thisDay == today { return "Today" }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        if thisDay == calendar.startOfDay(for: tomorrow) { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMM yyyy"; return f.string(from: date)
    }

    private func loanIcon(_ loanType: String) -> String {
        switch loanType.lowercased() {
        case "home":        return "house.fill"
        case "vehicle":     return "car.fill"
        case "business":    return "building.2.fill"
        case "education":   return "graduationcap.fill"
        case "gold":        return "sparkles"
        case "agriculture": return "leaf.fill"
        default:            return "indianrupeesign.circle.fill"
        }
    }

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

// MARK: - DateJumpSheet

/// Bottom sheet that lets the user pick any date (day + month + year) and jump to it.
private struct DateJumpSheet: View {
    @Binding var pickerDate: Date
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (Date) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Native wheel picker — shows Day / Month / Year wheels
                DatePicker(
                    "",
                    selection: $pickerDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.horizontal, 8)

                Divider().padding(.horizontal, 24)

                // Go button
                Button {
                    onConfirm(pickerDate)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.headline.weight(.semibold))
                        Text("Go to \(shortLabel(pickerDate))")
                            .font(.body.weight(.semibold)).fontDesign(.rounded)
                    }
                    .foregroundColor(.accentDarkText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#F5F5F0").ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .navigationTitle("Jump to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
    }

    private func shortLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f.string(from: date)
    }
}

// MARK: - Supporting Model

private struct CalendarEMIEntry: Identifiable {
    let id         : UUID
    let loanName   : String
    let loanType   : String
    let loanNumber : String
    let emiAmount  : Double
    let dueDate    : Date
    let isPaid     : Bool
    let isOverdue  : Bool
    let isDue      : Bool
}
