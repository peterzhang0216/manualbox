import Foundation
import SwiftUI
import CoreData
import UserNotifications

// 改名为AppNotificationManager以避免名称冲突
class AppNotificationManager: ObservableObject {
    // 保修提醒设置
    @AppStorage("enableWarrantyReminders") var enableWarrantyReminders = true
    @AppStorage("warrantyReminderDays") var warrantyReminderDays = 30
    
    // 通知权限状态
    @Published var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    
    init() {
        checkNotificationAuthorizationStatus()
    }
    
    // 检查通知权限状态
    func checkNotificationAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationAuthorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    // 注册通知权限
    func registerForNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if let error = error {
                print("通知授权失败: \(error.localizedDescription)")
            }
            // 更新权限状态
            DispatchQueue.main.async {
                self.checkNotificationAuthorizationStatus()
            }
        }
    }

    // 异步请求通知权限
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                print("✅ 通知权限已获得")
            } else {
                print("⚠️ 通知权限被拒绝")
            }
            // 更新权限状态
            await MainActor.run {
                self.checkNotificationAuthorizationStatus()
            }
        } catch {
            print("❌ 请求通知权限失败: \(error.localizedDescription)")
        }
    }
    
    // 打开系统设置
    func openNotificationSettings() {
        #if os(macOS)
        // macOS: 打开通知设置
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
        #else
        // iOS: 打开设置页面
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    // 更新所有产品的保修提醒
    func updateAllWarrantyReminders(in context: NSManagedObjectContext) {
        // 如果禁用了保修提醒，直接返回
        if !enableWarrantyReminders {
            removeAllWarrantyReminders()
            return
        }
        
        // 获取所有有订单且有保修期的产品
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "order != nil")
        
        do {
            let products = try context.fetch(fetchRequest)
            
            // 移除所有现有的提醒，然后重新创建
            removeAllWarrantyReminders()
            
            // 为每个产品创建提醒
            for product in products {
                if let order = product.order,
                   let warrantyEndDate = order.warrantyEndDate {
                    createWarrantyReminder(for: product, endDate: warrantyEndDate)
                }
            }
        } catch {
            print("获取产品失败: \(error.localizedDescription)")
        }
    }
    
    // 为特定产品创建保修提醒
    func createWarrantyReminder(for product: Product, endDate: Date) {
        guard enableWarrantyReminders else { return }
        
        // 计算提醒日期
        let reminderDate = Calendar.current.date(byAdding: .day, value: -warrantyReminderDays, to: endDate)
        
        // 如果提醒日期已经过去，不创建提醒
        guard let reminderDate = reminderDate, reminderDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "保修期即将到期"
        // 修复中文引号问题
        content.body = "产品「\(product.productName)」的保修期将于\(formatDate(endDate))到期。"
        content.sound = UNNotificationSound.default
        
        // 创建通知触发器
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        // 创建通知请求
        let identifier = "warranty-\(product.id?.uuidString ?? UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // 添加通知请求
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("创建保修提醒失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 移除产品的保修提醒
    func removeWarrantyReminder(for productId: UUID) {
        let identifier = "warranty-\(productId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // 移除所有保修提醒
    func removeAllWarrantyReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests.filter { $0.identifier.hasPrefix("warranty-") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    // 日期格式化
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}