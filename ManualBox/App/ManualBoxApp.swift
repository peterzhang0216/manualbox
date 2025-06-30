//
//  ManualBoxApp.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import SwiftUI
import CoreData

@main
struct ManualBoxApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var notificationManager = AppNotificationManager()
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var hasInitialized = false

    init() {
        print("✅ ManualBox 应用启动")

        // 初始化 SettingsViewModel
        let context = PersistenceController.shared.container.viewContext
        self._settingsViewModel = StateObject(wrappedValue: SettingsViewModel(viewContext: context))
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(notificationManager)
                .environmentObject(settingsViewModel)
                .environmentObject(settingsManager)
                .withLocalization()
                .onAppear {
                    // 防止重复初始化
                    guard !hasInitialized else { return }
                    hasInitialized = true

                    Task {
                        print("[App] 开始应用初始化...")

                        // 1. 初始化通知管理器
                        await notificationManager.requestPermission()

                        // 2. 安全地初始化默认数据
                        let initResult = await persistenceController.initializeDefaultDataSafely()
                        print("[App] 数据初始化结果: \(initResult.summary)")

                        print("[App] 应用初始化完成")
                    }
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        #endif
    }
}


