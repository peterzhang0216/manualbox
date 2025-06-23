//
//  DataInitializationTests.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/23.
//

import CoreData
import Foundation

/// 数据初始化测试工具
/// 用于验证重复数据问题是否已解决
class DataInitializationTests {
    
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    
    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext
    }
    
    /// 运行所有测试
    @MainActor
    func runAllTests() async -> TestResults {
        print("[DataInitTests] 开始运行数据初始化测试...")
        
        var results = TestResults()
        
        // 测试1: 检查当前数据状态
        results.currentDataState = await checkCurrentDataState()
        
        // 测试2: 测试重复数据清理
        results.duplicateCleanupResult = await testDuplicateDataCleanup()
        
        // 测试3: 测试统一初始化管理器
        results.initializationManagerResult = await testInitializationManager()
        
        // 测试4: 测试重复初始化防护
        results.duplicateInitializationResult = await testDuplicateInitializationPrevention()
        
        print("[DataInitTests] 所有测试完成")
        return results
    }
    
    // MARK: - 测试方法
    
    @MainActor
    private func checkCurrentDataState() async -> DataState {
        let categoriesRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
        let categoriesCount = (try? context.count(for: categoriesRequest)) ?? 0
        
        let tagsRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        let tagsCount = (try? context.count(for: tagsRequest)) ?? 0
        
        // 检查重复数据
        let duplicateCategories = await findDuplicateCategories()
        let duplicateTags = await findDuplicateTags()
        
        return DataState(
            categoriesCount: categoriesCount,
            tagsCount: tagsCount,
            duplicateCategoriesCount: duplicateCategories.count,
            duplicateTagsCount: duplicateTags.count
        )
    }
    
    @MainActor
    private func testDuplicateDataCleanup() async -> CleanupResult {
        print("[DataInitTests] 测试重复数据清理...")
        
        // 先记录清理前的状态
        let beforeState = await checkCurrentDataState()
        
        // 执行清理
        persistenceController.removeDuplicateData()
        
        // 记录清理后的状态
        let afterState = await checkCurrentDataState()
        
        let categoriesRemoved = beforeState.duplicateCategoriesCount
        let tagsRemoved = beforeState.duplicateTagsCount
        
        return CleanupResult(
            categoriesRemoved: categoriesRemoved,
            tagsRemoved: tagsRemoved,
            success: afterState.duplicateCategoriesCount == 0 && afterState.duplicateTagsCount == 0
        )
    }
    
    @MainActor
    private func testInitializationManager() async -> InitializationResult {
        print("[DataInitTests] 测试统一初始化管理器...")

        // 重置初始化标记
        DataInitializationManager.shared.resetInitializationFlagForTesting()

        // 执行初始化
        let result = await DataInitializationManager.shared.initializeDefaultDataIfNeeded(in: context)

        return InitializationResult(
            categoriesCreated: result.categoriesCreated,
            tagsCreated: result.tagsCreated,
            success: result.success,
            message: result.message
        )
    }
    
    @MainActor
    private func testDuplicateInitializationPrevention() async -> PreventionResult {
        print("[DataInitTests] 测试重复初始化防护...")
        
        // 第一次初始化
        let firstResult = await DataInitializationManager.shared.initializeDefaultDataIfNeeded(in: context)
        
        // 记录第一次初始化后的数据状态
        let stateAfterFirst = await checkCurrentDataState()
        
        // 第二次初始化（应该被阻止）
        let secondResult = await DataInitializationManager.shared.initializeDefaultDataIfNeeded(in: context)
        
        // 记录第二次初始化后的数据状态
        let stateAfterSecond = await checkCurrentDataState()
        
        // 验证第二次初始化没有创建重复数据
        let noDuplicatesCreated = stateAfterFirst.categoriesCount == stateAfterSecond.categoriesCount &&
                                  stateAfterFirst.tagsCount == stateAfterSecond.tagsCount
        
        return PreventionResult(
            firstInitializationSuccess: firstResult.success,
            secondInitializationPrevented: secondResult.wasAlreadyInitialized,
            noDuplicatesCreated: noDuplicatesCreated
        )
    }
    
    // MARK: - 辅助方法
    
    private func findDuplicateCategories() async -> [String] {
        return await withCheckedContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<Category> = Category.fetchRequest()
                    let categories = try self.context.fetch(request)
                    
                    let groupedCategories = Dictionary(grouping: categories) { category in
                        category.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                    }
                    
                    let duplicates = groupedCategories.compactMap { (name, categories) in
                        categories.count > 1 ? name : nil
                    }
                    
                    continuation.resume(returning: duplicates)
                } catch {
                    print("[DataInitTests] 查找重复分类时出错: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func findDuplicateTags() async -> [String] {
        return await withCheckedContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<Tag> = Tag.fetchRequest()
                    let tags = try self.context.fetch(request)
                    
                    let groupedTags = Dictionary(grouping: tags) { tag in
                        tag.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                    }
                    
                    let duplicates = groupedTags.compactMap { (name, tags) in
                        tags.count > 1 ? name : nil
                    }
                    
                    continuation.resume(returning: duplicates)
                } catch {
                    print("[DataInitTests] 查找重复标签时出错: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // MARK: - 结果类型
    
    struct TestResults {
        var currentDataState: DataState = DataState()
        var duplicateCleanupResult: CleanupResult = CleanupResult()
        var initializationManagerResult: InitializationResult = InitializationResult()
        var duplicateInitializationResult: PreventionResult = PreventionResult()
        
        var summary: String {
            return """
            数据初始化测试结果:
            
            当前数据状态:
            - 分类数量: \(currentDataState.categoriesCount)
            - 标签数量: \(currentDataState.tagsCount)
            - 重复分类: \(currentDataState.duplicateCategoriesCount)
            - 重复标签: \(currentDataState.duplicateTagsCount)
            
            重复数据清理:
            - 清理分类: \(duplicateCleanupResult.categoriesRemoved)
            - 清理标签: \(duplicateCleanupResult.tagsRemoved)
            - 清理成功: \(duplicateCleanupResult.success ? "是" : "否")
            
            初始化管理器:
            - 创建分类: \(initializationManagerResult.categoriesCreated)
            - 创建标签: \(initializationManagerResult.tagsCreated)
            - 初始化成功: \(initializationManagerResult.success ? "是" : "否")
            
            重复初始化防护:
            - 第一次初始化成功: \(duplicateInitializationResult.firstInitializationSuccess ? "是" : "否")
            - 第二次初始化被阻止: \(duplicateInitializationResult.secondInitializationPrevented ? "是" : "否")
            - 无重复数据创建: \(duplicateInitializationResult.noDuplicatesCreated ? "是" : "否")
            """
        }
    }
    
    struct DataState {
        var categoriesCount: Int = 0
        var tagsCount: Int = 0
        var duplicateCategoriesCount: Int = 0
        var duplicateTagsCount: Int = 0
    }
    
    struct CleanupResult {
        var categoriesRemoved: Int = 0
        var tagsRemoved: Int = 0
        var success: Bool = false
    }
    
    struct InitializationResult {
        var categoriesCreated: Int = 0
        var tagsCreated: Int = 0
        var success: Bool = false
        var message: String = ""
    }
    
    struct PreventionResult {
        var firstInitializationSuccess: Bool = false
        var secondInitializationPrevented: Bool = false
        var noDuplicatesCreated: Bool = false
    }
}

// MARK: - DataInitializationManager Extension for Testing
extension DataInitializationManager {
    /// 重置初始化标记（仅用于测试）
    func resetInitializationFlagForTesting() {
        UserDefaults.standard.removeObject(forKey: "ManualBox_DataInitializationManager_HasInitialized")
        UserDefaults.standard.removeObject(forKey: "ManualBox_DataInitializationManager_Version")
        UserDefaults.standard.synchronize()
        print("[DataInitManager] 测试：初始化标记已重置")
    }
}
