//
//  PaymentActivityAttributes.swift
//  LMS  (Shared)
//
//  SHARED TYPE for the payment Live Activity. Lives in the non-synchronized
//  `Shared/` folder and is compiled into BOTH the LMS app target and the
//  LMSWidgetsExtension target (wired in project.pbxproj). ActivityKit requires
//  the attributes type to be the exact same type in both targets.
//

import ActivityKit
import Foundation

struct PaymentActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// "processing" | "confirmed" | "failed"
        var stage: String
        var message: String
    }

    /// What's being paid (shown in the Live Activity / Dynamic Island).
    var title: String
    var amount: Double
}
