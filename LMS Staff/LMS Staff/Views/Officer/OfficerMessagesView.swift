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
                    await dashboardVm.loadApplications(forOfficerId: staff.id)
                }
            }
        }
    }
}

// MARK: - Dedicated ChatSupportConsole Subview
struct ChatSupportConsole: View {
    let appWithBorrower: ApplicationWithBorrower
    let forceInternalOnly: Bool
    @StateObject private var detailVm: ApplicationDetailViewModel
    @State private var messageText: String = ""
    @State private var isInternalChat: Bool
    @EnvironmentObject var authViewModel: AuthViewModel
    
    init(appWithBorrower: ApplicationWithBorrower, forceInternalOnly: Bool = false) {
        self.appWithBorrower = appWithBorrower
        self.forceInternalOnly = forceInternalOnly
        _isInternalChat = State(initialValue: forceInternalOnly)
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
                    Text(forceInternalOnly ? "Officer Review Discussion" : "Messaging Support")
                        .font(.staffTitle)
                        .foregroundColor(.staffTextPrimary)
                    Text(appWithBorrower.borrower.fullName)
                        .font(.staffCaption)
                        .foregroundColor(.staffTextSecondary)
                }
                
                Spacer()
                
                if !forceInternalOnly {
                    // Toggle between Borrower and Internal chat
                    Picker("Chat Type", selection: $isInternalChat) {
                        Text("Borrower Chat").tag(false)
                        Text("Internal Chat").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 280)
                } else {
                    Text("Internal Chat")
                        .font(.staffBody)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.staffAccent.opacity(0.15))
                        .foregroundColor(.staffAccent)
                        .cornerRadius(StaffCorner.md)
                }
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            // Message List Scroller
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: StaffSpacing.md) {
                        let activeMessages = isInternalChat ? detailVm.internalMessages : detailVm.borrowerMessages
                        
                        if activeMessages.isEmpty {
                            Text(isInternalChat ? "No internal messages. Send a message below to discuss with the branch manager." : "No messages yet. Send a message below to start a thread with this borrower.")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                                .padding(.top, 40)
                        } else {
                            ForEach(activeMessages.filter { msg in
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
                                            .background(isMe ? Color.staffAccent : (isInternalChat ? Color.staffAmber.opacity(0.2) : Color.staffSurface))
                                            .foregroundColor(isMe ? .white : .staffTextPrimary)
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
                    }
                    .padding(StaffSpacing.lg)
                }
                .onChange(of: isInternalChat ? detailVm.internalMessages : detailVm.borrowerMessages) { messages in
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
            if authViewModel.currentUser?.role != .admin {
                HStack(spacing: StaffSpacing.md) {
                    TextField(isInternalChat ? "Type internal message..." : "Type a message to client...", text: $messageText)
                        .textInputAutocapitalization(.sentences)
                        .padding(14)
                        .background(Color.staffSurface)
                        .cornerRadius(StaffCorner.md)
                        .foregroundColor(.staffTextPrimary)
                    
                    Button(action: {
                        Task {
                            let success = await detailVm.sendChatMessage(messageText, isInternal: isInternalChat)
                            if success {
                                messageText = ""
                            }
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
