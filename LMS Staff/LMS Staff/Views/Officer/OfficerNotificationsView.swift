//
//  OfficerNotificationsView.swift
//  LMS Staff
//
//  Notifications alert inbox view for staff portals.
//

import SwiftUI

struct OfficerNotificationsView: View {
    @State private var notifications: [LMSNotification] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Alert Notifications")
                    .font(.staffTitle)
                    .foregroundColor(.staffTextPrimary)
                Spacer()
                Button("Refresh") {
                    Task {
                        await loadNotifications()
                    }
                }
                .font(.staffBody)
                .foregroundColor(.staffAccent)
            }
            .padding(StaffSpacing.lg)
            .background(Color.staffSurface)
            
            Divider()
                .background(Color.staffBorder)
            
            // Notifications List
            if isLoading {
                Spacer()
                ProgressView("Fetching alert inbox...")
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if notifications.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "bell.slash",
                    title: "All Caught Up",
                    message: "You have no unread notifications or system alerts at this time."
                )
                Spacer()
            } else {
                List(notifications) { item in
                    HStack(spacing: StaffSpacing.md) {
                        // Unread Indicator
                        Circle()
                            .fill(item.isRead ? Color.clear : Color.staffAccent)
                            .frame(width: 8, height: 8)
                        
                        Image(systemName: item.type.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .foregroundColor(item.isRead ? .staffTextSecondary : .staffAccent)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.staffBody)
                                .fontWeight(item.isRead ? .regular : .bold)
                                .foregroundColor(.staffTextPrimary)
                            
                            if let body = item.body {
                                Text(body)
                                    .font(.staffCaption)
                                    .foregroundColor(.staffTextSecondary)
                                    .lineLimit(2)
                            }
                            
                            Text(formatRelativeDate(item.sentAt))
                                .font(.caption)
                                .foregroundColor(.staffTextSecondary.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        if !item.isRead {
                            Button(action: {
                                Task {
                                    try? await NotificationService.shared.markAsRead(notificationId: item.id)
                                    await loadNotifications()
                                }
                            }) {
                                Text("Mark Read")
                                    .font(.staffCaption)
                                    .foregroundColor(.staffAccent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: StaffCorner.sm)
                                            .stroke(Color.staffAccent, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.staffSurface)
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .background(Color.staffBackground)
            }
        }
        .background(Color.staffBackground)
        .task {
            await loadNotifications()
        }
    }
    
    private func loadNotifications() async {
        isLoading = true
        errorMessage = nil
        do {
            self.notifications = try await NotificationService.shared.fetchNotifications()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func formatRelativeDate(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: d, relativeTo: Date())
    }
}
