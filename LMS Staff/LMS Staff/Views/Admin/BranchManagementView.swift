//
//  BranchManagementView.swift
//  LMS Staff
//
//  Admin view for managing branches — create, edit, assign managers & officers,
//  manage pincode coverage areas, and view per-branch loan metrics.
//

import SwiftUI

// MARK: - Main Branch Management View

struct BranchManagementView: View {
    @StateObject private var vm = BranchManagementViewModel()
    @State private var showCreateSheet = false
    @State private var selectedTab: BranchDetailTab = .overview

    var body: some View {
        HStack(spacing: 0) {
            // Left Panel — Branch List
            branchListPanel
                .frame(width: 340)
                .background(Color.staffBackground)

            Divider()
                .background(Color.staffBorder)

            // Right Panel — Branch Detail
            if let branch = vm.selectedBranch {
                branchDetailPanel(branch: branch)
                    .frame(maxWidth: .infinity)
            } else {
                emptyDetailPanel
                    .frame(maxWidth: .infinity)
            }
        }
        .background(Color.staffBackground)
        .onAppear {
            Task { await vm.loadBranches() }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateBranchSheet(vm: vm)
        }
        .alert("Success", isPresented: .init(
            get: { vm.successMessage != nil },
            set: { if !$0 { vm.successMessage = nil } }
        )) {
            Button("OK") { vm.successMessage = nil }
        } message: {
            Text(vm.successMessage ?? "")
        }
    }

    // MARK: - Branch List Panel

    private var branchListPanel: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Branches")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)

