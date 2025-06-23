//
//  DataInitializationManager.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/23.
//

import CoreData
import Foundation

/// 统一的数据初始化管理器
/// 负责管理所有默认数据的创建，防止重复初始化
class DataInitializationManager {
    
    // MARK: - 单例
    static let shared = DataInitializationManager()
    
    // MARK: - 私有属性
    private let initializationKey = "ManualBox_DataInitializationManager_HasInitialized"
    private let versionKey = "ManualBox_DataInitializationManager_Version"
    private let currentVersion = "1.0.0"
    
    private var isInitializing = false
    private let initializationQueue = DispatchQueue(label: "com.manualbox.data-initialization", qos: .utility)
    
    private init() {}
    
    // MARK: - 公开方法
    
    /// 检查是否需要初始化默认数据
    func shouldInitializeDefaultData() -> Bool {
        let hasInitialized = UserDefaults.standard.bool(forKey: initializationKey)
        let lastVersion = UserDefaults.standard.string(forKey: versionKey)
        
        // 如果从未初始化过，或者版本不匹配，则需要初始化
        return !hasInitialized || lastVersion != currentVersion
    }
    
    /// 安全地初始化默认数据（防止重复调用）
    @MainActor
    func initializeDefaultDataIfNeeded(in context: NSManagedObjectContext) async -> InitializationResult {
        // 防止重复初始化
        guard !isInitializing else {
            print("[DataInitManager] 正在初始化中，跳过重复调用")
            return InitializationResult(
                categoriesCreated: 0,
                tagsCreated: 0,
                wasAlreadyInitialized: true,
                success: true,
                message: "初始化已在进行中"
            )
        }
        
        // 检查是否需要初始化
        guard shouldInitializeDefaultData() else {
            print("[DataInitManager] 数据已初始化，跳过")
            return InitializationResult(
                categoriesCreated: 0,
                tagsCreated: 0,
                wasAlreadyInitialized: true,
                success: true,
                message: "数据已初始化"
            )
        }
        
        isInitializing = true
        defer { isInitializing = false }
        
        return await withCheckedContinuation { continuation in
            context.perform {
                var categoriesCreated = 0
                var tagsCreated = 0
                var success = true
                var message = ""
                
                do {
                    print("[DataInitManager] 开始初始化默认数据...")
                    
                    // 1. 清理重复数据
                    let persistenceController = PersistenceController.shared
                    persistenceController.removeDuplicateData()
                    
                    // 2. 检查并创建默认分类
                    let categoriesRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
                    let categoriesCount = (try? context.count(for: categoriesRequest)) ?? 0
                    
                    if categoriesCount == 0 {
                        Category.createDefaultCategories(in: context)
                        let newCategoriesCount = (try? context.count(for: categoriesRequest)) ?? 0
                        categoriesCreated = newCategoriesCount
                        print("[DataInitManager] 创建了 \(categoriesCreated) 个默认分类")
                    } else {
                        print("[DataInitManager] 已存在 \(categoriesCount) 个分类，跳过创建")
                    }
                    
                    // 3. 检查并创建默认标签
                    let tagsRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
                    let tagsCount = (try? context.count(for: tagsRequest)) ?? 0
                    
                    if tagsCount == 0 {
                        Tag.createDefaultTags(in: context)
                        let newTagsCount = (try? context.count(for: tagsRequest)) ?? 0
                        tagsCreated = newTagsCount
                        print("[DataInitManager] 创建了 \(tagsCreated) 个默认标签")
                    } else {
                        print("[DataInitManager] 已存在 \(tagsCount) 个标签，跳过创建")
                    }
                    
                    // 4. 保存更改
                    if context.hasChanges {
                        try context.save()
                        print("[DataInitManager] 数据保存成功")
                    }
                    
                    // 5. 标记初始化完成
                    self.markInitializationComplete()
                    
                    message = "默认数据初始化完成"
                    
                } catch {
                    success = false
                    message = "初始化失败: \(error.localizedDescription)"
                    print("[DataInitManager] 错误: \(message)")
                }
                
                let result = InitializationResult(
                    categoriesCreated: categoriesCreated,
                    tagsCreated: tagsCreated,
                    wasAlreadyInitialized: false,
                    success: success,
                    message: message
                )
                
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 强制重新初始化（用于重置功能）
    @MainActor
    func forceReinitialize(in context: NSManagedObjectContext) async -> InitializationResult {
        print("[DataInitManager] 开始强制重新初始化...")
        
        // 重置初始化标记
        resetInitializationFlag()
        
        // 执行初始化
        return await initializeDefaultDataIfNeeded(in: context)
    }
    
    // MARK: - 私有方法
    
    private func markInitializationComplete() {
        UserDefaults.standard.set(true, forKey: initializationKey)
        UserDefaults.standard.set(currentVersion, forKey: versionKey)
        UserDefaults.standard.synchronize()
        print("[DataInitManager] 初始化标记已设置")
    }
    
    private func resetInitializationFlag() {
        UserDefaults.standard.removeObject(forKey: initializationKey)
        UserDefaults.standard.removeObject(forKey: versionKey)
        UserDefaults.standard.synchronize()
        print("[DataInitManager] 初始化标记已重置")
    }
    
    // MARK: - 结果类型
    
    struct InitializationResult {
        let categoriesCreated: Int
        let tagsCreated: Int
        let wasAlreadyInitialized: Bool
        let success: Bool
        let message: String
        
        var summary: String {
            if wasAlreadyInitialized {
                return "数据已初始化"
            } else if success {
                return "成功创建 \(categoriesCreated) 个分类和 \(tagsCreated) 个标签"
            } else {
                return "初始化失败: \(message)"
            }
        }
    }
}

// MARK: - PersistenceController Extension
extension PersistenceController {
    /// 使用统一的数据初始化管理器
    @MainActor
    func initializeDefaultDataSafely() async -> DataInitializationManager.InitializationResult {
        return await DataInitializationManager.shared.initializeDefaultDataIfNeeded(in: container.viewContext)
    }
    
    /// 强制重新初始化
    @MainActor
    func forceReinitializeData() async -> DataInitializationManager.InitializationResult {
        return await DataInitializationManager.shared.forceReinitialize(in: container.viewContext)
    }
}
