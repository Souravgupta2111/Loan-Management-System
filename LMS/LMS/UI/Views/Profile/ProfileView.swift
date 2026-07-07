import SwiftUI
import Supabase
import PhotosUI

// MARK: - EditableProfileField
private enum EditableField {
    case name, email, phone, address
}

/// Profile View (design.md §8.9)
/// Avatar, name, email, KYC status, personal details, sign out.
/// Supports inline editing of name, phone, email, address (with address proof attachment).
struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var a11yManager = AppAccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss

    // Loaded state
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var kycStatus = "pending"
    @State private var aaConsentStatus = "pending"
    @State private var phone = ""
    @State private var pan = ""
    @State private var address = ""

    // Edit state
    @State private var isEditingName = false
    @State private var isEditingEmail = false
    @State private var isEditingPhone = false
    @State private var isEditingAddress = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var showHelpAndSupport = false

    @State private var draftName = ""
    @State private var draftEmail = ""
    @State private var draftPhone = ""
    @State private var draftAddress = ""

    // Validation errors
    @State private var nameError: String? = nil
    @State private var emailError: String? = nil
    @State private var phoneError: String? = nil

    // Address proof attachment
    @State private var addressProofItem: PhotosPickerItem? = nil
    @State private var addressProofImage: UIImage? = nil
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var saveSuccess = false

    @State private var showIncomeVerification = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.xl) {

                    // MARK: - Avatar Card
                    avatarCard

                    // MARK: - Personal Details (editable)
                    editableSection

                    // MARK: - KYC / Actions
                    actionsSection

                    // MARK: - Sign Out
                    PillButton(title: "Sign Out", style: .destructive, icon: "rectangle.portrait.and.arrow.right") {
                        Task {
                            await authViewModel.signOut()
                            dismiss()
                        }
                    }
                    .padding(.top, Spacing.md)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, 60)
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "#E7EFE5"), Color(hex: "#EFF4EA"), Color(hex: "#E7EFE5")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.textPrimary)
                    }
                }
            }
            .task { await loadProfile() }
            .overlay(saveSuccessBanner, alignment: .top)
            .onChange(of: draftName) { _, newValue in
                if newValue.isEmpty {
                    nameError = "Name is required"
                } else if !validateName(newValue) {
                    nameError = "Wrong format is being used, enter the name as correct format"
                } else {
                    nameError = nil
                }
            }
            .onChange(of: draftEmail) { _, newValue in
                if newValue.isEmpty {
                    emailError = "Email is required"
                } else if !validateEmail(newValue) {
                    emailError = "Enter the email in correct format"
                } else {
                    emailError = nil
                }
            }
            .onChange(of: draftPhone) { _, newValue in
                if newValue.isEmpty {
                    phoneError = "Phone number is required"
                } else if !validatePhone(newValue) {
                    phoneError = "Phone number should be of 10 digits"
                } else {
                    phoneError = nil
                }
            }
        }
    }

    // MARK: - Avatar Card

    private var avatarCard: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#89DBA6").opacity(0.20))
                    .frame(width: 90, height: 90)
                Circle()
                    .stroke(Color(hex: "#89DBA6"), lineWidth: 2)
                    .frame(width: 90, height: 90)
                Text(initials)
                    .font(.title.weight(.bold)).fontDesign(.rounded)
                    .foregroundColor(Color(hex: "#2D8B4E"))
            }

            Text(userName.isEmpty ? "User" : userName)
                .font(.title3.weight(.bold)).fontDesign(.rounded)
                .foregroundColor(.textPrimary)

            Text(userEmail)
                .font(.bodyRegular)
                .foregroundColor(.textSecondary)

            AccessibleStatusBadge(status: kycStatus == "verified" ? "verified" : "pending")
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
        .liquidGlass(cornerRadius: 22, tint: Color(hex: "#2D8B4E"), tintOpacity: 0.04)
    }

    // MARK: - Editable Section

    private var editableSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Personal Details")

            editableRow(
                label: "Full Name",
                icon: "person.fill",
                value: userName.isEmpty ? "Not set" : userName,
                isEditing: isEditingName,
                draft: $draftName,
                errorMessage: nameError,
                onEdit: {
                    draftName = userName
                    nameError = nil
                    isEditingName = true
                },
                onSave: {
                    Task { await saveName() }
                },
                onCancel: { 
                    isEditingName = false
                    nameError = nil
                }
            )

            divider

            editableRow(
                label: "Email",
                icon: "envelope.fill",
                value: userEmail.isEmpty ? "Not set" : userEmail,
                isEditing: isEditingEmail,
                draft: $draftEmail,
                errorMessage: emailError,
                onEdit: {
                    draftEmail = userEmail
                    emailError = nil
                    isEditingEmail = true
                },
                onSave: {
                    Task { await saveEmail() }
                },
                onCancel: { 
                    isEditingEmail = false
                    emailError = nil
                }
            )

            divider

            editableRow(
                label: "Phone",
                icon: "phone.fill",
                value: phone.isEmpty ? "Not set" : phone,
                isEditing: isEditingPhone,
                draft: $draftPhone,
                keyboardType: .phonePad,
                errorMessage: phoneError,
                onEdit: {
                    draftPhone = phone
                    phoneError = nil
                    isEditingPhone = true
                },
                onSave: {
                    Task { await savePhone() }
                },
                onCancel: { 
                    isEditingPhone = false
                    phoneError = nil
                }
            )

            divider

            // Address row with proof attachment
            addressRow

            divider

            // Read-only KYC row
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color(hex: "#89DBA6").opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: "checkmark.seal.fill").foregroundColor(Color(hex: "#2D8B4E")).font(.subheadline)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("KYC Status")
                        .font(.bodyLarge)
                        .foregroundColor(.textPrimary)
                }
                Spacer()
                StatusBadge(status: kycStatus == "verified" ? "verified" : "pending")
            }
            .padding(Spacing.lg)

            divider

            // Income Verification Row
            Button {
                showIncomeVerification = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(hex: "#89DBA6").opacity(0.15)).frame(width: 32, height: 32)
                        Image(systemName: "banknote.fill").foregroundColor(Color(hex: "#2D8B4E")).font(.subheadline)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Income Verification")
                            .font(.bodyLarge)
                            .foregroundColor(.textPrimary)
                    }
                    Spacer()
                    if (aaConsentStatus.uppercased() == "ACTIVE" || aaConsentStatus.uppercased() == "APPROVED") {
                        StatusBadge(status: "verified")
                    } else {
                        Image(systemName: "chevron.right").foregroundColor(.textTertiary)
                    }
                }
                .padding(Spacing.lg)
            }
            .buttonStyle(.plain)
        }
        .liquidGlass(cornerRadius: 22)
        .sheet(isPresented: $showIncomeVerification) {
            IncomeVerificationView(mobileNumber: phone) {
                Task {
                    await loadProfile() // Refresh after verification
                }
            }
        }
    }

    private var addressRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(Color(hex: "#89DBA6").opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: "mappin.and.ellipse").foregroundColor(Color(hex: "#2D8B4E")).font(.subheadline)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Address").font(.caption.weight(.medium)).foregroundColor(.textSecondary)
                    if isEditingAddress {
                        TextField("Enter your address", text: $draftAddress, axis: .vertical)
                            .font(.bodyLarge)
                            .foregroundColor(.textPrimary)
                            .lineLimit(1...3)
                        
                        // Address proof attachment nested here
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ADDRESS PROOF")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.textSecondary)
                                .tracking(1.2)
                                .padding(.top, 4)

                            PhotosPicker(selection: $addressProofItem, matching: .images) {
                                HStack(spacing: 10) {
                                    if let img = addressProofImage {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        Text("Change photo")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: "#2D8B4E"))
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                                .foregroundColor(Color(hex: "#89DBA6").opacity(0.5))
                                                .frame(width: 60, height: 60)
                                            Image(systemName: "plus")
                                                .foregroundColor(Color(hex: "#2D8B4E"))
                                        }
                                        Text("Attach proof document")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: "#2D8B4E"))
                                    }
                                    Spacer()
                                }
                            }
                            .onChange(of: addressProofItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let img = UIImage(data: data) {
                                        addressProofImage = img
                                    }
                                }
                            }

                            HStack(spacing: Spacing.md) {
                                Button { isEditingAddress = false } label: {
                                    Text("Cancel")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.surfaceMuted)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task { await saveAddress() }
                                } label: {
                                    HStack {
                                        if isSaving {
                                            ProgressView().tint(.white)
                                        } else {
                                            Text("Save")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(hex: "#2D8B4E"))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(isSaving)
                            }
                            .padding(.top, 4)
                        }
                        .transition(.opacity)
                    } else {
                        Text(address.isEmpty ? "please enter your address" : address)
                            .font(.bodyLarge)
                            .foregroundColor(address.isEmpty ? .textSecondary : .textPrimary)
                    }
                }
                Spacer()
                if isEditingAddress {
                    Button { isEditingAddress = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textTertiary)
                            .font(.title3)
                    }
                } else {
                    Button {
                        draftAddress = address
                        isEditingAddress = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#E0E0E0"))
                                .frame(width: 28, height: 28)
                            Image(systemName: "pencil")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.black)
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Settings")
            
            Toggle(isOn: $a11yManager.isHapticsEnabled) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#89DBA6").opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(Color(hex: "#2D8B4E"))
                            .font(.subheadline)
                    }
                    Text("Haptic Feedback")
                        .font(.bodyRegular)
                        .foregroundColor(.textPrimary)
                }
            }
            .tint(Color(hex: "#2D8B4E"))
            .padding(Spacing.lg)
            
            divider
            
            Toggle(isOn: $a11yManager.isHighContrastEnabled) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#89DBA6").opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundColor(Color(hex: "#2D8B4E"))
                            .font(.subheadline)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("High Contrast Mode")
                            .font(.bodyRegular)
                            .foregroundColor(.textPrimary)
                        Text("Color blind safe shapes & contrast")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .tint(Color(hex: "#2D8B4E"))
            .padding(Spacing.lg)
            
            divider
            
            Toggle(isOn: $notificationsEnabled) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#89DBA6").opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "bell.fill")
                            .foregroundColor(Color(hex: "#2D8B4E"))
                            .font(.subheadline)
                    }
                    Text("Notifications")
                        .font(.bodyLarge)
                        .foregroundColor(.textPrimary)
                }
            }
            .tint(Color(hex: "#2D8B4E"))
            .padding(Spacing.lg)
            .onChange(of: notificationsEnabled) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "notificationsEnabled")
            }
            
            divider
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHelpAndSupport.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#89DBA6").opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(Color(hex: "#2D8B4E"))
                            .font(.subheadline)
                    }
                    Text("Help & Support")
                        .font(.bodyLarge)
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
                .padding(Spacing.lg)
            }
            .buttonStyle(.plain)
            
            if showHelpAndSupport {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Contact Customer Care")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.textPrimary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(Color(hex: "#2D8B4E"))
                                .font(.caption)
                            Text("support@loanmanagement.com")
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .foregroundColor(Color(hex: "#2D8B4E"))
                                .font(.caption)
                            Text("1800-200-5678 (Toll Free)")
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .liquidGlass(cornerRadius: 22)
    }

    // MARK: - Reusable Subviews

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.textSecondary)
            .tracking(1.2)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, 4)
    }

    private var divider: some View {
        Divider()
            .padding(.leading, Spacing.lg)
    }

    @ViewBuilder
    private func editableRow(
        label: String,
        icon: String,
        value: String,
        isEditing: Bool,
        draft: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        errorMessage: String? = nil,
        onEdit: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#89DBA6").opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .foregroundColor(Color(hex: "#2D8B4E"))
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.textSecondary)
                    if isEditing {
                        TextField(label, text: draft)
                            .font(.bodyLarge)
                            .foregroundColor(.textPrimary)
                            .keyboardType(keyboardType)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.accentRed)
                        }
                    } else {
                        Text(value)
                            .font(.bodyLarge)
                            .foregroundColor(.textPrimary)
                    }
                }

                Spacer()

                if isEditing {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textTertiary)
                            .font(.title3)
                    }
                } else {
                    Button(action: onEdit) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#E0E0E0"))
                                .frame(width: 28, height: 28)
                            Image(systemName: "pencil")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.black)
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .contentShape(Rectangle())

            if isEditing {
                HStack(spacing: Spacing.md) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.surfaceMuted)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onSave) {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(errorMessage != nil ? Color.textTertiary : Color(hex: "#2D8B4E"))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || errorMessage != nil)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.2), value: isEditing)
            }
        }
    }

    private func actionRow(icon: String, title: String, color: Color) -> some View {
        Button { } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#89DBA6").opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .foregroundColor(Color(hex: "#2D8B4E"))
                        .font(.subheadline)
                }
                Text(title)
                    .font(.bodyRegular)
                    .foregroundColor(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
            .padding(Spacing.lg)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var saveSuccessBanner: some View {
        if saveSuccess {
            Text("✓ Saved successfully")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(hex: "#2D8B4E"))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private var initials: String {
        let parts = userName.components(separatedBy: " ")
        let first = parts.first?.prefix(1) ?? "U"
        let last = parts.count > 1 ? String(parts.last!.prefix(1)) : ""
        return "\(first)\(last)".uppercased()
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        userEmail = authViewModel.currentUser?.email ?? ""

        do {
            let users: [ProfileRow] = try await SupabaseManager.shared.client
                .from("users")
                .select("full_name, phone")
                .eq("id", value: userId.uuidString)
                .execute()
                .value
            if let row = users.first {
                userName = row.fullName
                phone = row.phone ?? ""
            }

            let profiles: [BorrowerRow] = try await SupabaseManager.shared.client
                .from("borrower_profiles")
                .select("kyc_status, pan_number, address_line1, aa_consent_status")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            if let profile = profiles.first {
                kycStatus = profile.kycStatus
                aaConsentStatus = profile.aaConsentStatus ?? "pending"
                pan = profile.panNumber ?? ""
                address = profile.address ?? ""
            }
        } catch {
            print("Profile load error: \(error)")
        }
    }

    // MARK: - Save Handlers

    private func saveName() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await SupabaseManager.shared.client
                .from("users")
                .update(["full_name": draftName])
                .eq("id", value: userId.uuidString)
                .execute()
            userName = draftName
            isEditingName = false
            showSuccessBanner()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func saveEmail() async {
        // Email changes go through Supabase Auth update
        isSaving = true
        defer { isSaving = false }
        do {
            try await SupabaseManager.shared.client.auth.update(user: UserAttributes(email: draftEmail))
            userEmail = draftEmail
            isEditingEmail = false
            showSuccessBanner()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func savePhone() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await SupabaseManager.shared.client
                .from("users")
                .update(["phone": draftPhone])
                .eq("id", value: userId.uuidString)
                .execute()
            phone = draftPhone
            isEditingPhone = false
            showSuccessBanner()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func saveAddress() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await SupabaseManager.shared.client
                .from("borrower_profiles")
                .update(["address_line1": draftAddress])
                .eq("user_id", value: userId.uuidString)
                .execute()
            address = draftAddress
            isEditingAddress = false
            showSuccessBanner()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func validateName(_ name: String) -> Bool {
        let nameRegEx = "^[A-Za-z ]+$"
        let namePred = NSPredicate(format:"SELF MATCHES %@", nameRegEx)
        return namePred.evaluate(with: name)
    }

    private func validateEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    private func validatePhone(_ phone: String) -> Bool {
        let phoneRegEx = "^[0-9]{10}$"
        let phonePred = NSPredicate(format:"SELF MATCHES %@", phoneRegEx)
        return phonePred.evaluate(with: phone)
    }

    private func showSuccessBanner() {
        withAnimation { saveSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saveSuccess = false }
        }
    }
}

// MARK: - Decodable Models
private struct ProfileRow: Decodable {
    let fullName: String
    let phone: String?
    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case phone
    }
}

private struct BorrowerRow: Decodable {
    let kycStatus: String
    let panNumber: String?
    let address: String?
    let aaConsentStatus: String?
    enum CodingKeys: String, CodingKey {
        case kycStatus = "kyc_status"
        case panNumber = "pan_number"
        case address = "address_line1"
        case aaConsentStatus = "aa_consent_status"
    }
}
