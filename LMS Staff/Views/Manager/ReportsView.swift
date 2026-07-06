//
//  ReportsView.swift
//  LMS Staff
//
//  Reports generator and exporter (PDF / CSV) with sharing support.
//

import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ReportsView: View {
    @State private var selectedReportType: String = "Portfolio Summary"
    @State private var startDate = Date().addingTimeInterval(-2592000) // 30 days ago
    @State private var endDate = Date()
    @State private var isGenerating: Bool = false
    
    // Sharing state
    @State private var showShareSheet: Bool = false
    @State private var shareURL: URL? = nil
    
    let reportTypes = ["Portfolio Summary", "Repayment Trend", "NPA Report"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: StaffSpacing.lg) {
            Text("Institutional Reports")
                .font(.staffTitle)
                .foregroundColor(.staffTextPrimary)
                .padding(.horizontal, StaffSpacing.lg)
                .padding(.top, StaffSpacing.lg)
            
            Divider()
                .background(Color.staffBorder)
            
            ScrollView {
                VStack(alignment: .leading, spacing: StaffSpacing.xl) {
                    // Parameters selection card
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Export Configurations")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            // Type Picker
                            Text("Report Type")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                            Picker("Report Type", selection: $selectedReportType) {
                                ForEach(reportTypes, id: \.self) { type in
                                    Text(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            // Date Range Picker
                            HStack {
                                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                                    .foregroundColor(.staffTextPrimary)
                                Spacer()
                                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                                    .foregroundColor(.staffTextPrimary)
                            }
                            .padding(.top, StaffSpacing.md)
                        }
                    }
                    
                    // Preview summary display
                    StaffCard {
                        VStack(alignment: .leading, spacing: StaffSpacing.md) {
                            Text("Compilation Summary Details")
                                .font(.staffTitle)
                                .foregroundColor(.staffTextPrimary)
                            
                            Divider()
                            
                            VStack(spacing: StaffSpacing.sm) {
                                KYCRow(label: "Target Scope", value: "HQ - Main Branch Consolidated")
                                KYCRow(label: "Filtered Span", value: "\(formatSpanDate(startDate)) to \(formatSpanDate(endDate))")
                                KYCRow(label: "Est. Record Count", value: "348 Accounts")
                            }
                        }
                    }
                    
                    // Export triggers
                    HStack(spacing: StaffSpacing.lg) {
                        StaffButton(
                            title: "Compile & Export CSV",
                            style: .primary,
                            icon: "tablecells",
                            isLoading: isGenerating
                        ) {
                            Task {
                                await compileAndExportReport(format: "CSV")
                            }
                        }
                        
                        StaffButton(
                            title: "Compile & Export PDF",
                            style: .primary,
                            icon: "doc.text.fill",
                            isLoading: isGenerating
                        ) {
                            Task {
                                await compileAndExportReport(format: "PDF")
                            }
                        }
                    }
                }
                .padding(StaffSpacing.lg)
            }
        }
        .background(Color.staffBackground)
        .sheet(isPresented: $showShareSheet, onDismiss: { shareURL = nil }) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    // MARK: - Actions
    
    private func compileAndExportReport(format: String) async {
        isGenerating = true
        
        // Simulate background report compile processing
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        do {
            let loans = try await LoanPortfolioService.shared.fetchLoans()
            let rawLoans = loans.map(\.loan)
            
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "\(selectedReportType.replacingOccurrences(of: " ", with: "_"))_\(Int(Date().timeIntervalSince1970))"
            
            if format == "CSV" {
                let csvString = ReportService.shared.generateCSVReport(loansList: rawLoans)
                let fileURL = tempDir.appendingPathComponent("\(filename).csv")
                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                self.shareURL = fileURL
            } else {
                // Generate a PDF placeholder using sanction letter mock layout styles
                let pdfData = SanctionLetterService.shared.generateSanctionLetterPDF(
                    borrowerName: "All Consolidated Portfolio Accounts",
                    applicationNo: "RPT-\(Int.random(in: 1000...9999))",
                    approvedAmount: rawLoans.reduce(0.0) { $0 + $1.principalAmount },
                    interestRate: 10.5,
                    tenureMonths: 24,
                    emiAmount: 12500,
                    branchName: "HQ - Consolidated Summary"
                )
                let fileURL = tempDir.appendingPathComponent("\(filename).pdf")
                try pdfData.write(to: fileURL)
                self.shareURL = fileURL
            }
            
            self.showShareSheet = true
        } catch {
            print("Error compiling report: \(error)")
        }
        
        isGenerating = false
    }
    
    private func formatSpanDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
