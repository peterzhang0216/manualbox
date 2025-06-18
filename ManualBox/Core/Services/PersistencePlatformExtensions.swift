//
//  PersistencePlatformExtensions.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import CoreData
#if os(iOS)
import UIKit
#endif

// MARK: - 平台特定的数据同步策略
extension PersistenceController {
    
    // 平台特定的容器配置
    static func platformOptimizedContainer() -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "ManualBox")
        
        // 配置CloudKit选项
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("无法获取持久化存储描述")
        }
        
        // 基础 CloudKit 配置（适用于所有平台）
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        #if os(macOS)
        // macOS 特定配置
        description.setOption("macOS" as NSString, forKey: "CloudKitContainerEnvironment")
        #else
        // iOS 特定配置
        description.setOption("iOS" as NSString, forKey: "CloudKitContainerEnvironment")
        #endif
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data 加载失败: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }
    
    // 平台特定的文件存储路径
    static var platformDocumentsDirectory: URL {
        #if os(macOS)
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ManualBox")
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #endif
    }
} 