//
//  BorrowerSearchView.swift
//  LMS Staff
//
//  Admin Borrower database search screen showing KYC status and repayment histories.
//

import SwiftUI
import Supabase

struct BorrowerSearchView: View {
    @State private var searchText: String = ""
    @State private var borrowers: [BorrowerProfile] = []
    @State private var filteredBorrowers: [BorrowerProfile] = []
    @State private var selectedBorrower: BorrowerProfile?
    @State private var borrowerUser: AppUser?
    @State private var borrowerLoans: [Loan] = []
    @State private var isLoading: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Search List
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
                    Text("Borrower Database")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                        .padding(.horizontal, StaffSpacing.lg)
                        .padding(.top, StaffSpacing.lg)
                    
                    TextField("Search", text: $searchText)
                        .padding(12)
                        .background(Color.staffSurface)
                        .cornerRadius(StaffCorner.md)
                        .foregroundColor(.staffTextPrimary)
                        .padding(StaffSpacing.lg)
                        .onChange(of: searchText) { _ in
                            applyFilters()
                        }
                }
                .background(Color.white)
                
                Divider()
                    .background(Color.staffBorder)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if filteredBorrowers.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "person.text.rectangle",
                        title: "No Borrowers Found",
                        message: "Search matches no borrower profiles in the system."
                    )
                    Spacer()
                } else {
                    List(filteredBorrowers, selection: $selectedBorrower) { borrower in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(borrower.panNumber ?? "PAN-N/A")
                                .font(.staffBody)
                                .fontWeight(.bold)
                                .foregroundColor(.staffTextPrimary)
                            
                            HStack {
                                Text("Score: \(borrower.creditScore ?? 300)")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                Spacer()
                                Text(borrower.kycStatus.displayName)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(borrower.kycStatus == .verified ? .staffGreen : .staffAmber)
                            }
                        }
                        .padding(.vertical, 4)
                        .tag(borrower)
                        .listRowBackground(
                            selectedBorrower?.id == borrower.id
                            ? Color.staffAccent.opacity(0.15)
                            : Color.white
                        )
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.staffBackground)
                }
            }
            .frame(width: 340)
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // Right detailed profile panel
            if let borrower = selectedBorrower {
                borrowerProfileInspector(borrower)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "person.text.rectangle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select a Borrower to Inspect Profile")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.staffSurface.opacity(0.1))
            }
        }
        .background(Color.staffBackground)
        .task {
            await loadBorrowers()
        }
        .onChange(of: selectedBorrower) { borrower in
            if let b = borrower {
                Task {
                    await loadSelectedBorrowerDetails(b)
                }
            }
        }
    }
    
    // MARK: - Inspector Subviews
    
    @ViewBuilder
    private func borrowerProfileInspector(_ item: BorrowerProfile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Info banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(borrowerUser?.fullName ?? "Borrower Profile")
                        .font(.staffTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.staffTextPrimary)
                    Text("System User ID: \(item.userId.uuidString.prefix(8)) | KYC: \(item.kycStatus.displayName)")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffBackground)
            
            ScrollView {
                VStack(spacing: StaffSpacing.lg) {
                    // KYC particulars card
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("KYC Verification Details")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            KYCRow(label: "Aadhaar Card Number", value: item.aadhaarNumber ?? "N/A")
                            KYCRow(label: "PAN Card ID", value: item.panNumber ?? "N/A")
                            let incomeVal = item.verifiedAnnualIncome != nil ? (item.verifiedAnnualIncome! / 12) : item.monthlyIncome
                            KYCRow(label: "Monthly Salary Income", value: incomeVal != nil ? "INR \(String(format: "%.2f", incomeVal!))" : "N/A")
                            KYCRow(label: "Residential Address", value: "\(item.addressLine1 ?? ""), \(item.city ?? ""), \(item.state ?? "") - \(item.pincode ?? "")")
                        }
                    }
                    
                    // Historical Loans
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Borrower Repayment History")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            if borrowerLoans.isEmpty {
                                Text("No loan history matches for this borrower.")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                            } else {
                                ForEach(borrowerLoans) { loan in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(loan.loanNumber ?? "LMS-XXXX")
                                                .font(.staffBody)
                                                .fontWeight(.bold)
                                                .foregroundColor(.staffTextPrimary)
                                            Text("Disbursed Date: \(loan.disbursementDate ?? "")")
                                                .font(.staffCaption)
                                                .foregroundColor(.staffTextSecondary)
                                        }
                                        Spacer()
                                        StaffStatusBadge(status: loan.status.displayName)
                                    }
                                    .padding(.vertical, 4)
                                    
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding(StaffSpacing.lg)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadBorrowers() async {
        isLoading = true
        do {
            let list: [BorrowerProfile] = try await SupabaseManager.shared.database
                .from("borrower_profiles")
                .select()
                .execute()
                .value
            
            self.borrowers = list
            self.filteredBorrowers = list
        } catch {
            print("Error loading borrowers: \(error)")
        }
        isLoading = false
    }
    
    private func loadSelectedBorrowerDetails(_ b: BorrowerProfile) async {
        do {
            // Fetch users row
            let user: AppUser = try await SupabaseManager.shared.database
                .from("users")
                .select()
                .eq("id", value: b.userId)
                .single()
                .execute()
                .value
            self.borrowerUser = user
            
            // Fetch loans list
            let loans: [Loan] = try await SupabaseManager.shared.database
                .from("loans")
                .select()
                .eq("borrower_id", value: b.userId)
                .execute()
                .value
            self.borrowerLoans = loans
        } catch {
            print("Error loading borrower details: \(error)")
        }
    }
    
    private func applyFilters() {
        if searchText.isEmpty {
            filteredBorrowers = borrowers
        } else {
            let query = searchText.lowercased()
            filteredBorrowers = borrowers.filter {
                ($0.panNumber ?? "").lowercased().contains(query) ||
                ($0.aadhaarNumber ?? "").lowercased().contains(query) ||
                ($0.city ?? "").lowercased().contains(query)
            }
        }
    }
}