                    Spacer()

                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.staffAccent)
                    }
                }
                .padding(.horizontal, StaffSpacing.lg)
                .padding(.top, StaffSpacing.lg)

                // Search
                HStack(spacing: StaffSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.staffTextTertiary)
                    TextField("Search branches...", text: $vm.searchText)
                        .font(.staffBody)
                        .foregroundColor(.staffTextPrimary)
                        .tint(.staffAccent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.staffSurfaceMuted)
                .cornerRadius(StaffCorner.sm)
                .padding(.horizontal, StaffSpacing.lg)
                .padding(.bottom, StaffSpacing.md)
            }
            .background(Color.white)

            Divider().background(Color.staffBorder)

            // Branch List
            if vm.isLoading && vm.branches.isEmpty {
                Spacer()
                ProgressView()
                    .tint(.staffAccent)
                Spacer()
            } else if vm.filteredBranches.isEmpty {
                Spacer()
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "building.2")
                        .font(.system(size: 40))
                        .foregroundColor(.staffTextTertiary)
                    Text("No branches found")
                        .font(.staffBody)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.filteredBranches) { branch in
                            branchRow(branch: branch)
                        }
                    }
                }
            }
        }
    }

    private func branchRow(branch: Branch) -> some View {
        let isSelected = vm.selectedBranch?.id == branch.id

        return Button(action: {
            selectedTab = .overview
            Task { await vm.loadBranchDetail(branch: branch) }
        }) {
            HStack(spacing: StaffSpacing.md) {
                // Icon
                Image(systemName: "building.2.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.staffAccent)
                    .frame(width: 36, height: 36)
                    .background(Color.staffAccentBg)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(branch.name)
                        .font(.staffBody)
                        .fontWeight(isSelected ? .bold : .medium)
                        .foregroundColor(.staffTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: StaffSpacing.xs) {
                        Text(branch.code)
                            .font(.staffCaption)
                            .foregroundColor(.staffTextSecondary)

                        if let city = branch.city {
                            Text("•")
                                .foregroundColor(.staffTextTertiary)
                            Text(city)
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, StaffSpacing.lg)
            .padding(.vertical, StaffSpacing.md)
            .background(isSelected ? Color.staffSidebarActive : Color.white)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Empty Detail

    private var emptyDetailPanel: some View {
        VStack(spacing: StaffSpacing.lg) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.staffTextTertiary.opacity(0.4))

            Text("Select a Branch")
                .font(.staffTitle)
                .foregroundColor(.staffTextSecondary)

            Text("Choose a branch from the left panel to view details,\nassign staff, manage pincodes, and view loan metrics.")
                .font(.staffBodyRegular)
                .foregroundColor(.staffTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.staffBackground)
    }

    // MARK: - Branch Detail Panel

    private func branchDetailPanel(branch: Branch) -> some View {
        VStack(spacing: 0) {
            // Branch Header
            branchDetailHeader(branch: branch)

            Divider().background(Color.staffBorder)

            // Tab Picker
            tabPicker

            Divider().background(Color.staffBorder)

            // Tab Content
            if vm.isLoadingDetail {
                Spacer()
                ProgressView("Loading branch data...")
                    .tint(.staffAccent)
                    .foregroundColor(.staffTextSecondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: StaffSpacing.xl) {
                        switch selectedTab {
                        case .overview:
                            BranchOverviewTab(vm: vm, branch: branch)
                        case .staff:
                            BranchStaffTab(vm: vm, branch: branch)
                        case .pincodes:
                            BranchPincodesTab(vm: vm, branch: branch)
                        case .metrics:
                            BranchMetricsTab(vm: vm, branch: branch)
                        }
                    }
                    .padding(StaffSpacing.xl)
                }
            }
        }
        .background(Color.staffBackground)
    }

    private func branchDetailHeader(branch: Branch) -> some View {
        HStack(spacing: StaffSpacing.lg) {
            // Branch icon
            Image(systemName: "building.2.fill")
                .font(.system(size: 28))
                .foregroundColor(.staffAccent)
                .frame(width: 52, height: 52)
                .background(Color.staffAccentBg)
                .cornerRadius(StaffCorner.md)

            VStack(alignment: .leading, spacing: 2) {
                Text(branch.name)
                    .font(.staffSectionTitle)
                    .foregroundColor(.staffTextPrimary)

                HStack(spacing: StaffSpacing.sm) {
                    Text(branch.code)
                        .font(.staffBadge)
                        .foregroundColor(.staffAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.staffAccentBg)
                        .cornerRadius(StaffCorner.xs)

                    if let city = branch.city, let state = branch.state {
                        Text("\(city), \(state)")
                            .font(.staffCaption)
                            .foregroundColor(.staffTextSecondary)
                    }
                }
            }

            Spacer()

            // Status badge
            HStack(spacing: 4) {
                Circle()
                    .fill(branch.isActive ? Color.staffGreen : Color.staffRed)
                    .frame(width: 8, height: 8)
                Text(branch.isActive ? "Active" : "Inactive")
                    .font(.staffBadge)
                    .foregroundColor(branch.isActive ? .staffGreen : .staffRed)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(branch.isActive ? Color.staffGreenBg : Color.staffRedBg)
            .cornerRadius(StaffCorner.sm)
        }
        .padding(StaffSpacing.xl)
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(BranchDetailTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: StaffSpacing.sm) {
                        HStack(spacing: StaffSpacing.xs) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13))
                            Text(tab.title)
                                .font(.staffLabel)
                        }
                        .foregroundColor(selectedTab == tab ? .staffAccent : .staffTextSecondary)
                        .padding(.horizontal, StaffSpacing.lg)
                        .padding(.top, StaffSpacing.md)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.staffAccent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()
        }
        .background(Color.staffSurface)
    }
}

// MARK: - Detail Tab Enum

enum BranchDetailTab: String, CaseIterable {
    case overview
    case staff
    case pincodes
    case metrics

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .staff: return "Staff"
        case .pincodes: return "Pincodes"
        case .metrics: return "Loan Metrics"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "info.circle.fill"
        case .staff: return "person.3.fill"
        case .pincodes: return "mappin.and.ellipse"
        case .metrics: return "chart.bar.fill"
        }
    }
}

// MARK: - Overview Tab

struct BranchOverviewTab: View {
    @ObservedObject var vm: BranchManagementViewModel
    let branch: Branch

