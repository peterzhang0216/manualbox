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
    @State private var hasInitialized = false

    init() {
        // 配置依赖注入服务
        ServiceRegistrationManager.configureServices()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(notificationManager)
                .serviceContainer(ServiceContainer.shared)
                .onAppear {
                    // 防止重复初始化
                    guard !hasInitialized else { return }
                    hasInitialized = true

                    Task {
                        print("[App] 开始应用初始化...")

                        // 1. 首先进行数据诊断
                        let diagnosticResult = await persistenceController.quickDiagnose()
                        print("[App] 数据诊断结果: \(diagnosticResult.summary)")

                        // 2. 如果发现问题，先进行清理
                        if diagnosticResult.hasIssues {
                            print("[App] 发现数据问题，开始自动修复...")
                            let fixResult = await persistenceController.autoFixDuplicateData()
                            print("[App] 自动修复结果: \(fixResult.message)")
                        }

                        // 3. 执行智能初始化（发布版本不创建示例数据）
                        let initResult = await persistenceController.performSmartInitialization(createSampleData: false)
                        print("[App] 初始化结果: \(initResult.summary)")

                        // 4. 最终验证数据完整性
                        let validationResult = await persistenceController.performDataValidation()
                        print("[App] 数据验证结果: \(validationResult.summary)")

                        if validationResult.hasErrors {
                            print("[App] ⚠️ 数据验证发现错误，可能需要手动处理")
                            for error in validationResult.errors {
                                print("[App] 错误: \(error.message)")
                            }
                        }

                        // 5. 注册通知并安排通知检查
                        await MainActor.run {
                            notificationManager.registerForNotifications()
                            NotificationScheduler.shared.scheduleNotificationCheck()
                        }

                        print("[App] 应用初始化完成")
                    }
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
