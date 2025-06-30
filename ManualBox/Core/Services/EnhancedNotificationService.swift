//
//  EnhancedNotificationService.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import Foundation
import UserNotifications
import CoreData
import Combine

// MARK: - 增强通知服务
@MainActor
class EnhancedNotificationService: ObservableObject {
    static let shared = EnhancedNotificationService()
    
    @Published var notificationHistory: [NotificationRecord] = []
    @Published var pendingNotifications: [PendingNotification] = []
    @Published var notificationCategories: [NotificationCategory] = []
    @Published var isLoading = false
    
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.context = PersistenceController.shared.container.viewContext
        loadNotificationCategories()
        setupNotificationCategories()
        loadNotificationHistory()
        setupNotificationDelegate()
    }
    
    // MARK: - 通知分类设置
    
    private func setupNotificationCategories() {
        notificationCategories = [
            NotificationCategory(
                id: "warranty",
                name: "保修提醒",
                description: "产品保修期到期提醒",
                icon: "shield.checkered",
                color: "orange",
                isEnabled: true,
                priority: .high
            ),
            NotificationCategory(
                id: "maintenance",
                name: "维护保养",
                description: "产品维护保养提醒",
                icon: "wrench.and.screwdriver",
                color: "blue",
                isEnabled: true,
                priority: .medium
            ),
            NotificationCategory(
                id: "ocr",
                name: "OCR处理",
                description: "说明书OCR处理完成通知",
                icon: "doc.text.viewfinder",
                color: "green",
                isEnabled: true,
                priority: .low
            ),
            NotificationCategory(
                id: "sync",
                name: "数据同步",
                description: "数据同步状态通知",
                icon: "arrow.triangle.2.circlepath",
                color: "purple",
                isEnabled: false,
                priority: .low
            ),
            NotificationCategory(
                id: "backup",
                name: "数据备份",
                description: "数据备份提醒",
                icon: "externaldrive.badge.checkmark",
                color: "indigo",
                isEnabled: true,
                priority: .medium
            )
        ]
        
        // 注册通知分类到系统
        registerNotificationCategories()
    }
    
    private func registerNotificationCategories() {
        var categories: Set<UNNotificationCategory> = []
        
        for category in notificationCategories {
            let actions = createActionsForCategory(category)
            let unCategory = UNNotificationCategory(
                identifier: category.id,
                actions: actions,
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
            categories.insert(unCategory)
        }
        
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
    
    private func createActionsForCategory(_ category: NotificationCategory) -> [UNNotificationAction] {
        switch category.id {
        case "warranty":
            return [
                UNNotificationAction(
                    identifier: "view_product",
                    title: "查看产品",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "extend_warranty",
                    title: "延长保修",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "dismiss",
                    title: "忽略",
                    options: []
                )
            ]
        case "maintenance":
            return [
                UNNotificationAction(
                    identifier: "schedule_maintenance",
                    title: "安排维护",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "mark_completed",
                    title: "标记完成",
                    options: []
                )
            ]
        default:
            return [
                UNNotificationAction(
                    identifier: "view_details",
                    title: "查看详情",
                    options: [.foreground]
                )
            ]
        }
    }
    
    // MARK: - 通知发送
    
    /// 发送增强通知
    func sendNotification(
        _ notification: EnhancedNotification,
        scheduledDate: Date? = nil
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = notification.sound
        content.categoryIdentifier = notification.categoryId
        content.userInfo = notification.userInfo
        
        // 添加附件
        if let attachments = notification.attachments {
            content.attachments = attachments
        }
        
        // 创建触发器
        let trigger: UNNotificationTrigger?
        if let scheduledDate = scheduledDate {
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: scheduledDate
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            trigger = nil // 立即发送
        }
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: trigger
        )
        
        // 添加到系统
        try await UNUserNotificationCenter.current().add(request)
        
        // 记录到历史
        let record = NotificationRecord(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            categoryId: notification.categoryId,
            scheduledDate: scheduledDate ?? Date(),
            sentDate: scheduledDate == nil ? Date() : nil,
            status: scheduledDate == nil ? .sent : .scheduled,
            userInfo: notification.userInfo as? [String: String] ?? [:]
        )
        
        notificationHistory.insert(record, at: 0)
        saveNotificationHistory()
    }
    
    /// 批量发送通知
    func sendBatchNotifications(_ notifications: [EnhancedNotification]) async {
        for notification in notifications {
            do {
                try await sendNotification(notification)
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒延迟
            } catch {
                print("发送通知失败: \(error)")
            }
        }
    }
    
    // MARK: - 通知管理
    
    /// 取消通知
    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        
        // 更新历史记录状态
        if let index = notificationHistory.firstIndex(where: { $0.id == id }) {
            notificationHistory[index].status = .cancelled
            saveNotificationHistory()
        }
    }
    
    /// 批量取消通知
    func cancelNotifications(ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        
        // 更新历史记录状态
        for id in ids {
            if let index = notificationHistory.firstIndex(where: { $0.id == id }) {
                notificationHistory[index].status = .cancelled
            }
        }
        saveNotificationHistory()
    }
    
    /// 取消分类下的所有通知
    func cancelNotifications(in categoryId: String) {
        let idsToCancel = notificationHistory
            .filter { $0.categoryId == categoryId && $0.status == .scheduled }
            .map { $0.id }
        
        cancelNotifications(ids: idsToCancel)
    }
    
    /// 清理历史记录
    func clearHistory(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        notificationHistory.removeAll { record in
            guard let sentDate = record.sentDate else { return false }
            return sentDate < cutoffDate
        }
        saveNotificationHistory()
    }
    
    // MARK: - 通知历史管理
    
    private func loadNotificationHistory() {
        if let data = UserDefaults.standard.data(forKey: "NotificationHistory"),
           let history = try? JSONDecoder().decode([NotificationRecord].self, from: data) {
            notificationHistory = history
        }
    }
    
    private func saveNotificationHistory() {
        if let data = try? JSONEncoder().encode(notificationHistory) {
            UserDefaults.standard.set(data, forKey: "NotificationHistory")
        }
    }
    
    /// 获取待发送通知
    func loadPendingNotifications() async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        
        await MainActor.run {
            self.pendingNotifications = requests.map { request in
                PendingNotification(
                    id: request.identifier,
                    title: request.content.title,
                    body: request.content.body,
                    categoryId: request.content.categoryIdentifier,
                    scheduledDate: extractScheduledDate(from: request.trigger),
                    userInfo: request.content.userInfo
                )
            }.sorted { $0.scheduledDate < $1.scheduledDate }
        }
    }
    
    private func extractScheduledDate(from trigger: UNNotificationTrigger?) -> Date {
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            return Calendar.current.date(from: calendarTrigger.dateComponents) ?? Date()
        }
        return Date()
    }
    
    // MARK: - 通知委托设置
    
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    // MARK: - 统计信息

    func getNotificationStatistics() -> NotificationStatistics {
        let total = notificationHistory.count
        let sent = notificationHistory.filter { $0.status == .sent }.count
        let scheduled = notificationHistory.filter { $0.status == .scheduled }.count
        let cancelled = notificationHistory.filter { $0.status == .cancelled }.count

        var categoryStats: [String: Int] = [:]
        for record in notificationHistory {
            categoryStats[record.categoryId] = (categoryStats[record.categoryId] ?? 0) + 1
        }

        return NotificationStatistics(
            totalNotifications: total,
            sentNotifications: sent,
            scheduledNotifications: scheduled,
            cancelledNotifications: cancelled,
            categoryStatistics: categoryStats
        )
    }

    // MARK: - 通知历史管理方法

    /// 刷新通知历史
    func refreshNotificationHistory() async {
        await loadPendingNotifications()
        // 重新加载历史记录
        loadNotificationHistory()
    }

    /// 清空通知历史
    func clearNotificationHistory() async {
        await MainActor.run {
            notificationHistory.removeAll()
            saveNotificationHistory()
        }
    }

    /// 删除指定通知记录
    func deleteNotifications(_ notifications: [NotificationRecord]) async {
        await MainActor.run {
            let idsToDelete = Set(notifications.map { $0.id })
            notificationHistory.removeAll { idsToDelete.contains($0.id) }
            saveNotificationHistory()
        }
    }

    /// 标记通知为已读
    func markNotificationAsRead(_ notificationId: String) {
        if let index = notificationHistory.firstIndex(where: { $0.id == notificationId }) {
            notificationHistory[index].isRead = true
            saveNotificationHistory()
        }
    }

    /// 批量标记通知为已读
    func markNotificationsAsRead(_ notificationIds: [String]) {
        let idsSet = Set(notificationIds)
        for index in notificationHistory.indices {
            if idsSet.contains(notificationHistory[index].id) {
                notificationHistory[index].isRead = true
            }
        }
        saveNotificationHistory()
    }

    /// 公开加载通知历史方法
    func loadNotificationHistoryAsync() async {
        await MainActor.run {
            loadNotificationHistory()
        }
    }

    // MARK: - 通知分类管理

    /// 添加通知分类
    func addNotificationCategory(_ category: NotificationCategory) async {
        await MainActor.run {
            notificationCategories.append(category)
            saveNotificationCategories()
            setupNotificationCategories()
        }
    }

    /// 更新通知分类
    func updateNotificationCategory(_ category: NotificationCategory) async {
        await MainActor.run {
            if let index = notificationCategories.firstIndex(where: { $0.id == category.id }) {
                notificationCategories[index] = category
                saveNotificationCategories()
                setupNotificationCategories()
            }
        }
    }

    /// 删除通知分类
    func deleteNotificationCategories(_ categories: [NotificationCategory]) async {
        await MainActor.run {
            let idsToDelete = Set(categories.map { $0.id })
            notificationCategories.removeAll { idsToDelete.contains($0.id) }
            saveNotificationCategories()
            setupNotificationCategories()
        }
    }

    /// 更新分类启用状态
    func updateCategoryEnabled(_ categoryId: String, enabled: Bool) async {
        await MainActor.run {
            if let index = notificationCategories.firstIndex(where: { $0.id == categoryId }) {
                notificationCategories[index].isEnabled = enabled
                saveNotificationCategories()
                setupNotificationCategories()
            }
        }
    }

    /// 保存通知分类
    private func saveNotificationCategories() {
        if let data = try? JSONEncoder().encode(notificationCategories) {
            UserDefaults.standard.set(data, forKey: "NotificationCategories")
        }
    }

    /// 加载通知分类
    private func loadNotificationCategories() {
        if let data = UserDefaults.standard.data(forKey: "NotificationCategories"),
           let categories = try? JSONDecoder().decode([NotificationCategory].self, from: data) {
            notificationCategories = categories
        } else {
            // 设置默认分类
            notificationCategories = [
                NotificationCategory(
                    id: "warranty",
                    name: "保修提醒",
                    description: "产品保修期相关通知",
                    icon: "shield.checkered",
                    color: "blue",
                    isEnabled: true,
                    priority: .high
                ),
                NotificationCategory(
                    id: "maintenance",
                    name: "维护提醒",
                    description: "产品维护保养相关通知",
                    icon: "wrench.and.screwdriver",
                    color: "green",
                    isEnabled: true,
                    priority: .medium
                ),
                NotificationCategory(
                    id: "ocr",
                    name: "OCR处理",
                    description: "说明书OCR处理相关通知",
                    icon: "doc.text.viewfinder",
                    color: "orange",
                    isEnabled: true,
                    priority: .low
                ),
                NotificationCategory(
                    id: "sync",
                    name: "数据同步",
                    description: "数据同步相关通知",
                    icon: "arrow.triangle.2.circlepath",
                    color: "purple",
                    isEnabled: true,
                    priority: .medium
                )
            ]
            saveNotificationCategories()
        }
    }
}
