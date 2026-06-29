//
//  OfficerMessagesView.swift
//  LMS Staff
//
//  Centralised messaging center for Loan Officers to chat with borrowers.
//

import SwiftUI

struct OfficerMessagesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var dashboardVm = OfficerDashboardViewModel()
    @State private var selectedApp: ApplicationWithBorrower?
    
    var body: some View {
        HStack(spacing: 0) {
            // Left list: Chat Rooms / Applications
            VStack(alignment: .leading, spacing: 0) {
                Text("Chat Support Rooms")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                
                TextField("Search chats...", text: $dashboardVm.searchText)
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
                } else if dashboardVm.filteredApplications.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "bubble.left.and.bubble.right", title: "No Chats", message: "No active chat rooms found.")
                    Spacer()
                } else {
                    List(dashboardVm.filteredApplications, selection: $selectedApp) { app in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.borrower.fullName)
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                Text(app.product.name)
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.staffTextSecondary)
                        }
                        .padding(.vertical, 6)
                        .tag(app)
                        .listRowBackground(Color.staffSurface)
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
            
            // Right chat inspector
            if let app = selectedApp {
                ChatSupportConsole(appWithBorrower: app)
                    .id(app.application.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: StaffSpacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.staffTextSecondary.opacity(0.3))
                    Text("Select a Room to Message Client")
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
                if let staff = authViewModel.currentStaff {
                    await dashboardVm.loadApplications(forOfficerId: staff.userId)
                }
            }
        }
    }
}

// MARK: - Dedicated ChatSupportConsole Subview
struct ChatSupportConsole: View {
    let appWithBorrower: ApplicationWithBorrower
    @StateObject private var detailVm: ApplicationDetailViewModel
    @State private var messageText: String = ""
    
    init(appWithBorrower: ApplicationWithBorrower) {
        self.appWithBorrower = appWithBorrower
        _detailVm = StateObject(wrappedValue: ApplicationDetailViewModel(
            application: appWithBorrower.application,
            borrower: appWithBorrower.borrower,
            profile: appWithBorrower.profile,
            product: appWithBorrower.product
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Room Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appWithBorrower.borrower.fullName)
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    Text("Related Application: \(appWithBorrower.application.applicationNumber ?? "APP-NEW")")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            // Message List Scroller
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: StaffSpacing.md) {
                        ForEach(detailVm.borrowerMessages.filter { msg in
                            let isMe = msg.senderId == SupabaseManager.shared.currentUserId
                            return isMe ? !msg.isDeletedBySender : !msg.isDeletedByReceiver
                        }) { msg in
                            let isMe = msg.senderId == SupabaseManager.shared.currentUserId
                            HStack {
                                if isMe { Spacer() }
                                
                                VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                                    Text(msg.content)
                                        .font(.staffBody)
                                        .padding(12)
                                        .background(isMe ? Color.staffAccent : Color.staffSurface)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    
                                    HStack(spacing: 4) {
                                        Text(formatDate(msg.sentAt))
                                            .font(.system(size: 9))
                                            .foregroundColor(.staffTextSecondary)
                                        
                                        if isMe {
                                            Image(systemName: msg.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                                                .font(.system(size: 9))
                                                .foregroundColor(msg.isRead ? .staffAccent : .staffTextSecondary)
                                        }
                                    }
                                }
                                .id(msg.id)
                                .onAppear {
                                    if !isMe && !msg.isRead {
                                        Task {
                                            await detailVm.markMessageAsRead(msg.id)
                                        }
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task {
                                            await detailVm.deleteMessage(msg.id, isSender: isMe)
                                        }
                                    } label: {
                                        Label("Delete for me", systemImage: "trash")
                                    }
                                }
                                
                                if !isMe { Spacer() }
                            }
                        }
                    }
                    .padding(StaffSpacing.lg)
                }
                .onChange(of: detailVm.borrowerMessages) { messages in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // Text Input Footer
            HStack(spacing: StaffSpacing.md) {
                TextField("Type your message here...", text: $messageText)
                    .padding(14)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                    .foregroundColor(.staffTextPrimary)
                
                Button(action: {
                    Task {
                        await detailVm.sendChatMessage(messageText)
                        messageText = ""
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(14)
                        .background(Color.staffAccent)
                        .cornerRadius(StaffCorner.md)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
        }
        .task {
            await detailVm.loadAllDetails()
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: d)
    }
}
