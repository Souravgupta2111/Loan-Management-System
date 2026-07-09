//
//  LMSWidgetsBundle.swift
//  LMSWidgets
//

import WidgetKit
import SwiftUI

@main
struct LMSWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LoanSummaryWidget()
        ApplicationTrackerWidget()
        AIQuickAskWidget()
        CreditScoreWidget()
        EMILockWidget()
        PaymentLiveActivityWidget()
    }
}
