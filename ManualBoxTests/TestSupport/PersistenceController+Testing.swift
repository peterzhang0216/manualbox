import CoreData
import XCTest
@testable import ManualBox

/// 测试专用的持久化控制器扩展
/// 提供完全隔离的测试数据环境
extension PersistenceController {
    
    /// 创建独立的测试用 Core Data 栈
    /// 每次调用都会创建一个全新的内存数据库实例
    static func createTestInstance() -> PersistenceController {
        let instance = PersistenceController(inMemory: true)
        
        // 确保每个测试实例都有唯一的数据库名
        let testId = UUID().uuidString
        instance.container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null/test-\(testId)")
        
        return instance
    }
    
    /// 为测试环境初始化基础数据
    /// 创建必要的默认数据，但保持最小化
    @MainActor
    func setupTestData() {
        let context = container.viewContext
        
        // 创建基础分类（测试可能需要）
        let defaultCategory = Category(context: context)
        defaultCategory.id = UUID()
        defaultCategory.name = "测试分类"
        defaultCategory.icon = "folder"
        defaultCategory.createdAt = Date()
        defaultCategory.updatedAt = Date()
        
        // 保存基础数据
        do {
            try context.save()
        } catch {
            print("测试数据初始化失败: \(error)")
        }
    }
    
    /// 清理测试数据
    /// 删除所有测试创建的数据
    @MainActor
    func cleanupTestData() {
        let context = container.viewContext
        
        // 定义需要清理的实体
        let entityNames = [
            "Product",
            "Category", 
            "Tag",
            "Manual",
            "Order",
            "RepairRecord"
        ]
        
        // 批量删除所有实体的数据
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("清理实体 \(entityName) 失败: \(error)")
            }
        }
        
        // 重置上下文
        context.reset()
        
        // 保存更改
        do {
            try context.save()
        } catch {
            print("测试数据清理保存失败: \(error)")
        }
    }
    
    /// 验证数据库是否为空
    /// 用于确认测试隔离是否成功
    func isDatabaseEmpty() -> Bool {
        let context = container.viewContext
        
        let entityNames = ["Product", "Category", "Tag", "Manual", "Order", "RepairRecord"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetchRequest.resultType = .countResultType
            
            do {
                let count = try context.count(for: fetchRequest)
                if count > 0 {
                    return false
                }
            } catch {
                print("检查实体 \(entityName) 数量失败: \(error)")
                return false
            }
        }
        
        return true
    }
}
