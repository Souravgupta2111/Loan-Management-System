//
//  MetricDetailSheet.swift
//  LMS Staff
//
//  Generic sheet to present list drill-downs for dashboard metrics.
//

import SwiftUI

enum MetricDataType {
    case loans([LoanWithDetails])
    case applications([ApplicationWithBorrower])
}

struct MetricDetailSheet: View {
    let title: String
    let data: MetricDataType
    
    @State private var selectedLoan: LoanWithDetails?
    @State private var selectedApplication: ApplicationWithBorrower?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.staffBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: StaffSpacing.md) {
                            switch data {
                            case .loans(let loans):
                                if loans.isEmpty {
                                    EmptyStateView(icon: "list.bullet.rectangle", title: "No Data", message: "No loans match this metric.")
                                        .padding(.top, 40)
                                } else {
                                    ForEach(loans) { loan in
                                        Button(action: {
                                            selectedLoan = loan
                                        }) {
                                            LoanRow(loan: loan)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            case .applications(let apps):
                                if apps.isEmpty {
                                    EmptyStateView(icon: "list.bullet.rectangle", title: "No Data", message: "No applications match this metric.")
                                        .padding(.top, 40)
                                } else {
                                    ForEach(apps) { app in
                                        Button(action: {
                                            selectedApplication = app
                                        }) {
                                            ApplicationRow(app: app)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(StaffSpacing.md)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .background(
                NavigationLink(
                    destination: selectedLoan.map { LoanDetailView(loanWithDetails: $0) },
                    isActive: Binding(
                        get: { selectedLoan != nil },
                        set: { if !$0 { selectedLoan = nil } }
                    )
                ) { EmptyView() }
                .hidden()
            )
            .background(
                NavigationLink(
                    destination: selectedApplication.map { 
                        ApplicationDetailView(appWithBorrower: $0, onStatusUpdated: {}) 
                    },
                    isActive: Binding(
                        get: { selectedApplication != nil },
                        set: { if !$0 { selectedApplication = nil } }
                    )
                ) { EmptyView() }
                .hidden()
            )
        }
    }
}

// MARK: - Row Subviews

struct LoanRow: View {
    let loan: LoanWithDetails
    
    var body: some View {
        StaffCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.borrower.fullName)
                        .font(.staffBody)
                        .fontWeight(.bold)
                        .foregroundColor(.staffTextPrimary)
                    
                    Text("Loan No: \(loan.loan.loanNumber ?? "N/A")")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("INR \(String(format: "%.2f", loan.loan.outstandingPrincipal))")
                        .font(.staffBody)
                        .fontWeight(.medium)
                        .foregroundColor(.staffAccent)
                    
                    StaffStatusBadge(status: loan.loan.status.displayName)
                }
            }
        }
    }
}

struct ApplicationRow: View {
    let app: ApplicationWithBorrower
    
    var body: some View {
        StaffCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.borrower.fullName)
                        .font(.staffBody)
                        .fontWeight(.bold)
                        .foregroundColor(.staffTextPrimary)
                    
                    Text("App ID: \(app.application.id.uuidString.prefix(8))")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("INR \(String(format: "%.2f", app.application.requestedAmount))")
                        .font(.staffBody)
                        .fontWeight(.medium)
                        .foregroundColor(.staffAccent)
                    
                    StaffStatusBadge(status: app.application.status.displayName)
                }
            }
        }
    }
}
