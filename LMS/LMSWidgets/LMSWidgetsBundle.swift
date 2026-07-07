//
//  LMSWidgetsBundle.swift
//  LMSWidgets
//

import WidgetKit
import SwiftUI

@main
struct LMSWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextEMIWidget()
        LoanSummaryWidget()
        EMICalendarWidget()
        ApplicationTrackerWidget()
        AIQuickAskWidget()
        CreditScoreWidget()
        LoanCalculatorWidget()
        EMILockWidget()
        PaymentLiveActivityWidget()
    }
}
