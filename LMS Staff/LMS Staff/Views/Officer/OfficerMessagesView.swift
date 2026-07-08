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
                    dashboardVm.selectedStatusFilter = "All"
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
            .background(Color.white.opacity(0.1))
            
            // Message List Scroller
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: StaffSpacing.md) {
                        let activeMessages = isInternalChat ? detailVm.internalMessages : detailVm.borrowerMessages
                        
                        if activeMessages.isEmpty {
                            Text(isInternalChat ? "No internal messages. Send a message below to discuss with the branch manager." : "No messages yet. Send a message below to start a thread with this borrower.")
                                .font(.staffCaption)
                                .foregroundColor(.staffTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, StaffSpacing.lg)
                                .padding(.top, 40)
                        } else {
                            ForEach(activeMessages.filter { msg in
                                // If Admin, show all messages. Otherwise, filter out deleted ones for the user.
                                if authViewModel.currentUser?.role == .admin {
                                    return true
                                }
                                let isMe = msg.senderId == SupabaseManager.shared.currentUserId
                                return isMe ? !msg.isDeletedBySender : !msg.isDeletedByReceiver
                            }) { msg in
                                let isMe = msg.senderId == SupabaseManager.shared.currentUserId
                                let isStaffSender = msg.senderId != appWithBorrower.borrower.id
                                
                                let styling = getMessageStyling(for: msg, isInternalChat: isInternalChat, isMe: isMe, isStaffSender: isStaffSender)
                                
                                HStack {
                                    if styling.isRightAligned { Spacer() }
                                    
                                    VStack(alignment: styling.isRightAligned ? .trailing : .leading, spacing: 4) {
                                        Text(getSenderRoleName(isInternalChat: isInternalChat, isMe: isMe, isStaffSender: isStaffSender, isManagerInInternalChat: styling.isManagerInInternalChat))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.staffTextSecondary)
                                            .padding(.horizontal, 4)
                                        
                                        Text(msg.content)
                                            .font(.staffBody)
                                            .padding(12)
                                            .background(styling.bgColor)
                                            .foregroundColor(styling.fgColor)
                                            .cornerRadius(12)
                                        
                                        HStack(spacing: 4) {
                                            Text(formatDate(msg.sentAt))
                                                .font(.caption)
                                                .foregroundColor(.staffTextSecondary)
                                            
                                            if isMe {
                                                Image(systemName: msg.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                                                    .font(.caption)
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
                                        if isMe {
                                            Button(role: .destructive) {
                                                Task {
                                                    await detailVm.deleteMessage(msg.id, isSender: isMe)
                                                }
                                            } label: {
                                                Label("Delete for me", systemImage: "trash")
                                            }
                                        }
                                    }
                                    
                                    if !styling.isRightAligned { Spacer() }
                                }
                            }
                        }
                    }
                    .padding(StaffSpacing.lg)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: isInternalChat ? detailVm.internalMessages : detailVm.borrowerMessages) { messages in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color.staffBackground)
            
            Divider()
                .background(Color.staffBorder)
            
            // Text Input Footer
            if authViewModel.currentUser?.role == .manager && appWithBorrower.application.status == .rejected {
                Text("Application is rejected. Chat is disabled.")
                    .font(.staffBody)
                    .foregroundColor(.staffTextSecondary)
                    .padding(StaffSpacing.lg)
                    .frame(maxWidth: .infinity)
                    .background(Color.staffSurface)
            } else if authViewModel.currentUser?.role != .admin {
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
    
    private func getMessageStyling(for msg: Message, isInternalChat: Bool, isMe: Bool, isStaffSender: Bool) -> (isRightAligned: Bool, isManagerInInternalChat: Bool, bgColor: Color, fgColor: Color) {
        let isManagerInInternalChat: Bool
        if authViewModel.currentUser?.role == .admin {
            let senderRole = detailVm.internalChatParticipantRoles[msg.senderId]
            isManagerInInternalChat = senderRole == .manager || senderRole == .admin
        } else {
            isManagerInInternalChat = authViewModel.currentUser?.role == .manager ? isMe : !isMe
        }
        
        let isRightAligned: Bool
        if isInternalChat {
            if authViewModel.currentUser?.role == .admin {
                isRightAligned = !isManagerInInternalChat
            } else {
                isRightAligned = isMe
            }
        } else {
            isRightAligned = isStaffSender
        }
        
        let bgColor: Color
        if authViewModel.currentUser?.role == .admin {
            bgColor = .white
        } else if isRightAligned {
            bgColor = .staffAccent
        } else if isInternalChat {
            bgColor = .staffAmber.opacity(0.2)
        } else {
            bgColor = .staffSurface
        }
        
        let fgColor: Color
        if authViewModel.currentUser?.role == .admin {
            fgColor = .staffTextPrimary
        } else if isRightAligned {
            fgColor = .white
        } else {
            fgColor = .staffTextPrimary
        }
        
        return (isRightAligned, isManagerInInternalChat, bgColor, fgColor)
    }
    
    private func getSenderRoleName(isInternalChat: Bool, isMe: Bool, isStaffSender: Bool, isManagerInInternalChat: Bool) -> String {
        if isInternalChat {
            return isManagerInInternalChat ? "Manager" : "Loan Officer"
        } else {
            if isMe {
                return authViewModel.currentUser?.role.displayName ?? "Loan Officer"
            } else if isStaffSender {
                return "Loan Officer"
            } else {
                return "Borrower"
            }
        }
    }
}
