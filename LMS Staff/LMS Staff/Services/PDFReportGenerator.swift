//
//  PDFReportGenerator.swift
//  LMS Staff
//
//  Generates rich PDF reports embedding rendered SwiftUI charts and descriptions.
//

import SwiftUI
import PDFKit

@MainActor
class PDFReportGenerator {
    
    static let shared = PDFReportGenerator()
    
    private init() {}
    
    /// Generates a complete PDF report incorporating the selected charts.
    func generateReportPDF(
        reportType: String,
        dashboardVM: ManagerDashboardViewModel,
        productVolumeBreakdown: [(product: String, amount: Double)],
        selectedPeriod: String,
        startDate: Date,
        endDate: Date,
        branchName: String = "HQ - Consolidated Summary"
    ) -> Data {
        let pdfMetaData = [
            kCGPDFContextSubject: "LMS Branch Report",
            kCGPDFContextAuthor: "LMS Financial Services Ltd.",
            kCGPDFContextTitle: "Branch Report - \(reportType)"
        ] as [CFString : Any]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // A4 dimensions in points: 595.2 x 841.8
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            var currentY: CGFloat = 50
            let margin: CGFloat = 50
            let contentWidth = pageRect.width - (margin * 2)
            
            // Header
            let titleFont = UIFont.boldSystemFont(ofSize: 22)
            let titleString = "BRANCH PERFORMANCE REPORT"
            titleString.draw(at: CGPoint(x: margin, y: currentY), withAttributes: [.font: titleFont, .foregroundColor: UIColor.systemBlue])
            currentY += 35
            
            let subtitleFont = UIFont.systemFont(ofSize: 12)
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            
            let details = """
            Branch: \(branchName)
            Report Type: \(reportType)
            Date Range: \(formatter.string(from: startDate)) to \(formatter.string(from: endDate))
            Generated On: \(formatter.string(from: Date()))
            """
            
            details.draw(in: CGRect(x: margin, y: currentY, width: contentWidth, height: 60),
                         withAttributes: [.font: subtitleFont, .foregroundColor: UIColor.darkGray])
            currentY += 70
            
            // Divider
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: currentY))
            path.addLine(to: CGPoint(x: pageRect.width - margin, y: currentY))
            path.lineWidth = 1.0
            UIColor.lightGray.setStroke()
            path.stroke()
            currentY += 30
            
            // Render specific charts based on report type
            if reportType == "Portfolio Summary" {
                currentY = drawChartWithDescription(
                    title: "Portfolio Status Mix & Product Volume",
                    description: "This section illustrates the distribution of loans across various states (e.g., Active, NPA, Closed) and the volume of loans disbursed per loan product category.",
                    view: AnyView(
                        PortfolioSummaryCharts(dashboardVM: dashboardVM, productVolumeBreakdown: productVolumeBreakdown)
                            .frame(width: 500)
                            .padding()
                            .background(Color.white)
                    ),
                    currentY: currentY,
                    pageRect: pageRect,
                    context: context
                )
            } else if reportType == "Disbursement Trend" {
                currentY = drawChartWithDescription(
                    title: "Disbursement Trend (\(selectedPeriod.capitalized))",
                    description: "This chart shows the historical disbursement volume grouped by the selected time period, indicating overall growth and seasonal spikes in loan origination.",
                    view: AnyView(
                        DisbursementTrendChart(dashboardVM: dashboardVM, selectedPeriod: .constant(selectedPeriod))
                            .frame(width: 500)
                            .padding()
                            .background(Color.white)
                    ),
                    currentY: currentY,
                    pageRect: pageRect,
                    context: context
                )
            } else if reportType == "Repayment Trend" {
                currentY = drawChartWithDescription(
                    title: "Collection Efficiency Trend",
                    description: "This graph plots the monthly collection efficiency percentage, tracking the branch's performance in recovering scheduled EMI payments on time.",
                    view: AnyView(
                        RepaymentTrendChart(dashboardVM: dashboardVM)
                            .frame(width: 500)
                            .padding()
                            .background(Color.white)
                    ),
                    currentY: currentY,
                    pageRect: pageRect,
                    context: context
                )
            } else if reportType == "NPA Report" {
                currentY = drawChartWithDescription(
                    title: "NPA Aging Buckets",
                    description: "This chart breaks down the Non-Performing Assets (NPA) into aging buckets (30-60 days, 60-90 days, etc.), highlighting the severity of overdue accounts.",
                    view: AnyView(
                        NPAReportChart(dashboardVM: dashboardVM)
                            .frame(width: 500)
                            .padding()
                            .background(Color.white)
                    ),
                    currentY: currentY,
                    pageRect: pageRect,
                    context: context
                )
            }
            
            // Footer
            let footerFont = UIFont.systemFont(ofSize: 10)
            let footerText = "Confidential - LMS Financial Services Ltd."
            footerText.draw(at: CGPoint(x: margin, y: pageRect.height - 40),
                            withAttributes: [.font: footerFont, .foregroundColor: UIColor.lightGray])
        }
        
        return data
    }
    
    private func drawChartWithDescription(
        title: String,
        description: String,
        view: AnyView,
        currentY: CGFloat,
        pageRect: CGRect,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var y = currentY
        let margin: CGFloat = 50
        let contentWidth = pageRect.width - (margin * 2)
        
        // Ensure space for title and description
        if y > pageRect.height - 100 {
            context.beginPage()
            y = 50
        }
        
        // Title
        let titleFont = UIFont.boldSystemFont(ofSize: 16)
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: titleFont])
        y += 25
        
        // Description
        let descFont = UIFont.systemFont(ofSize: 12)
        let textRect = CGRect(x: margin, y: y, width: contentWidth, height: 60)
        description.draw(in: textRect, withAttributes: [.font: descFont, .foregroundColor: UIColor.darkGray])
        y += 60 // Approximate height for 2-3 lines
        
        // Render SwiftUI view to image
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0 // High res
        if let image = renderer.uiImage {
            // Calculate aspect ratio fit
            let imageRatio = image.size.width / image.size.height
            let targetWidth = contentWidth
            let targetHeight = targetWidth / imageRatio
            
            // Check if we need a new page for the image
            if y + targetHeight > pageRect.height - 50 {
                context.beginPage()
                y = 50
            }
            
            image.draw(in: CGRect(x: margin, y: y, width: targetWidth, height: targetHeight))
            y += targetHeight + 30
        }
        
        return y
    }
}
