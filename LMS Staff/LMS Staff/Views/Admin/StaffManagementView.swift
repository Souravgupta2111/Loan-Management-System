//
//  StaffManagementView.swift
//  LMS Staff
//
//  Staff Management admin console supporting staff listing, creation, role change, and status toggle.
//  Includes a master-detail layout for editing staff permissions.
//

import SwiftUI

struct StaffManagementView: View {
    @StateObject private var vm = StaffManagementViewModel()
    @State private var showCreateSheet: Bool = false
    
    @State private var selectedStaff: StaffWithUser?
    
    // Create form values
    @State private var inputName: String = ""
    @State private var inputEmail: String = ""
    @State private var selectedRole: UserRole = .officer
    @State private var inputDesignation: String = "Loan Officer"
    @State private var selectedBranchId: UUID = UUID()
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: Staff List
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Staff Accounts")
                            .font(.staffTitle)
                            .foregroundColor(.staffTextPrimary)
                            .accessibilityAddTraits(.isHeader)
                        
                        Spacer()
                        
                        Button(action: {
                            if let firstBranch = vm.branches.first {
                                selectedBranchId = firstBranch.id
                            }
                            showCreateSheet = true
                        }) {
                            Image(systemName: "person.badge.plus")
                                .font(.title3)
                                .foregroundColor(.staffAccent)
                        }
                        .accessibilityLabel("Add staff member")
                    }
                    .padding(StaffSpacing.lg)
                    
                    TextField("Search staff list...", text: $vm.searchText)
                        .padding(12)
                        .background(Color.staffSurface)
                        .cornerRadius(StaffCorner.md)
                        .foregroundColor(.staffTextPrimary)
                        .padding(StaffSpacing.lg)
                }
                .background(Color.staffPanel)
                
                Divider().background(Color.staffBorder)
                
                if vm.isLoading && vm.staffList.isEmpty {
                    Spacer()
                    ProgressView("Fetching staff accounts list...")
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if vm.filteredStaff.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "person.crop.circle.badge.exclamationmark",
                        title: "No Staff Accounts",
                        message: "No staff members match the current search filters."
                    )
                    Spacer()
                } else {
                    List(vm.filteredStaff, selection: $selectedStaff) { item in
                        HStack(spacing: StaffSpacing.md) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .foregroundColor(item.user.isActive ? .staffAccent : .staffTextSecondary)
                                .accessibilityHidden(true)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.user.fullName)
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                
                                Text("\(item.staff.employeeId) | \(item.user.role.displayName)")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .tag(item)
                        .listRowBackground(
                            selectedStaff?.id == item.id
                            ? Color.staffAccent.opacity(0.15)
                            : Color.staffPanel
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Double tap to open")
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.staffBackground)
                }
            }
            .frame(width: 340)
            .background(Color.staffBackground)
            
            Divider().background(Color.staffBorder)
            
            // Right: Detail View
            if let selected = selectedStaff {
                StaffProfileDetailView(
                    item: selected,
                    viewModel: vm,
                    onUpdate: { updatedItem in
                        selectedStaff = updatedItem
                    }
                )
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "person.text.rectangle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                        .accessibilityHidden(true)
                    Text("Select a Staff Member")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextSecondary)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.staffSurface.opacity(0.1))
            }
        }
        .background(Color.staffBackground)
        .onAppear {
            Task {
                await vm.loadStaffAndBranches()
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            createStaffSheetView
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
    
    // MARK: - Create Staff View Sheet
    
    private var createStaffSheetView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: StaffSpacing.xl) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 56))
                        .foregroundColor(.staffAccent)
                        .padding(.top, StaffSpacing.xl)
                        .accessibilityHidden(true)
                    
                    Text("Create New Staff Account")
                        .font(.staffSectionTitle)
                        .foregroundColor(.staffTextPrimary)
                    
                    VStack(spacing: StaffSpacing.lg) {
                        StaffFormField(label: "Full Name *", placeholder: "Enter staff member name", text: $inputName, icon: "person")
                        StaffFormField(label: "Employee Email", placeholder: "employee@company.com", text: $inputEmail, keyboardType: .emailAddress, icon: "envelope")
                        
                        createStaffMenu(label: "Designation / Position Title *", value: inputDesignation, icon: "briefcase") {
                            Button("System Administrator") { inputDesignation = "System Administrator" }
                            Button("Branch Manager") { inputDesignation = "Branch Manager" }
                            Button("Loan Officer") { inputDesignation = "Loan Officer" }
                        }
                        
                        createStaffMenu(
                            label: "Branch",
                            value: vm.branches.first(where: { $0.id == selectedBranchId })?.name ?? "Select branch",
                            icon: "building.2"
                        ) {
                            ForEach(vm.branches) { branch in
                                Button(branch.name) { selectedBranchId = branch.id }
                            }
                        }
                    }
                    .padding(.horizontal, StaffSpacing.xl)
                    
                    StaffButton(title: "Generate Access", style: .primary, icon: "paperplane.fill") {
                        Task {
                            _ = await vm.createStaffAccount(
                                fullName: inputName,
                                role: selectedRole,
                                designation: inputDesignation,
                                branchId: selectedBranchId,
                                email: inputEmail
                            )
                        }
                    }
                    .disabled(inputName.trimmingCharacters(in: .whitespaces).isEmpty || inputDesignation.isEmpty)
                    .padding(.horizontal, StaffSpacing.xl)
                    .padding(.bottom, StaffSpacing.xl)
                }
            }
            .background(Color.staffBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showCreateSheet = false
                        inputName = ""
                        inputEmail = ""
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.staffAccent)
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationBackground(Color.staffBackground)
        .alert(isPresented: $vm.showCredentialsAlert) {
            Alert(
                title: Text("✅ Account Created Successfully"),
                message: Text("A new staff account has been provisioned.\n\nSecure login credentials and instructions have been automatically emailed to \(inputEmail.isEmpty ? "the provided email address" : inputEmail)."),
                dismissButton: .default(Text("Done")) {
                    vm.newlyCreatedCredentials = nil
                    showCreateSheet = false
                    inputName = ""
                    inputEmail = ""
                }
            )
        }
    }
    
    @ViewBuilder
    private func createStaffMenu<Content: View>(label: String, value: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: StaffSpacing.sm) {
            Text(label)
                .font(.staffLabel)
                .foregroundColor(.staffTextSecondary)
            
            Menu {
                content()
            } label: {
                HStack(spacing: StaffSpacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.staffTextTertiary)
                        .frame(width: 20)
                    Text(value)
                        .font(.staffBody)
                        .foregroundColor(value == "Select branch" ? .staffTextTertiary : .staffTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.staffAccent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.staffSurfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: StaffCorner.md))
                .overlay(
                    RoundedRectangle(cornerRadius: StaffCorner.md)
                        .stroke(Color.staffBorder, lineWidth: 1.5)
                )
            }
        }
    }
}

