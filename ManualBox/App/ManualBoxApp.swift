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

#if os(macOS)
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
#endif
