import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import UserNotifications

// MARK: - 批量通知操作视图
struct BatchNotificationOperationsView: View {
    @StateObject private var notificationService = EnhancedNotificationService.shared
    @State private var selectedNotifications = Set<String>()
    @State private var isSelectionMode = false
    @State private var showingDeleteAlert = false
    @State private var showingMarkReadAlert = false
    @State private var selectedCategory = "all"
    
    var filteredNotifications: [NotificationRecord] {
        var notifications = notificationService.notificationHistory
        
        if selectedCategory != "all" {
            notifications = notifications.filter { $0.categoryId == selectedCategory }
        }
        
        return notifications.sorted { ($0.sentDate ?? Date.distantPast) > ($1.sentDate ?? Date.distantPast) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 操作工具栏
            if isSelectionMode {
                BatchOperationToolbar(
                    selectedCount: selectedNotifications.count,
                    totalCount: filteredNotifications.count,
                    onSelectAll: selectAllNotifications,
                    onDeselectAll: deselectAllNotifications,
                    onMarkAsRead: {
                        showingMarkReadAlert = true
                    },
                    onDelete: {
                        showingDeleteAlert = true
                    }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                
                Divider()
            }
            
            // 分类筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    LocalFilterChip(
                        title: "全部",
                        isSelected: selectedCategory == "all",
                        count: 0
                    ) {
                        selectedCategory = "all"
                    }
                    
                    ForEach(notificationService.notificationCategories, id: \.id) { category in
                        LocalFilterChip(
                            title: category.name,
                            isSelected: selectedCategory == category.id,
                            count: 0
                        ) {
                            selectedCategory = category.id
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
            .background(
                #if os(iOS)
                Color(UIColor.systemBackground)
                #elseif os(macOS)
                Color(NSColor.windowBackgroundColor)
                #endif
            )
            
            Divider()
            
            // 通知列表
            if filteredNotifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("暂无通知记录")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    #if os(iOS)
                    Color(UIColor.systemGroupedBackground)
                    #elseif os(macOS)
                    Color(NSColor.windowBackgroundColor)
                    #endif
                )
            } else {
                List {
                    ForEach(filteredNotifications) { notification in
                        BatchNotificationRow(
                            notification: notification,
                            isSelected: selectedNotifications.contains(notification.id),
                            isSelectionMode: isSelectionMode,
                            onToggleSelection: {
                                toggleNotificationSelection(notification.id)
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("批量操作")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                Button(isSelectionMode ? "完成" : "选择") {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedNotifications.removeAll()
                    }
                }
            }
            #elseif os(macOS)
            SwiftUI.ToolbarItem(placement: .automatic) {
                Button(isSelectionMode ? "完成" : "选择") {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedNotifications.removeAll()
                    }
                }
            }
            #endif
        }
        .alert("标记为已读", isPresented: $showingMarkReadAlert) {
            Button("取消", role: .cancel) { }
            Button("确认") {
                markSelectedAsRead()
            }
        } message: {
            Text("将选中的 \(selectedNotifications.count) 条通知标记为已读？")
        }
        .alert("删除通知", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteSelectedNotifications()
            }
        } message: {
            Text("确定要删除选中的 \(selectedNotifications.count) 条通知吗？此操作无法撤销。")
        }
        .task {
            await notificationService.loadNotificationHistoryAsync()
        }
    }
    
    // MARK: - 私有方法
    
    private func toggleNotificationSelection(_ id: String) {
        if selectedNotifications.contains(id) {
            selectedNotifications.remove(id)
        } else {
            selectedNotifications.insert(id)
        }
    }
    
    private func selectAllNotifications() {
        selectedNotifications = Set(filteredNotifications.map { $0.id })
    }
    
    private func deselectAllNotifications() {
        selectedNotifications.removeAll()
    }
    
    private func markSelectedAsRead() {
        Task {
            notificationService.markNotificationsAsRead(Array(selectedNotifications))
            selectedNotifications.removeAll()
        }
    }
    
    private func deleteSelectedNotifications() {
        let notificationsToDelete = filteredNotifications.filter { 
            selectedNotifications.contains($0.id) 
        }
        
        Task {
            await notificationService.deleteNotifications(notificationsToDelete)
            selectedNotifications.removeAll()
        }
    }
}

// MARK: - 批量操作工具栏
struct BatchOperationToolbar: View {
    let selectedCount: Int
    let totalCount: Int
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onMarkAsRead: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text("已选择 \(selectedCount) 项")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(selectedCount == totalCount ? "取消全选" : "全选") {
                    if selectedCount == totalCount {
                        onDeselectAll()
                    } else {
                        onSelectAll()
                    }
                }
                .font(.caption)
                .disabled(totalCount == 0)
                
                Button("标记已读") {
                    onMarkAsRead()
                }
                .font(.caption)
                .disabled(selectedCount == 0)
                
                Button("删除") {
                    onDelete()
                }
                .font(.caption)
                .foregroundColor(.red)
                .disabled(selectedCount == 0)
            }
        }
    }
}

// MARK: - 批量通知行组件
struct BatchNotificationRow: View {
    let notification: NotificationRecord
    let isSelected: Bool
    let isSelectionMode: Bool
    let onToggleSelection: () -> Void
    
    var body: some View {
        HStack {
            if isSelectionMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            NotificationHistoryRow(notification: notification)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection()
            }
        }
    }
}

// MARK: - 本地筛选芯片组件
private struct LocalFilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor : Color.gray.opacity(0.1)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        BatchNotificationOperationsView()
    }
}