    @State private var editName: String = ""
    @State private var editAddress: String = ""
    @State private var editCity: String = ""
    @State private var editState: String = ""
    @State private var editPincode: String = ""
    @State private var editIfsc: String = ""
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(spacing: StaffSpacing.xl) {
            // Info card
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    HStack {
                        Text("Branch Details")
                            .font(.staffCardTitle)
                            .foregroundColor(.staffTextPrimary)

                        Spacer()

                        Button(action: {
                            if isEditing {
                                Task {
                                    let _ = await vm.updateBranch(
                                        name: editName,
                                        address: editAddress.isEmpty ? nil : editAddress,
                                        city: editCity.isEmpty ? nil : editCity,
                                        state: editState.isEmpty ? nil : editState,
                                        pincode: editPincode.isEmpty ? nil : editPincode,
                                        ifscPrefix: editIfsc.isEmpty ? nil : editIfsc
                                    )
                                    isEditing = false
                                }
                            } else {
                                populateFields()
                                isEditing = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isEditing ? "checkmark" : "pencil")
                                Text(isEditing ? "Save" : "Edit")
                            }
                            .font(.staffBadge)
                            .foregroundColor(.staffAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.staffAccentBg)
                            .cornerRadius(StaffCorner.xs)
                        }
                    }

                    Divider().background(Color.staffBorder)

                    if isEditing {
                        editForm
                    } else {
                        readOnlyInfo
                    }
                }
            }

            // Actions
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    Text("Branch Actions")
                        .font(.staffCardTitle)
                        .foregroundColor(.staffTextPrimary)

                    Divider().background(Color.staffBorder)

                    HStack(spacing: StaffSpacing.lg) {
                        Button(action: {
                            Task { await vm.toggleBranchStatus() }
                        }) {
                            HStack(spacing: StaffSpacing.sm) {
                                Image(systemName: branch.isActive ? "xmark.circle" : "checkmark.circle")
                                Text(branch.isActive ? "Deactivate Branch" : "Activate Branch")
                            }
                            .font(.staffButton)
                            .foregroundColor(branch.isActive ? .staffRed : .staffGreen)
                            .padding(.horizontal, StaffSpacing.xl)
                            .padding(.vertical, StaffSpacing.md)
                            .background(branch.isActive ? Color.staffRedBg : Color.staffGreenBg)
                            .cornerRadius(StaffCorner.md)
                        }

                        Spacer()
                    }
                }
            }

            if let error = vm.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                }
                .font(.staffCaption)
                .foregroundColor(.staffRed)
                .padding(StaffSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.staffRedBg)
                .cornerRadius(StaffCorner.sm)
            }
        }
        .onAppear { populateFields() }
        .onChange(of: vm.selectedBranch) { _, _ in populateFields() }
    }

    private var readOnlyInfo: some View {
        let rows: [(String, String)] = [
            ("Branch Name", branch.name),
            ("Branch Code", branch.code),
            ("Address", branch.address ?? "—"),
            ("City", branch.city ?? "—"),
            ("State", branch.state ?? "—"),
            ("Pincode", branch.pincode ?? "—"),
            ("IFSC Prefix", branch.ifscPrefix ?? "—")
        ]

        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0)
                        .font(.staffLabel)
                        .foregroundColor(.staffTextSecondary)
                        .frame(width: 140, alignment: .leading)
                    Text(row.1)
                        .font(.staffBody)
                        .foregroundColor(.staffTextPrimary)
                    Spacer()
                }
                .padding(.vertical, StaffSpacing.sm)
            }
        }
    }

    private var editForm: some View {
        VStack(spacing: StaffSpacing.md) {
            StaffFormField(label: "Branch Name", placeholder: "Enter branch name", text: $editName, icon: "building.2")
            StaffFormField(label: "Address", placeholder: "Street address", text: $editAddress, icon: "mappin")
            HStack(spacing: StaffSpacing.md) {
                StaffFormField(label: "City", placeholder: "City", text: $editCity, icon: "map")
                StaffFormField(label: "State", placeholder: "State", text: $editState, icon: "globe.asia.australia")
            }
            HStack(spacing: StaffSpacing.md) {
                StaffFormField(label: "Pincode", placeholder: "6-digit pincode", text: $editPincode, keyboardType: .numberPad, icon: "number")
                StaffFormField(label: "IFSC Prefix", placeholder: "e.g. LMSB00", text: $editIfsc, icon: "building.columns")
            }
        }
    }

    private func populateFields() {
        editName = branch.name
        editAddress = branch.address ?? ""
        editCity = branch.city ?? ""
        editState = branch.state ?? ""
        editPincode = branch.pincode ?? ""
        editIfsc = branch.ifscPrefix ?? ""
    }
}

// MARK: - Staff Tab

struct BranchStaffTab: View {
    @ObservedObject var vm: BranchManagementViewModel
    let branch: Branch

    @State private var showManagerPicker = false
    @State private var showOfficerPicker = false

