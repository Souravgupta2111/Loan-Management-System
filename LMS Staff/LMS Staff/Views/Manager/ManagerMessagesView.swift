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
    
    var body: some View {
        HStack(spacing: 0) {
            // Left list of recommended rooms
            VStack(alignment: .leading, spacing: 0) {
                Text("Officer Chat Rooms")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                    .padding(.horizontal, StaffSpacing.lg)
                    .padding(.top, StaffSpacing.lg)
                
                Divider()
                    .background(Color.staffBorder)
                    .padding(.vertical, StaffSpacing.md)
                
                if dashboardVm.isLoading {
                    Spacer()
                    ProgressView()
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if dashboardVm.recommendedApplications.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "bubble.left.and.bubble.right", title: "No Chats", message: "No recommended applications active for discussion.")
                    Spacer()
                } else {
                    List(dashboardVm.recommendedApplications, selection: $selectedApp) { app in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.borrower.fullName)
                                    .font(.staffBody)
                                    .fontWeight(.bold)
                                    .foregroundColor(.staffTextPrimary)
                                Text("No: \(app.application.applicationNumber ?? "")")
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
            
            // Right chat window
            if let app = selectedApp {
                ManagerOfficerChatConsole(appWithBorrower: app)
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

// MARK: - Subview Chat Console
struct ManagerOfficerChatConsole: View {
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
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review Discussion - \(appWithBorrower.borrower.fullName)")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    Text("Assigned Officer ID: \(appWithBorrower.application.assignedOfficerId?.uuidString.prefix(8) ?? "N/A")")
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                Spacer()
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            // Scroller
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: StaffSpacing.md) {
                        ForEach(detailVm.internalMessages.filter { msg in
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
                                        
                                    // Timestamp & Read Status
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
                .onChange(of: detailVm.internalMessages) { messages in
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
            
            // Footer textfield
            HStack(spacing: StaffSpacing.md) {
                TextField("Message to Loan Officer...", text: $messageText)
                    .padding(14)
                    .background(Color.staffSurface)
                    .cornerRadius(StaffCorner.md)
                    .foregroundColor(.staffTextPrimary)
                
                Button(action: {
                    Task {
                        // Send message to the officer
                        let officerId = appWithBorrower.application.assignedOfficerId ?? appWithBorrower.borrower.id
                        _ = try? await MessageService.shared.sendMessage(
                            applicationId: appWithBorrower.application.id,
                            receiverId: officerId,
                            content: messageText
                        )
                        messageText = ""
                        await detailVm.loadAllDetails()
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
