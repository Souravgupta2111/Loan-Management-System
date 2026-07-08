//
//  ManagerMessagesView.swift
//  LMS Staff
//
//  Centralised messaging console for Managers to chat with Loan Officers about loan files.
//

import SwiftUI

struct ManagerMessagesView: View {
    @StateObject private var dashboardVm = ManagerDashboardViewModel()
    @State private var selectedApp: ApplicationWithBorrower?
    @State private var searchText: String = ""
    
    private var filteredChats: [ApplicationWithBorrower] {
        dashboardVm.chatApplications.filter { app in
            if searchText.isEmpty { return true }
            let query = searchText.lowercased()
            return app.borrower.fullName.lowercased().contains(query) ||
                   (app.application.applicationNumber ?? "").lowercased().contains(query) ||
                   app.product.name.lowercased().contains(query)
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left list of recommended rooms
            VStack(alignment: .leading, spacing: 0) {
                Text("Officer Chat Rooms")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                
                TextField("Search chats...", text: $searchText)
                    .padding(12)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                    .foregroundColor(.staffTextPrimary)
                    .padding(StaffSpacing.lg)
                
                Divider()
                    .background(Color.staffBorder)
                
                if dashboardVm.isLoading {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if filteredChats.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "bubble.left.and.bubble.right", title: "No Chats", message: "No active chat rooms found.")
                    Spacer()
                } else {
                    List(filteredChats, selection: $selectedApp) { app in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.borrower.fullName)
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                HStack(spacing: 4) {
                                    Text(app.application.applicationNumber ?? "APP-NEW")
                                        .fontWeight(.semibold)
                                    Text("•")
                                    Text(app.product.name)
                                }
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        .padding(.vertical, 4)
                        .tag(app)
                        .listRowBackground(
                            selectedApp?.application.id == app.application.id
                            ? Color.staffAccent.opacity(0.15)
                            : Color.staffSurface
                        )
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Color.staffBackground)
                }
            }
            .frame(width: 320)
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // Right chat window
            if let app = selectedApp {
                ChatSupportConsole(appWithBorrower: app, forceInternalOnly: true)
                    .id(app.application.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select an Officer Chat Room to Open Conversation")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.staffSurface.opacity(0.1))
            }
        }
        .background(Color.staffBackground)
        .onAppear {
            Task {
                await dashboardVm.loadDashboard()
            }
        }
    }
}
