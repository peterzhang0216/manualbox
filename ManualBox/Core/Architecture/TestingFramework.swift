//
//  TestingFramework.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/22.
//

import Foundation
import CoreData

// MARK: - 测试框架协议
protocol TestingFramework {
    func createTestContext() -> NSManagedObjectContext
    func createMockService<T>(_ type: T.Type) -> T
    func performanceTest<T>(_ operation: () async throws -> T) async -> PerformanceResult<T>
    func setupTestEnvironment() async throws
    func teardownTestEnvironment() async throws
}

// MARK: - 测试环境配置
struct TestEnvironment {
    let context: NSManagedObjectContext
    let persistenceController: PersistenceController
    let serviceContainer: ServiceContainer
    let isInMemory: Bool
    
    init(inMemory: Bool = true) {
        self.isInMemory = inMemory
        self.persistenceController = PersistenceController(inMemory: inMemory)
        self.context = persistenceController.container.viewContext
        self.serviceContainer = ServiceContainer.shared
    }
}

// MARK: - 性能测试结果
struct PerformanceResult<T> {
    let result: T?
    let duration: TimeInterval
    let memoryUsage: MemoryUsage
    let success: Bool
    let error: Error?
    
    struct MemoryUsage {
        let initial: Int64
        let peak: Int64
        let final: Int64
        
        var delta: Int64 { final - initial }
        var peakDelta: Int64 { peak - initial }
    }
}

// MARK: - 测试框架实现
class ManualBoxTestingFramework: TestingFramework {
    static let shared = ManualBoxTestingFramework()
    
    private var testEnvironments: [String: TestEnvironment] = [:]
    private let performanceMonitor = TestPerformanceMonitor()
    
    private init() {}
    
    func createTestContext() -> NSManagedObjectContext {
        let environment = TestEnvironment(inMemory: true)
        let contextId = UUID().uuidString
        testEnvironments[contextId] = environment
        return environment.context
    }
    
    func createMockService<T>(_ type: T.Type) -> T {
        // 使用反射和工厂模式创建模拟服务
        switch type {
        case is ProductServiceProtocol.Type:
            return MockProductService() as! T
        case is CategoryServiceProtocol.Type:
            return MockCategoryService() as! T
        case is FileServiceProtocol.Type:
            return MockFileService() as! T
        case is NotificationServiceProtocol.Type:
            return MockNotificationService() as! T
        case is SyncServiceProtocol.Type:
            return MockSyncService() as! T
        default:
            fatalError("未支持的服务类型: \(type)")
        }
    }
    
    func performanceTest<T>(_ operation: () async throws -> T) async -> PerformanceResult<T> {
        let initialMemory = performanceMonitor.getCurrentMemoryUsage()
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var result: T?
        var error: Error?
        var peakMemory = initialMemory
        
        // 启动内存监控
        let memoryMonitorTask = Task {
            while !Task.isCancelled {
                let currentMemory = performanceMonitor.getCurrentMemoryUsage()
                if currentMemory > peakMemory {
                    peakMemory = currentMemory
                }
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
        
        do {
            result = try await operation()
        } catch let operationError {
            error = operationError
        }
        
        memoryMonitorTask.cancel()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let finalMemory = performanceMonitor.getCurrentMemoryUsage()
        
        return PerformanceResult(
            result: result,
            duration: endTime - startTime,
            memoryUsage: PerformanceResult.MemoryUsage(
                initial: initialMemory,
                peak: peakMemory,
                final: finalMemory
            ),
            success: error == nil,
            error: error
        )
    }
    
    func setupTestEnvironment() async throws {
        // 清理之前的测试环境
        await teardownTestEnvironment()
        
        // 设置测试用的UserDefaults
        UserDefaults.standard.set(true, forKey: "ManualBox_TestMode")
        
        // 初始化服务容器
        ServiceContainer.shared.reset()
        await ServiceContainer.shared.initialize()
    }
    
    func teardownTestEnvironment() async throws {
        // 清理测试环境
        testEnvironments.removeAll()
        
        // 重置UserDefaults
        UserDefaults.standard.removeObject(forKey: "ManualBox_TestMode")
        UserDefaults.standard.removeObject(forKey: "ManualBox_HasInitializedDefaultData")
        
        // 清理服务容器
        ServiceContainer.shared.reset()
    }
}

// MARK: - 测试性能监控器
class TestPerformanceMonitor {
    func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}