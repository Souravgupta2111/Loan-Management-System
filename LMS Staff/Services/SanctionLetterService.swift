//
//  SanctionLetterService.swift
//  LMS Staff
//
//  Service for generating PDF sanction letters for approved loans.
//

import Foundation
import UIKit
import PDFKit

class SanctionLetterService {
    
    static let shared = SanctionLetterService()
    
    private init() {}
    
    /// Generates PDF sanction letter in-memory
    func generateSanctionLetterPDF(
        borrowerName: String,
        applicationNo: String,
        approvedAmount: Double,
        interestRate: Double,
        tenureMonths: Int,
        emiAmount: Double,
        branchName: String
    ) -> Data {
        let pdfMetaData = [
            kCGPDFContextSubject: "LMS Loan Sanction Letter",
            kCGPDFContextAuthor: "LMS Financial Services Ltd.",
            kCGPDFContextTitle: "Sanction Letter - \(applicationNo)"
        ] as [CFString : Any]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // A4 dimensions in points: 595 x 842
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { (context) in
            context.beginPage()
            
            var currentY: CGFloat = 50
            
            // 1. Draw Title Header
            let headerFont = UIFont.boldSystemFont(ofSize: 22)
            let titleString = "LOAN SANCTION LETTER"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.systemBlue
            ]
            titleString.draw(at: CGPoint(x: 50, y: currentY), withAttributes: titleAttributes)
            currentY += 40
            
            // Subtitle
            let subtitleFont = UIFont.systemFont(ofSize: 10)
            let subtitleString = "LMS Financial Services Ltd. | Branch: \(branchName)"
            subtitleString.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: subtitleFont, .foregroundColor: UIColor.darkGray])
            currentY += 15
            
            let dateString = "Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))"
            dateString.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: subtitleFont, .foregroundColor: UIColor.darkGray])
            currentY += 30
            
            // Divider line
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 50, y: currentY))
            path.addLine(to: CGPoint(x: 545, y: currentY))
            path.lineWidth = 1.5
            UIColor.lightGray.setStroke()
            path.stroke()
            currentY += 25
            
            // 2. Draw Subject / Opening
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let bodyBoldFont = UIFont.boldSystemFont(ofSize: 12)
            
            let openingString = "To,\n\(borrowerName)\nApplication Number: \(applicationNo)\n\nDear Client,\n\nWe are pleased to inform you that your application for a loan has been approved. The terms and conditions under which the loan has been sanctioned are detailed below:"
            
            let openingRect = CGRect(x: 50, y: currentY, width: 495, height: 120)
            openingString.draw(in: openingRect, withAttributes: [.font: bodyFont])
            currentY += 120
            
            // 3. Draw Loan Terms Table
            let terms = [
                ("Sanctioned Amount", "INR \(String(format: "%.2f", approvedAmount))"),
                ("Interest Rate", "\(String(format: "%.2f", interestRate))% Per Annum (Reducing)"),
                ("Tenure", "\(tenureMonths) Months"),
                ("Estimated Monthly EMI", "INR \(String(format: "%.2f", emiAmount))"),
                ("Repayment Mode", "ECS / Auto-Debit")
            ]
            
            let termLabelWidth: CGFloat = 200
            let termValueWidth: CGFloat = 295
            
            for (label, val) in terms {
                label.draw(at: CGPoint(x: 60, y: currentY), withAttributes: [.font: bodyBoldFont])
                val.draw(at: CGPoint(x: 60 + termLabelWidth, y: currentY), withAttributes: [.font: bodyFont])
                
                // Light underline for row
                let rowPath = UIBezierPath()
                rowPath.move(to: CGPoint(x: 50, y: currentY + 18))
                rowPath.addLine(to: CGPoint(x: 545, y: currentY + 18))
                rowPath.lineWidth = 0.5
                UIColor.lightGray.withAlphaComponent(0.5).setStroke()
                rowPath.stroke()
                
                currentY += 24
            }
            currentY += 20
            
            // 4. Closing Clauses
            let closingString = "Please review this document and return a signed copy as token of your acceptance to initiate disbursement. Final disbursement is subject to verification of original bank credentials and signing of the electronic ECS auto-debit mandate.\n\nYours Sincerely,\n\nLMS Risk & Credit Approval Committee"
            let closingRect = CGRect(x: 50, y: currentY, width: 495, height: 180)
            closingString.draw(in: closingRect, withAttributes: [.font: bodyFont])
        }
        
        return data
    }
}