    var body: some View {
        VStack(spacing: StaffSpacing.xl) {
            // Branch Manager Card
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .foregroundColor(.staffTeal)
                        Text("Branch Manager")
                            .font(.staffCardTitle)
                            .foregroundColor(.staffTextPrimary)
                        Spacer()
                    }

                    Divider().background(Color.staffBorder)

                    if let manager = vm.managerUser {
                        HStack(spacing: StaffSpacing.lg) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.staffTeal)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(manager.fullName)
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                Text(manager.email ?? "")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                HStack(spacing: 4) {
                                    Circle().fill(Color.staffTeal).frame(width: 6, height: 6)
                                    Text("Manager")
                                        .font(.staffBadge)
                                        .foregroundColor(.staffTeal)
                                }
                            }

                            Spacer()

                            Button(action: {
                                Task {
                                    await vm.loadAvailableManagers()
                                    showManagerPicker = true
                                }
                            }) {
                                Text("Change")
                                    .font(.staffBadge)
                                    .foregroundColor(.staffAmber)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.staffAmberBg)
                                    .cornerRadius(StaffCorner.xs)
                            }

                            Button(action: {
                                Task { await vm.removeManager() }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.staffRed)
                            }
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No Manager Assigned")
                                    .font(.staffBody)
                                    .foregroundColor(.staffTextSecondary)
                                Text("Assign a manager to oversee this branch")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextTertiary)
                            }

                            Spacer()

                            Button(action: {
                                Task {
                                    await vm.loadAvailableManagers()
                                    showManagerPicker = true
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("Assign Manager")
                                }
                                .font(.staffBadge)
                                .foregroundColor(.staffAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.staffAccentBg)
                                .cornerRadius(StaffCorner.sm)
                            }
                        }
                    }
                }
            }

            // Loan Officers Card
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.staffAccent)
                        Text("Loan Officers")
                            .font(.staffCardTitle)
                            .foregroundColor(.staffTextPrimary)

                        Spacer()

                        // Count badge
                        let officerCount = branchOfficers.count
                        Text("\(officerCount)")
                            .font(.staffBadge)
                            .foregroundColor(.staffAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.staffAccentBg)
                            .cornerRadius(StaffCorner.pill)

                        Button(action: {
                            Task {
                                await vm.loadAvailableOfficers()
                                showOfficerPicker = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add Officer")
                            }
                            .font(.staffBadge)
                            .foregroundColor(.staffAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.staffAccentBg)
                            .cornerRadius(StaffCorner.xs)
                        }
                    }

                    Divider().background(Color.staffBorder)

                    if branchOfficers.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: StaffSpacing.sm) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 28))
                                    .foregroundColor(.staffTextTertiary)
                                Text("No officers assigned to this branch")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                            }
                            .padding(.vertical, StaffSpacing.xl)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(branchOfficers) { staffUser in
                                HStack(spacing: StaffSpacing.md) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.staffAccent)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(staffUser.user.fullName)
                                            .font(.staffBody)
                                            .foregroundColor(.staffTextPrimary)
                                        Text(staffUser.staff.employeeId)
                                            .font(.staffCaption)
                                            .foregroundColor(.staffTextSecondary)
                                    }

                                    Spacer()

                                    Text(staffUser.staff.designation ?? "Officer")
                                        .font(.staffBadge)
                                        .foregroundColor(.staffAccent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.staffAccentBg)
                                        .cornerRadius(StaffCorner.xs)

                                    Button(action: {
                                        Task { await vm.removeOfficer(officerUserId: staffUser.user.id) }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.staffRed.opacity(0.7))
                                    }
                                }
                                .padding(.vertical, StaffSpacing.sm)

                                Divider().background(Color.staffBorder.opacity(0.5))
                            }
                        }
                    }
                }
            }

            // Full Employee Roster
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                            .foregroundColor(.staffPurple)
                        Text("All Branch Employees")
                            .font(.staffCardTitle)
                            .foregroundColor(.staffTextPrimary)
                        Spacer()
                        Text("\(vm.branchStaff.count) total")
                            .font(.staffBadge)
                            .foregroundColor(.staffPurple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.staffPurpleBg)
                            .cornerRadius(StaffCorner.pill)
                    }

                    Divider().background(Color.staffBorder)

                    if vm.branchStaff.isEmpty {
                        Text("No employees assigned to this branch")
                            .font(.staffCaption)
                            .foregroundColor(.staffTextSecondary)
                            .padding(.vertical, StaffSpacing.md)
                    } else {
                        // Table header
                        HStack {
                            Text("Name")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Employee ID")
                                .frame(width: 120, alignment: .leading)
                            Text("Role")
                                .frame(width: 100, alignment: .leading)
                            Text("Designation")
                                .frame(width: 140, alignment: .leading)
                            Text("Status")
                                .frame(width: 80, alignment: .center)
                        }
                        .font(.staffBadge)
                        .foregroundColor(.staffTextTertiary)
                        .padding(.bottom, 4)

                        VStack(spacing: 0) {
                            ForEach(vm.branchStaff) { staffUser in
                                HStack {
                                    Text(staffUser.user.fullName)
                                        .font(.staffBody)
                                        .foregroundColor(.staffTextPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Text(staffUser.staff.employeeId)
                                        .font(.staffCaption)
                                        .foregroundColor(.staffTextSecondary)
                                        .frame(width: 120, alignment: .leading)

                                    Text(staffUser.user.role.displayName)
                                        .font(.staffBadge)
                                        .foregroundColor(Color.roleBadgeColor(for: staffUser.user.role.rawValue))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.roleBadgeBg(for: staffUser.user.role.rawValue))
                                        .cornerRadius(StaffCorner.xs)
                                        .frame(width: 100, alignment: .leading)

                                    Text(staffUser.staff.designation ?? "—")
                                        .font(.staffCaption)
                                        .foregroundColor(.staffTextSecondary)
                                        .frame(width: 140, alignment: .leading)

                                    Circle()
                                        .fill(staffUser.user.isActive ? Color.staffGreen : Color.staffRed)
                                        .frame(width: 8, height: 8)
                                        .frame(width: 80)
                                }
                                .padding(.vertical, StaffSpacing.sm)

                                Divider().background(Color.staffBorder.opacity(0.3))
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showManagerPicker) {
            StaffPickerSheet(
                title: "Assign Branch Manager",
                staffList: vm.availableManagers,
                onSelect: { userId in
                    Task { await vm.assignManager(managerId: userId) }
                }
            )
        }
        .sheet(isPresented: $showOfficerPicker) {
            StaffPickerSheet(
                title: "Assign Loan Officer",
                staffList: vm.availableOfficers,
                onSelect: { userId in
                    Task { await vm.assignOfficer(officerUserId: userId) }
                }
            )
        }
    }

    private var branchOfficers: [StaffWithUser] {
        vm.branchStaff.filter { $0.user.role == .officer }
    }
}

