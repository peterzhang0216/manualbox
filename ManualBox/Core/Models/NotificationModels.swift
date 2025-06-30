//
//  NotificationModels.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import Foundation
import UserNotifications

// MARK: - 增强通知
struct EnhancedNotification {
    let id: String
    let title: String
    let body: String
    let categoryId: String
    let sound: UNNotificationSound
    let userInfo: [AnyHashable: Any]
    let attachments: [UNNotificationAttachment]?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        categoryId: String,
        sound: UNNotificationSound = .default,
        userInfo: [AnyHashable: Any] = [:],
        attachments: [UNNotificationAttachment]? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.categoryId = categoryId
        self.sound = sound
        self.userInfo = userInfo
        self.attachments = attachments
    }
}

// MARK: - 通知记录
struct NotificationRecord: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let categoryId: String
    let scheduledDate: Date
    let sentDate: Date?
    var status: NotificationStatus
    var isRead: Bool = false
    let userInfo: [String: String] // 简化的userInfo，只支持String类型
    
    var isOverdue: Bool {
        guard status == .scheduled else { return false }
        return scheduledDate < Date()
    }
    
    var timeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        
        if let sentDate = sentDate {
            return "已发送 " + formatter.localizedString(for: sentDate, relativeTo: Date())
        } else {
            return "计划 " + formatter.localizedString(for: scheduledDate, relativeTo: Date())
        }
    }
}

// MARK: - 待发送通知
struct PendingNotification: Identifiable {
    let id: String
    let title: String
    let body: String
    let categoryId: String
    let scheduledDate: Date
    let userInfo: [AnyHashable: Any]
    
    var timeUntilSend: TimeInterval {
        return scheduledDate.timeIntervalSince(Date())
    }
    
    var isOverdue: Bool {
        return timeUntilSend < 0
    }
    
    var timeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        
        if isOverdue {
            return "已过期"
        } else {
            return formatter.localizedString(for: scheduledDate, relativeTo: Date())
        }
    }
}

// MARK: - 通知分类
struct NotificationCategory: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: String
    var isEnabled: Bool
    let priority: NotificationPriority
    
    var displayColor: String {
        return isEnabled ? color : "gray"
    }
}

// MARK: - 通知状态
enum NotificationStatus: String, Codable, CaseIterable {
    case scheduled = "scheduled"
    case sent = "sent"
    case cancelled = "cancelled"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .scheduled:
            return "已安排"
        case .sent:
            return "已发送"
        case .cancelled:
            return "已取消"
        case .failed:
            return "发送失败"
        }
    }
    
    var color: String {
        switch self {
        case .scheduled:
            return "blue"
        case .sent:
            return "green"
        case .cancelled:
            return "orange"
        case .failed:
            return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .scheduled:
            return "clock"
        case .sent:
            return "checkmark.circle"
        case .cancelled:
            return "xmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - 通知优先级
enum NotificationPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low:
            return "低"
        case .medium:
            return "中"
        case .high:
            return "高"
        case .urgent:
            return "紧急"
        }
    }
    
    var color: String {
        switch self {
        case .low:
            return "gray"
        case .medium:
            return "blue"
        case .high:
            return "orange"
        case .urgent:
            return "red"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .urgent:
            return 0
        case .high:
            return 1
        case .medium:
            return 2
        case .low:
            return 3
        }
    }
}

// MARK: - 通知统计
struct NotificationStatistics {
    let totalNotifications: Int
    let sentNotifications: Int
    let scheduledNotifications: Int
    let cancelledNotifications: Int
    let categoryStatistics: [String: Int]
    
    var successRate: Double {
        guard totalNotifications > 0 else { return 0.0 }
        return Double(sentNotifications) / Double(totalNotifications)
    }
    
    var cancellationRate: Double {
        guard totalNotifications > 0 else { return 0.0 }
        return Double(cancelledNotifications) / Double(totalNotifications)
    }
    