// MARK: - Detail Panel
struct StaffProfileDetailView: View {
    let item: StaffWithUser
    @ObservedObject var viewModel: StaffManagementViewModel
    var onUpdate: (StaffWithUser) -> Void
    
    @State private var editMode = false
    
    // Editable fields
    @State private var designation: String = ""
    @State private var department: String = ""
    @State private var limitText: String = ""
    @State private var selectedManager: UUID? = nil
    @State private var canDisburse: Bool = false
    @State private var isActive: Bool = false
    @State private var selectedRole: UserRole = .officer
    @State private var selectedBranchId: UUID? = nil
    
    // Reset password flow
    @State private var showResetSheet: Bool = false
    @State private var resetEmail: String = ""
    
    enum ActiveAlert: Identifiable {
        case confirmSave
        case resetSuccess(password: String, email: String)
        
        var id: String {
            switch self {
            case .confirmSave: return "confirmSave"
            case .resetSuccess: return "resetSuccess"
            }
        }
    }
    @State private var activeAlert: ActiveAlert? = nil
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: StaffSpacing.lg) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.staffAccent)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.user.fullName)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.staffTextPrimary)
                    Text("\(item.staff.employeeId) | \(item.user.email ?? "No email")")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                
                Spacer()
                
                if !editMode {
                    HStack(spacing: StaffSpacing.md) {
                        StaffButton(title: "Reset Password", style: .destructive, icon: "key.fill", isFullWidth: false) {
                            resetEmail = item.user.email ?? ""
                            showResetSheet = true
                        }
                        .frame(width: 160)
                        
                        StaffButton(title: "Edit Profile", style: .secondary, icon: "pencil", isFullWidth: false) {
                            startEditing()
                        }
                        .frame(width: 140)
                    }
                }
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffBackground)
            
            Divider().background(Color.staffBorder)
            
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.xl) {
                    
                    // Access Controls & Role
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Access & Role")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Divider()
                            
                            if editMode {
                                Picker("System Role", selection: $selectedRole) {
                                    Text("System Administrator").tag(UserRole.admin)
                                    Text("Branch Manager").tag(UserRole.manager)
                                    Text("Loan Officer").tag(UserRole.officer)
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding(8)
                                .background(Color.staffSurfaceMuted)
                                .cornerRadius(StaffCorner.sm)
                                .foregroundColor(.staffTextPrimary)
                                
                                Toggle("Account Active", isOn: $isActive)
                                    .padding(.vertical, 4)
                                    .tint(.staffAccent)
                                
                                Toggle("Can Disburse Funds", isOn: $canDisburse)
                                    .padding(.vertical, 4)
                                    .tint(.staffAccent)
                            } else {
                                detailRow(title: "System Role", value: item.user.role.displayName)
                                detailRow(title: "Account Status", value: item.user.isActive ? "Active" : "Inactive")
                                detailRow(title: "Can Disburse", value: item.staff.canDisburse ? "Yes" : "No")
                            }
                        }
                    }
                    
                    // Professional Details
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Professional Info")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Divider()
                            
                            if editMode {
                                StaffFormField(label: "Designation", placeholder: "e.g. Loan Officer", text: $designation, error: nil)
                                StaffFormField(label: "Department", placeholder: "e.g. Retail Lending", text: $department, error: nil)
                                
                                Text("Reports To (Manager)")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                Picker("Reports To", selection: $selectedManager) {
                                    Text("None").tag(Optional<UUID>.none)
                                    ForEach(viewModel.staffList.filter { $0.user.role == .manager || $0.user.role == .admin }) { manager in
                                        if manager.id != item.id {
                                            Text(manager.user.fullName).tag(Optional(manager.id))
                                        }
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding(8)
                                .background(Color.staffSurfaceMuted)
                                .cornerRadius(StaffCorner.sm)
                                .foregroundColor(.staffTextPrimary)
                                
                                Text("Assigned Branch")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                Picker("Branch", selection: $selectedBranchId) {
                                    Text("None").tag(Optional<UUID>.none)
                                    ForEach(viewModel.branches) { branch in
                                        Text(branch.name).tag(Optional(branch.id))
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding(8)
                                .background(Color.staffSurfaceMuted)
                                .cornerRadius(StaffCorner.sm)
                                .foregroundColor(.staffTextPrimary)
                            } else {
                                detailRow(title: "Designation", value: item.staff.designation ?? "None")
                                detailRow(title: "Department", value: item.staff.department ?? "None")
                                
                                let branchName = viewModel.branches.first(where: { $0.id == item.staff.branchId })?.name ?? "None"
                                detailRow(title: "Assigned Branch", value: branchName)
                                
                                let managerName = viewModel.staffList.first(where: { $0.id == item.staff.reportsTo })?.user.fullName ?? "None"
                                detailRow(title: "Reports To", value: managerName)
                            }
                        }
                    }
                    
                    // Approval Limits
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Approval Limits")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Divider()
                            
                            if editMode {
                                StaffFormField(label: "Max Loan Approval Limit (INR)", placeholder: "e.g. 500000", text: $limitText, error: nil)
                            } else {
                                let limitValue = item.staff.maxLoanApprovalLimit.map { String(format: "₹%.2f", $0) } ?? "No Limit Assigned"
                                detailRow(title: "Max Approval Limit", value: limitValue)
                            }
                        }
                    }
                    
                }
                .padding(StaffSpacing.lg)
            }
            
            if editMode {
                Divider().background(Color.staffBorder)
                HStack {
                    Button("Cancel") {
                        editMode = false
                    }
                    .foregroundColor(.staffTextSecondary)
                    
                    Spacer()
                    
                    StaffButton(title: "Save Changes", style: .primary, icon: "checkmark") {
                        saveChanges()
                    }
                    .frame(width: 180)
                }
                .padding(StaffSpacing.lg)
                .background(Color.staffSurface)
            }
        }
            
            if viewModel.isLoading {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                VStack(spacing: StaffSpacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .staffAccent))
                        .scaleEffect(1.5)
                    
                    Text("Please wait...")
                        .font(.staffBody)
                        .foregroundColor(.staffTextPrimary)
                        .fontWeight(.medium)
                }
                .padding(30)
                .background(Color.staffSurface)
                .cornerRadius(StaffCorner.md)
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            syncData()
        }
        .onChange(of: item) { _ in
            syncData()
            editMode = false
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .confirmSave:
                return Alert(
                    title: Text("Confirm Profile Update"),
                    message: Text("Are you sure you want to save these changes? Modifying roles or access limits may immediately affect the user's permissions."),
                    primaryButton: .default(Text("Save Changes")) {
                        executeSave()
                    },
                    secondaryButton: .cancel()
                )
            case .resetSuccess(_, let email):
                return Alert(
                    title: Text("✅ Password Reset Successfully"),
                    message: Text("The employee's password has been reset.\n\nNew secure credentials have been automatically emailed to \(email)."),
                    dismissButton: .default(Text("Done")) {
                        viewModel.resetPasswordResult = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showResetSheet) {
            resetPasswordSheet
        }
        .accessibleAnimation(.easeInOut, value: viewModel.isLoading)
    }
    
    private func syncData() {
        designation = item.staff.designation ?? ""
        department = item.staff.department ?? ""
        limitText = item.staff.maxLoanApprovalLimit.map { String($0) } ?? ""
        selectedManager = item.staff.reportsTo
        canDisburse = item.staff.canDisburse
        isActive = item.user.isActive
        selectedRole = item.user.role
        selectedBranchId = item.staff.branchId
    }
    
    private func startEditing() {
        syncData()
        editMode = true
    }
    
    private func saveChanges() {
        activeAlert = .confirmSave
    }
    
    private func executeSave() {
        let limit = Double(limitText)
        Task {
            // Check if role changed
            if selectedRole != item.user.role {
                await viewModel.changeStaffRole(userId: item.user.id, profileId: item.staff.id, employeeId: item.staff.employeeId, newRole: selectedRole)
            }
            
            // Check if active changed
            if isActive != item.user.isActive {
                await viewModel.toggleStaffActiveStatus(userId: item.user.id, isActive: isActive)
            }
            
            await viewModel.updateStaffProfile(
                profileId: item.staff.id,
                department: department.isEmpty ? nil : department,
                designation: designation.isEmpty ? nil : designation,
                reportsTo: selectedManager,
                maxLoanApprovalLimit: limit,
                canDisburse: canDisburse,
                branchId: selectedBranchId
            )
            
            editMode = false
            // Find updated item and pass to callback
            if let updated = viewModel.staffList.first(where: { $0.id == item.id }) {
                onUpdate(updated)
            }
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.staffBody)
                .foregroundColor(.staffTextSecondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.staffBody)
                .foregroundColor(.staffTextPrimary)
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Reset Password Sheet
    
    private var resetPasswordSheet: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: StaffSpacing.xl) {
                    Image(systemName: "key.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.staffRed)
                        .padding(.top, StaffSpacing.xl)
                        .accessibilityHidden(true)
                    
                    Text("Reset Password")
                        .font(.staffSectionTitle)
                        .foregroundColor(.staffTextPrimary)
                    
                    VStack(spacing: StaffSpacing.lg) {
                        Text("Employee: \(item.user.fullName) (\(item.staff.employeeId))")
                            .font(.staffBody)
                            .foregroundColor(.staffTextPrimary)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        StaffFormField(
                            label: "Employee Email Address *",
                            placeholder: "employee@company.com",
                            text: $resetEmail,
                            error: resetEmail.isEmpty ? "Email is required to send credentials" : nil,
                            keyboardType: .emailAddress,
                            icon: "envelope"
                        )
                    }
                    .padding(.horizontal, StaffSpacing.xl)
                    
                    StaffButton(title: "Reset & Send Credentials", style: .destructive, icon: "paperplane.fill") {
                        Task {
                            showResetSheet = false
                            let success = await viewModel.resetStaffPassword(
                                userId: item.user.id,
                                employeeId: item.staff.employeeId,
                                email: resetEmail
                            )
                            if success, let res = viewModel.resetPasswordResult {
                                try? await Task.sleep(nanoseconds: 600_000_000)
                                activeAlert = .resetSuccess(password: res.password, email: resetEmail)
                            }
                        }
                    }
                    .disabled(resetEmail.isEmpty)
                    .padding(.horizontal, StaffSpacing.xl)
                    .padding(.bottom, StaffSpacing.xl)
                }
            }
            .background(Color.staffBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showResetSheet = false
                        resetEmail = ""
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.staffAccent)
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationBackground(Color.staffBackground)
    }
}