// MARK: - Pincodes Tab

struct BranchPincodesTab: View {
    @ObservedObject var vm: BranchManagementViewModel
    let branch: Branch

    @State private var newPincode: String = ""

    var body: some View {
        VStack(spacing: StaffSpacing.xl) {
            // Add Pincode
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.staffOrange)
                        Text("Pincode Coverage Area")
                            .font(.staffCardTitle)
                            .foregroundColor(.staffTextPrimary)
                        Spacer()
                        Text("\(vm.branchPincodes.count) pincodes")
                            .font(.staffBadge)
                            .foregroundColor(.staffOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.staffOrangeBg)
                            .cornerRadius(StaffCorner.pill)
                    }

                    Divider().background(Color.staffBorder)

                    // Add form
                    HStack(spacing: StaffSpacing.md) {
                        HStack(spacing: StaffSpacing.sm) {
                            Image(systemName: "number")
                                .foregroundColor(.staffTextTertiary)
                            TextField("Enter 6-digit pincode", text: $newPincode)
                                .font(.staffBody)
                                .foregroundColor(.staffTextPrimary)
                                .keyboardType(.numberPad)
                                .tint(.staffAccent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.staffSurfaceMuted)
                        .cornerRadius(StaffCorner.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: StaffCorner.sm)
                                .stroke(Color.staffBorder, lineWidth: 1)
                        )

                        Button(action: {
                            guard !newPincode.isEmpty else { return }
                            Task {
                                let success = await vm.addPincode(pincode: newPincode)
                                if success { newPincode = "" }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add")
                            }
                            .font(.staffButton)
                            .foregroundColor(.white)
                            .padding(.horizontal, StaffSpacing.xl)
                            .padding(.vertical, 10)
                            .background(newPincode.count == 6 ? Color.staffAccent : Color.staffBorder)
                            .cornerRadius(StaffCorner.sm)
                        }
                        .disabled(newPincode.count != 6)
                    }

                    // Pincode list
                    if vm.branchPincodes.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: StaffSpacing.sm) {
                                Image(systemName: "map")
                                    .font(.system(size: 28))
                                    .foregroundColor(.staffTextTertiary)
                                Text("No pincodes assigned yet")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                            }
                            .padding(.vertical, StaffSpacing.xl)
                            Spacer()
                        }
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: StaffSpacing.sm) {
                            ForEach(vm.branchPincodes) { bp in
                                HStack(spacing: StaffSpacing.sm) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.staffOrange)
                                        .font(.system(size: 14))

                                    Text(bp.pincode)
                                        .font(.staffBody)
                                        .fontWeight(.medium)
                                        .foregroundColor(.staffTextPrimary)

                                    Spacer()

                                    Button(action: {
                                        Task { await vm.removePincode(id: bp.id) }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.staffRed.opacity(0.6))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.staffSurfaceLight)
                                .cornerRadius(StaffCorner.sm)
                            }
                        }
                    }
                }
            }

            // Auto-assign section
            StaffCard {
                VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundColor(.staffTeal)
                        Text("Proximity-Based Auto-Assignment")
                            .font(.staffCardTitle)
                            .foregroundColor(.staffTextPrimary)
                    }

                    Divider().background(Color.staffBorder)

                    Text("Automatically assign unassigned loan applications to branches based on the borrower's pincode. Applications without a branch will be matched to the nearest branch by pincode coverage.")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)

                    Button(action: {
                        Task { await vm.autoAssignLoansByProximity() }
                    }) {
                        HStack(spacing: StaffSpacing.sm) {
                            if vm.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "location.magnifyingglass")
                            Text("Auto-Assign All Unassigned Applications")
                        }
                        .font(.staffButton)
                        .foregroundColor(.white)
                        .padding(.horizontal, StaffSpacing.xl)
                        .padding(.vertical, StaffSpacing.md)
                        .background(Color.staffTeal)
                        .cornerRadius(StaffCorner.md)
                    }
                    .disabled(vm.isLoading)

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.staffCaption)
                            .foregroundColor(.staffRed)
                    }
                }
            }
        }
    }
}

