//
//  AdminDashboardViewModel.swift
//  LMS Staff
//
//  ViewModel for System Administrators, offering full platform metrics.
//

import Foundation
import Combine
import Supabase

@MainActor
class AdminDashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var totalApplicationsCount: Int = 0
    @Published var pendingReviewsCount: Int = 0
    @Published var approvedCount: Int = 0
    @Published var rejectedCount: Int = 0
    @Published var disbursedCount: Int = 0
    
    @Published var allApplicationsList: [ApplicationWithBorrower] = []
    @Published var pendingReviewsList: [ApplicationWithBorrower] = []
    @Published var approvedList: [ApplicationWithBorrower] = []
    @Published var rejectedList: [ApplicationWithBorrower] = []
    @Published var disbursedList: [ApplicationWithBorrower] = []
    
    @Published var systemNpaRatio: Double = 0.0
    
    @Published var recentActivities: [AuditLog] = []
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let appService = ApplicationService.shared
    private let reportService = ReportService.shared
    private let auditService = AuditService.shared
    private let supabase = SupabaseManager.shared
    
    private var realtimeChannel: RealtimeChannelV2?
    
    init() {}
    
    /// Loads aggregate system statistics and recent audit trails
    func loadDashboard() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Fetch system metrics
            let allApps = try await appService.fetchAllApplications()
            
            self.allApplicationsList = allApps
            self.pendingReviewsList = allApps.filter { $0.application.status == .underReview || $0.application.status == .submitted }
            self.approvedList = allApps.filter { $0.application.status == .approved }
            self.rejectedList = allApps.filter { $0.application.status == .rejected }
            self.disbursedList = allApps.filter { $0.application.status == .disbursed }
            
            self.totalApplicationsCount = self.allApplicationsList.count
            self.pendingReviewsCount = self.pendingReviewsList.count
            self.approvedCount = self.approvedList.count
            self.rejectedCount = self.rejectedList.count
            self.disbursedCount = self.disbursedList.count
            
            // System-wide reports
            let report = try await reportService.compileConsolidatedReport()
            self.systemNpaRatio = report.npaRatio
            
            // 2. Load recent audit activity log
            self.recentActivities = try await auditService.fetchAuditLogs(limit: 10)
            
            // 3. Setup real-time updates
            subscribeToApplicationUpdates()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func subscribeToApplicationUpdates() {
        if realtimeChannel != nil { return }
        
        let channel = supabase.client.realtimeV2.channel("public:loan_applications")
        self.realtimeChannel = channel
        
        Task {
            let changes = await channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "loan_applications"
            )
            
            await channel.subscribe()
            
            for await _ in changes {
                print("Realtime update received, refreshing dashboard...")
                await self.loadDashboard()
            }
        }
    }
    
    deinit {
        if let channel = realtimeChannel {
            Task {
                await supabase.client.realtimeV2.removeChannel(channel)
            }
        }
    }
}
