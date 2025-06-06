import SwiftUI
import UserNotifications
import CoreData

struct NotificationScheduler {
    static let shared = NotificationScheduler()
    
    // 定期检查需要发送的通知
    func scheduleNotificationCheck() {
        // 注册应用状态通知
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.checkAndScheduleWarrantyNotifications()
            self.checkAndScheduleMaintenanceNotifications()
        }
        #else
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.checkAndScheduleWarrantyNotifications()
            self.checkAndScheduleMaintenanceNotifications()
        }
        #endif
        
        // 首次启动时检查
        checkAndScheduleWarrantyNotifications()
        checkAndScheduleMaintenanceNotifications()
    }
    
    // 检查并安排保修通知
    func checkAndScheduleWarrantyNotifications() {
        // 获取所有产品，按保修期到期时间排序
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        
        // 保修通知的谓词：有订单、有保修期、保修期尚未过期
        let now = Date()
        let calendar = Calendar.current
        let predicates = [
            NSPredicate(format: "order != nil"),
            NSPredicate(format: "order.warrantyEndDate != nil"),
            NSPredicate(format: "order.warrantyEndDate > %@", now as NSDate)
        ]
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        do {
            let products = try context.fetch(fetchRequest)
            let notificationManager = AppNotificationManager()
            
            // 移除现有通知
            notificationManager.removeAllWarrantyReminders()
            
            // 每个产品安排通知
            for product in products {
                if let order = product.order,
                   let warrantyEndDate = order.warrantyEndDate {
                    // 计算剩余天数
                    let days = calendar.numberOfDaysBetween(now, and: warrantyEndDate)
                    
                    // 如果剩余天数小于等于预设的提醒天数，但还未过期，则创建通知
                    if days <= notificationManager.warrantyReminderDays && days > 0 {
                        // 创建通知内容
                        let content = UNMutableNotificationContent()
                        content.title = "保修期即将到期"
                        content.body = "产品「\(product.productName)」的保修期还剩\(days)天"
                        content.sound = UNNotificationSound.default
                        
                        // 创建触发器 (当天上午10点)
                        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                        dateComponents.hour = 10
                        dateComponents.minute = 0
                        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                        
                        // 创建通知请求
                        let identifier = "warranty-\(product.id?.uuidString ?? UUID().uuidString)"
                        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                        
                        // 添加通知请求
                        UNUserNotificationCenter.current().add(request)
                    }
                }
            }
        } catch {
            print("获取产品失败: \(error.localizedDescription)")
        }
    }
    
    // 检查并安排维护保养通知
    func checkAndScheduleMaintenanceNotifications() {
        // 获取所有需要维护的产品
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Product> = Product.fetchRequest()
        
        // 查询需要维护的产品 (可根据实际需求修改查询条件)
        let now = Date()
        let calendar = Calendar.current
        
        do {
            let products = try context.fetch(fetchRequest)
            
            for product in products {
                // 如果上次维护时间超过了维护周期，则安排通知
                if let lastMaintenance = getLastMaintenanceDate(for: product) {
                    let maintenanceInterval = UserDefaults.standard.integer(forKey: "maintenanceIntervalMonths")
                    if maintenanceInterval > 0 {
                        // 计算下次维护日期
                        if let nextMaintenanceDate = calendar.date(byAdding: .month, value: maintenanceInterval, to: lastMaintenance),
                           nextMaintenanceDate > now {
                            // 创建维护提醒
                            scheduleMaintenanceReminder(for: product, date: nextMaintenanceDate)
                        }
                    }
                } else {
                    // 如果没有维护记录，基于购买日期计算
                    if let order = product.order,
                       let orderDate = order.orderDate {
                        let maintenanceInterval = UserDefaults.standard.integer(forKey: "maintenanceIntervalMonths")
                        if maintenanceInterval > 0 {
                            if let nextMaintenanceDate = calendar.date(byAdding: .month, value: maintenanceInterval, to: orderDate),
                               nextMaintenanceDate > now {
                                scheduleMaintenanceReminder(for: product, date: nextMaintenanceDate)
                            }
                        }
                    }
                }
            }
        } catch {
            print("获取产品失败: \(error.localizedDescription)")
        }
    }
    
    // 获取产品最后一次维护日期
    private func getLastMaintenanceDate(for product: Product) -> Date? {
        // 如果有维修记录，使用最新的维修日期
        if let order = product.order,
           let repairRecords = order.repairRecords,
           let records = repairRecords.allObjects as? [RepairRecord],
           !records.isEmpty {
            return records.compactMap { $0.date }.max()
        }
        
        // 如果没有维修记录，返回nil
        return nil
    }
    
    // 安排维护提醒
    private func scheduleMaintenanceReminder(for product: Product, date: Date) {
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "设备维护提醒"
        content.body = "产品「\(product.productName)」需要进行定期维护保养"
        content.sound = UNNotificationSound.default
        
        // 创建触发器 (提前7天的上午10点)
        let reminderDate = Calendar.current.date(byAdding: .day, value: -7, to: date) ?? date
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        dateComponents.hour = 10
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // 创建通知请求
        let identifier = "maintenance-\(product.id?.uuidString ?? UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // 添加通知请求
        UNUserNotificationCenter.current().add(request)
    }
}