// MARK: - Metrics Tab

struct BranchMetricsTab: View {
    @ObservedObject var vm: BranchManagementViewModel
    let branch: Branch

    var body: some View {
        VStack(spacing: StaffSpacing.xl) {
            if let metrics = vm.branchMetrics {
                // Metric cards grid
                VStack(spacing: StaffSpacing.md) {
                    HStack(spacing: StaffSpacing.md) {
                        MetricBlockCard(
                            title: "Total Loans",
                            value: "\(metrics.totalLoans)",
                            icon: "doc.text.fill",
                            color: .staffAccent
                        )
                        MetricBlockCard(
                            title: "Active Loans",
                            value: "\(metrics.activeLoans)",
                            icon: "checkmark.circle.fill",
                            color: .staffGreen
                        )
                        MetricBlockCard(
                            title: "NPA Loans",
                            value: "\(metrics.npaLoans)",
                            icon: "exclamationmark.triangle.fill",
                            color: .staffRed
                        )
                    }

                    HStack(spacing: StaffSpacing.md) {
                        MetricBlockCard(
                            title: "Total Disbursed",
                            value: formatCurrency(metrics.totalDisbursed),
                            icon: "banknote.fill",
                            color: .staffPurple
                        )
                        MetricBlockCard(
                            title: "Active Portfolio",
                            value: formatCurrency(metrics.activePortfolio),
                            icon: "briefcase.fill",
                            color: .staffTeal
                        )
                        MetricBlockCard(
                            title: "Collection %",
                            value: String(format: "%.1f%%", metrics.collectionEfficiency),
                            icon: "percent",
                            color: .staffAmber
                        )
                    }
                }

                // NPA Ratio
                StaffCard {
                    VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                        Text("NPA Ratio")
                            .font(.staffCardTitle)
                            .foregroundColor(.staffTextPrimary)

                        Divider().background(Color.staffBorder)

                        HStack(spacing: StaffSpacing.xl) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(format: "%.2f%%", metrics.npaRatio))
                                    .font(.staffLargeAmount)
                                    .foregroundColor(metrics.npaRatio > 5 ? .staffRed : metrics.npaRatio > 2 ? .staffAmber : .staffGreen)

                                Text("Non-Performing Assets Ratio")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                            }

                            Spacer()

                            // NPA visual bar
                            VStack(alignment: .leading, spacing: 4) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.staffSurfaceLight)
                                            .frame(height: 12)

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(metrics.npaRatio > 5 ? Color.staffRed : metrics.npaRatio > 2 ? Color.staffAmber : Color.staffGreen)
                                            .frame(width: geo.size.width * min(CGFloat(metrics.npaRatio) / 20.0, 1.0), height: 12)
                                    }
                                }
                                .frame(height: 12)
                                .frame(maxWidth: 200)

                                HStack {
                                    Text("0%")
                                    Spacer()
                                    Text("20%")
                                }
                                .font(.staffFinePrint)
                                .foregroundColor(.staffTextTertiary)
                                .frame(maxWidth: 200)
                            }
                        }

                        HStack(spacing: StaffSpacing.xl) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NPA Amount")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                Text(formatCurrency(metrics.npaAmount))
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffRed)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Total Collected")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                Text(formatCurrency(metrics.totalCollected))
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffGreen)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Total Due")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                Text(formatCurrency(metrics.totalDue))
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffAmber)
                            }
                        }
                    }
                }

                // Loan list
                if !vm.branchLoans.isEmpty {
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
                            HStack {
                                Text("Branch Loans")
                                    .font(.staffCardTitle)
                                    .foregroundColor(.staffTextPrimary)
                                Spacer()
                                Text("\(vm.branchLoans.count)")
                                    .font(.staffBadge)
                                    .foregroundColor(.staffAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.staffAccentBg)
                                    .cornerRadius(StaffCorner.pill)
                            }

                            Divider().background(Color.staffBorder)

                            // Table header
                            HStack {
                                Text("Loan #")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Principal")
                                    .frame(width: 120, alignment: .trailing)
                                Text("Rate")
                                    .frame(width: 70, alignment: .trailing)
                                Text("Outstanding")
                                    .frame(width: 120, alignment: .trailing)
                                Text("Status")
                                    .frame(width: 100, alignment: .center)
                            }
                            .font(.staffBadge)
                            .foregroundColor(.staffTextTertiary)

                            VStack(spacing: 0) {
                                ForEach(vm.branchLoans) { loan in
                                    HStack {
                                        Text(loan.loanNumber ?? "—")
                                            .font(.staffCaption)
                                            .foregroundColor(.staffTextPrimary)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Text(formatCurrency(loan.principalAmount))
                                            .font(.staffCaption)
                                            .foregroundColor(.staffTextPrimary)
                                            .frame(width: 120, alignment: .trailing)

                                        Text(String(format: "%.1f%%", loan.interestRate))
                                            .font(.staffCaption)
                                            .foregroundColor(.staffTextSecondary)
                                            .frame(width: 70, alignment: .trailing)

                                        Text(formatCurrency(loan.outstandingPrincipal))
                                            .font(.staffCaption)
                                            .foregroundColor(.staffAmber)
                                            .frame(width: 120, alignment: .trailing)

                                        Text(loan.status.displayName)
                                            .font(.staffBadge)
                                            .foregroundColor(Color.staffStatusForeground(for: loan.status.rawValue))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.staffStatusBackground(for: loan.status.rawValue))
                                            .cornerRadius(StaffCorner.xs)
                                            .frame(width: 100, alignment: .center)
                                    }
                                    .padding(.vertical, StaffSpacing.xs)

                                    Divider().background(Color.staffBorder.opacity(0.3))
                                }
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.staffTextTertiary)
                    Text("No loan data available for this branch")
                        .font(.staffBody)
                        .foregroundColor(.staffTextSecondary)
                }
                .padding(.vertical, StaffSpacing.xxxxl)
            }
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return "₹" + (formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))")
    }
}