    var topCategory: String? {
        return categoryStatistics.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - 通知模板
struct NotificationTemplate {
    let id: String
    let name: String
    let categoryId: String
    let titleTemplate: String
    let bodyTemplate: String
    let isCustom: Bool
    
    func createNotification(with variables: [String: String]) -> EnhancedNotification {
        var title = titleTemplate
        var body = bodyTemplate
        
        // 替换模板变量
        for (key, value) in variables {
            title = title.replacingOccurrences(of: "{\(key)}", with: value)
            body = body.replacingOccurrences(of: "{\(key)}", with: value)
        }
        
        return EnhancedNotification(
            title: title,
            body: body,
            categoryId: categoryId
        )
    }
    
    static let defaultTemplates: [NotificationTemplate] = [
        NotificationTemplate(
            id: "warranty_expiring",
            name: "保修即将到期",
            categoryId: "warranty",
            titleTemplate: "保修期即将到期",
            bodyTemplate: "产品「{productName}」的保修期将于{expiryDate}到期。",
            isCustom: false
        ),
        NotificationTemplate(
            id: "maintenance_due",
            name: "维护保养提醒",
            categoryId: "maintenance",
            titleTemplate: "维护保养提醒",
            bodyTemplate: "产品「{productName}」需要进行维护保养。",
            isCustom: false
        ),
        NotificationTemplate(
            id: "ocr_completed",
            name: "OCR处理完成",
            categoryId: "ocr",
            titleTemplate: "OCR处理完成",
            bodyTemplate: "说明书「{manualName}」的OCR处理已完成。",
            isCustom: false
        ),
        NotificationTemplate(
            id: "backup_reminder",
            name: "数据备份提醒",
            categoryId: "backup",
            titleTemplate: "数据备份提醒",
            bodyTemplate: "建议您备份ManualBox数据，上次备份时间：{lastBackupDate}。",
            isCustom: false
        )
    ]
}

// MARK: - 通知筛选器
struct NotificationFilter {
    var categories: Set<String> = []
    var statuses: Set<NotificationStatus> = []
    var dateRange: ClosedRange<Date>?
    var searchText: String = ""
    
    func matches(_ record: NotificationRecord) -> Bool {
        // 分类筛选
        if !categories.isEmpty && !categories.contains(record.categoryId) {
            return false
        }
        
        // 状态筛选
        if !statuses.isEmpty && !statuses.contains(record.status) {
            return false
        }
        
        // 日期范围筛选
        if let dateRange = dateRange {
            let checkDate = record.sentDate ?? record.scheduledDate
            if !dateRange.contains(checkDate) {
                return false
            }
        }
        
        // 文本搜索
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            return record.title.lowercased().contains(searchLower) ||
                   record.body.lowercased().contains(searchLower)
        }
        
        return true
    }
    
    var hasActiveFilters: Bool {
        return !categories.isEmpty || !statuses.isEmpty || dateRange != nil || !searchText.isEmpty
    }
    
    static let empty = NotificationFilter()
}

// MARK: - 通知委托
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // 应用在前台时收到通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 在前台显示通知
        completionHandler([.banner, .sound, .badge])
        
        // 更新通知历史
        updateNotificationHistory(for: notification)
    }
    
    // 用户点击通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationResponse(response)
        completionHandler()
    }
    
    private func updateNotificationHistory(for notification: UNNotification) {
        Task { @MainActor in
            let service = EnhancedNotificationService.shared
            if let index = service.notificationHistory.firstIndex(where: { $0.id == notification.request.identifier }) {
                service.notificationHistory[index].status = .sent
            }
        }
    }
    
    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        let actionIdentifier = response.actionIdentifier
        let notification = response.notification
        
        switch actionIdentifier {
        case "view_product":
            // 导航到产品详情
            handleViewProduct(notification)
        case "extend_warranty":
            // 处理延长保修
            handleExtendWarranty(notification)
        case "schedule_maintenance":
            // 安排维护
            handleScheduleMaintenance(notification)
        case "mark_completed":
            // 标记完成
            handleMarkCompleted(notification)
        default:
            // 默认操作
            break
        }
    }
    
    private func handleViewProduct(_ notification: UNNotification) {
        // 实现产品查看逻辑
        if let productId = notification.request.content.userInfo["productId"] as? String {
            // 发送导航通知
            NotificationCenter.default.post(
                name: Notification.Name("ShowProduct"),
                object: nil,
                userInfo: ["productId": productId]
            )
        }
    }
    
    private func handleExtendWarranty(_ notification: UNNotification) {
        // 实现延长保修逻辑
        print("处理延长保修请求")
    }
    
    private func handleScheduleMaintenance(_ notification: UNNotification) {
        // 实现安排维护逻辑
        print("处理安排维护请求")
    }
    
    private func handleMarkCompleted(_ notification: UNNotification) {
        // 实现标记完成逻辑
        print("处理标记完成请求")
    }
}
