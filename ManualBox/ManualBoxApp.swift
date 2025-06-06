//
//  ManualBoxApp.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import SwiftUI
import UserNotifications
import CoreData

@main
struct ManualBoxApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var notificationManager = AppNotificationManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(notificationManager)
                .onAppear {
                    // 初始化默认数据
                    persistenceController.initializeDefaultData()
                    
                    // 注册通知并安排通知检查
                    notificationManager.registerForNotifications()
                    NotificationScheduler.shared.scheduleNotificationCheck()
                }
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建产品") {
                    NotificationCenter.default.post(name: Notification.Name("ShowNewProductSheet"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        #endif
    }
}

// 通知管理器
class NotificationManager: ObservableObject {
    @Published var isNotificationsEnabled = false
    @Published var showingPermissionAlert = false
    
    func registerNotificationCategories() {
        let warrantyCategory = UNNotificationCategory(
            identifier: "WARRANTY_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction, .hiddenPreviewsShowTitle]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([warrantyCategory])
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isNotificationsEnabled = settings.authorizationStatus == .authorized
                
                switch settings.authorizationStatus {
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        DispatchQueue.main.async {
                            self?.isNotificationsEnabled = granted
                            if granted {
                                print("通知权限已获取")
                                self?.registerNotificationCategories()
                                #if os(iOS)
                                UIApplication.shared.registerForRemoteNotifications()
                                #endif
                            } else if let error = error {
                                print("通知权限请求失败: \(error.localizedDescription)")
                            }
                        }
                    }
                case .denied:
                    print("通知权限被用户拒绝，请在系统设置中开启")
                    self?.showingPermissionAlert = true
                case .authorized:
                    DispatchQueue.main.async {
                        self?.registerNotificationCategories()
                        #if os(iOS)
                        UIApplication.shared.registerForRemoteNotifications()
                        #endif
                    }
                default:
                    break
                }
            }
        }
    }
    
    // 引导用户去系统设置开启通知权限
    func openNotificationSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #else
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
        #endif
    }
    
    // 为产品设置保修到期提醒
    func scheduleWarrantyReminder(for product: Product) {
        guard let order = product.order,
              let endDate = order.warrantyEndDate,
              endDate > Date() else {
            return
        }
        
        // 设置在到期前7天和1天提醒
        let calendar = Calendar.current
        
        // 7天提醒
        if let sevenDayReminder = calendar.date(byAdding: .day, value: -7, to: endDate) {
            scheduleNotification(
                for: product,
                at: sevenDayReminder,
                title: "保修即将到期",
                body: "\(product.productName) 的保修将在7天后到期",
                identifier: "warranty-7day-\(product.id?.uuidString ?? UUID().uuidString)"
            )
        }
        
        // 1天提醒
        if let oneDayReminder = calendar.date(byAdding: .day, value: -1, to: endDate) {
            scheduleNotification(
                for: product,
                at: oneDayReminder,
                title: "保修明天到期",
                body: "\(product.productName) 的保修将在明天到期",
                identifier: "warranty-1day-\(product.id?.uuidString ?? UUID().uuidString)"
            )
        }
    }
    
    // 取消产品的所有提醒
    func cancelReminders(for product: Product) {
        guard let productId = product.id?.uuidString else { return }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["warranty-7day-\(productId)", "warranty-1day-\(productId)"]
        )
    }
    
    // 通用的通知调度方法
    private func scheduleNotification(for product: Product, at date: Date, title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "WARRANTY_REMINDER"
        
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("调度通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 检查并更新所有产品的保修提醒
    func updateAllWarrantyReminders(in context: NSManagedObjectContext) {
        let request = NSFetchRequest<Product>(entityName: "Product")
        request.predicate = NSPredicate(format: "order.warrantyEndDate != nil")
        
        do {
            let products = try context.fetch(request)
            for product in products {
                // 先取消可能的旧提醒
                cancelReminders(for: product)
                
                // 如果保修期有效，设置新的提醒
                if product.hasActiveWarranty {
                    scheduleWarrantyReminder(for: product)
                }
            }
        } catch {
            print("更新保修提醒失败: \(error.localizedDescription)")
        }
    }
    
    #if os(macOS)
    // 添加 macOS 上使用的 ExportService 方法
    @MainActor
    static func exportToPDF(products: [Product]) -> Data? {
        let pdfMetaData = [
            kCGPDFContextCreator: "ManualBox",
            kCGPDFContextAuthor: "Generated by ManualBox",
            kCGPDFContextTitle: "商品记录导出"
        ]
        
        let pageWidth: CGFloat = 595.2 // A4
        let pageHeight: CGFloat = 841.8 // A4
        
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer,
                                    mediaBox: &mediaBox,
                                    pdfMetaData as CFDictionary) else {
            return nil
        }
        
        for (index, _) in products.enumerated() {
            if index > 0 {
                context.beginPage(mediaBox: &mediaBox)
            }
            
            // 绘制商品信息代码保持不变...
        }
        
        context.closePDF()
        return data as Data
    }
    #endif
}

#if os(macOS)
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // macOS 特定的初始化代码
        if let appearance = NSAppearance(named: .vibrantDark) {
            NSApp.appearance = appearance
        }
        
        // 启用自动深色模式跟随系统
        NSApp.setActivationPolicy(.regular)
    }
}
#else
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // iOS 特定的初始化代码
        return true
    }
}
#endif