// MARK: - Create Branch Sheet

struct CreateBranchSheet: View {
    @ObservedObject var vm: BranchManagementViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var code = ""
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var pincode = ""
    @State private var ifscPrefix = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: StaffSpacing.xl) {
                    // Header icon
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.staffAccent)
                        .padding(.top, StaffSpacing.xl)

                    Text("Create New Branch")
                        .font(.staffSectionTitle)
                        .foregroundColor(.staffTextPrimary)

                    // Form
                    VStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Branch Name *", placeholder: "e.g. South Delhi Branch", text: $name, icon: "building.2")
                        StaffFormField(label: "Branch Code *", placeholder: "e.g. SD001", text: $code, icon: "barcode")
                        StaffFormField(label: "Address", placeholder: "Street address", text: $address, icon: "mappin")

                        HStack(spacing: StaffSpacing.md) {
                            StaffFormField(label: "City", placeholder: "City", text: $city, icon: "map")
                            StaffFormField(label: "State", placeholder: "State", text: $state, icon: "globe.asia.australia")
                        }

                        HStack(spacing: StaffSpacing.md) {
                            StaffFormField(label: "Pincode", placeholder: "6-digit pincode", text: $pincode, keyboardType: .numberPad, icon: "number")
                            StaffFormField(label: "IFSC Prefix", placeholder: "e.g. LMSB05", text: $ifscPrefix, icon: "building.columns")
                        }
                    }
                    .padding(.horizontal, StaffSpacing.xl)

                    if let error = vm.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                        }
                        .font(.staffCaption)
                        .foregroundColor(.staffRed)
                        .padding(StaffSpacing.md)
                        .background(Color.staffRedBg)
                        .cornerRadius(StaffCorner.sm)
                        .padding(.horizontal, StaffSpacing.xl)
                    }

                    // Create button
                    Button(action: {
                        Task {
                            let success = await vm.createBranch(
                                name: name,
                                code: code,
                                address: address.isEmpty ? nil : address,
                                city: city.isEmpty ? nil : city,
                                state: state.isEmpty ? nil : state,
                                pincode: pincode.isEmpty ? nil : pincode,
                                ifscPrefix: ifscPrefix.isEmpty ? nil : ifscPrefix
                            )
                            if success { dismiss() }
                        }
                    }) {
                        HStack(spacing: StaffSpacing.sm) {
                            if vm.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "plus.circle.fill")
                            Text("Create Branch")
                        }
                        .font(.staffButton)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, StaffSpacing.lg)
                        .background(isFormValid ? Color.staffAccent : Color.staffBorder)
                        .cornerRadius(StaffCorner.md)
                    }
                    .disabled(!isFormValid || vm.isLoading)
                    .padding(.horizontal, StaffSpacing.xl)
                    .padding(.bottom, StaffSpacing.xl)
                }
            }
            .background(Color.staffBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.staffAccent)
                }
            }
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !code.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Staff Picker Sheet

struct StaffPickerSheet: View {
    let title: String
    let staffList: [StaffWithUser]
    let onSelect: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: StaffSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.staffTextTertiary)
                    TextField("Search staff...", text: $search)
                        .font(.staffBody)
                        .foregroundColor(.staffTextPrimary)
                        .tint(.staffAccent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.staffSurfaceMuted)
                .cornerRadius(StaffCorner.sm)
                .padding(StaffSpacing.lg)

                Divider().background(Color.staffBorder)

                if filteredStaff.isEmpty {
                    Spacer()
                    VStack(spacing: StaffSpacing.md) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 36))
                            .foregroundColor(.staffTextTertiary)
                        Text("No available staff found")
                            .font(.staffBody)
                            .foregroundColor(.staffTextSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredStaff) { staffUser in
                                Button(action: {
                                    onSelect(staffUser.user.id)
                                    dismiss()
                                }) {
                                    HStack(spacing: StaffSpacing.md) {
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(Color.roleBadgeColor(for: staffUser.user.role.rawValue))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(staffUser.user.fullName)
                                                .font(.staffBody)
                                                .fontWeight(.medium)
                                                .foregroundColor(.staffTextPrimary)

                                            HStack(spacing: StaffSpacing.sm) {
                                                Text(staffUser.staff.employeeId)
                                                    .font(.staffCaption)
                                                    .foregroundColor(.staffTextSecondary)

                                                Text("•")
                                                    .foregroundColor(.staffTextTertiary)

                                                Text(staffUser.user.role.displayName)
                                                    .font(.staffBadge)
                                                    .foregroundColor(Color.roleBadgeColor(for: staffUser.user.role.rawValue))
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.staffTextTertiary)
                                    }
                                    .padding(.horizontal, StaffSpacing.lg)
                                    .padding(.vertical, StaffSpacing.md)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Divider().background(Color.staffBorder.opacity(0.5))
                                    .padding(.leading, 64)
                            }
                        }
                    }
                }
            }
            .background(Color.staffBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.staffAccent)
                }
            }
        }
    }

    private var filteredStaff: [StaffWithUser] {
        if search.isEmpty { return staffList }
        let q = search.lowercased()
        return staffList.filter {
            $0.user.fullName.lowercased().contains(q) ||
            $0.staff.employeeId.lowercased().contains(q)
        }
    }
}
