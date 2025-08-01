//
//  PerformanceOptimizationService.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/25.
//

import Foundation
import SwiftUI
import Combine
import CoreData

// MARK: - 性能优化服务
@MainActor
class PerformanceOptimizationService: ObservableObject {
    static let shared = PerformanceOptimizationService()
    
    @Published var performanceMetrics: OptimizationPerformanceMetrics = OptimizationPerformanceMetrics()
    @Published var optimizationSuggestions: [OptimizationSuggestion] = []
    @Published var isOptimizing = false
    
    private var cancellables = Set<AnyCancellable>()
    private let metricsCollector = MetricsCollector()
    
    init() {
        startPerformanceMonitoring()
    }
    
    // MARK: - 性能监控
    
    private func startPerformanceMonitoring() {
        // 每30秒收集一次性能指标
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.collectPerformanceMetrics()
            }
            .store(in: &cancellables)
    }
    
    private func collectPerformanceMetrics() {
        Task {
            let metrics = await metricsCollector.collectMetrics()
            await MainActor.run {
                self.performanceMetrics = metrics
                self.generateOptimizationSuggestions()
            }
        }
    }
    
    // MARK: - 优化建议生成
    
    private func generateOptimizationSuggestions() {
        var suggestions: [OptimizationSuggestion] = []
        
        // 内存使用优化
        if performanceMetrics.memoryUsage > 200 { // MB
            suggestions.append(OptimizationSuggestion(
                type: .memory,
                title: "内存使用过高",
                description: "当前内存使用量为 \(performanceMetrics.memoryUsage)MB，建议清理缓存",
                priority: .high,
                action: .clearCache
            ))
        }
        
        // CPU使用优化
        if performanceMetrics.cpuUsage > 80 { // %
            suggestions.append(OptimizationSuggestion(
                type: .cpu,
                title: "CPU使用率过高",
                description: "当前CPU使用率为 \(performanceMetrics.cpuUsage)%，建议减少后台任务",
                priority: .medium,
                action: .reduceBackgroundTasks
            ))
        }
        
        // 存储空间优化
        if performanceMetrics.storageUsage > 1000 { // MB
            suggestions.append(OptimizationSuggestion(
                type: .storage,
                title: "存储空间使用过多",
                description: "当前存储使用量为 \(performanceMetrics.storageUsage)MB，建议清理临时文件",
                priority: .medium,
                action: .cleanTempFiles
            ))
        }
        
        // 网络性能优化
        if performanceMetrics.networkLatency > 1000 { // ms
            suggestions.append(OptimizationSuggestion(
                type: .network,
                title: "网络延迟较高",
                description: "当前网络延迟为 \(performanceMetrics.networkLatency)ms，建议检查网络连接",
                priority: .low,
                action: .optimizeNetwork
            ))
        }
        
        // 数据库性能优化
        if performanceMetrics.databaseQueryTime > 500 { // ms
            suggestions.append(OptimizationSuggestion(
                type: .database,
                title: "数据库查询较慢",
                description: "平均查询时间为 \(performanceMetrics.databaseQueryTime)ms，建议优化数据库",
                priority: .medium,
                action: .optimizeDatabase
            ))
        }
        
        optimizationSuggestions = suggestions
    }
    
    // MARK: - 优化执行
    
    func executeOptimization(_ suggestion: OptimizationSuggestion) async {
        isOptimizing = true
        defer { isOptimizing = false }
        
        switch suggestion.action {
        case .clearCache:
            await clearCache()
        case .reduceBackgroundTasks:
            await reduceBackgroundTasks()
        case .cleanTempFiles:
            await cleanTempFiles()
        case .optimizeNetwork:
            await optimizeNetwork()
        case .optimizeDatabase:
            await optimizeDatabase()
        }
        
        // 重新收集指标
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
        collectPerformanceMetrics()
    }
    
    func executeAllOptimizations() async {
        isOptimizing = true
        defer { isOptimizing = false }
        
        for suggestion in optimizationSuggestions {
            await executeOptimization(suggestion)
        }
    }
    
    // MARK: - 具体优化方法
    
    private func clearCache() async {
        // 清理图片缓存
        URLCache.shared.removeAllCachedResponses()
        
        // 清理临时文件
        let tempDir = NSTemporaryDirectory()
        let fileManager = FileManager.default
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(atPath: tempDir)
            for file in tempFiles {
                let filePath = tempDir + file
                try fileManager.removeItem(atPath: filePath)
            }
        } catch {
            print("清理缓存失败: \(error)")
        }
    }
    
    private func reduceBackgroundTasks() async {
        // 暂停非关键的后台任务
        NotificationCenter.default.post(name: .pauseBackgroundTasks, object: nil)
    }
    
    private func cleanTempFiles() async {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tempPath = documentsPath.appendingPathComponent("temp")
        
        do {
            if fileManager.fileExists(atPath: tempPath.path) {
                try fileManager.removeItem(at: tempPath)
            }
            try fileManager.createDirectory(at: tempPath, withIntermediateDirectories: true)
        } catch {
            print("清理临时文件失败: \(error)")
        }
    }
    
    private func optimizeNetwork() async {
        // 优化网络请求配置
        URLSession.shared.configuration.timeoutIntervalForRequest = 30
        URLSession.shared.configuration.timeoutIntervalForResource = 60
    }
    
    private func optimizeDatabase() async {
        // 执行数据库优化
        let context = PersistenceController.shared.container.viewContext
        
        await context.perform {
            // 清理删除的对象
            context.processPendingChanges()
            
            // 重置上下文以释放内存
            context.reset()
        }
    }
    
    // MARK: - 性能报告
    
    func generatePerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            timestamp: Date(),
            metrics: performanceMetrics,
            suggestions: optimizationSuggestions,
            optimizationHistory: getOptimizationHistory()
        )
    }
    
    private func getOptimizationHistory() -> [OptimizationRecord] {
        guard let data = UserDefaults.standard.data(forKey: "optimization_history"),
              let history = try? JSONDecoder().decode([OptimizationRecord].self, from: data) else {
            return []
        }
        return history
    }
    
    private func recordOptimization(_ suggestion: OptimizationSuggestion) {
        var history = getOptimizationHistory()
        
        let record = OptimizationRecord(
            type: suggestion.type,
            action: suggestion.action,
            timestamp: Date(),
            beforeMetrics: performanceMetrics,
            success: true
        )
        
        history.append(record)
        
        // 只保留最近100条记录
        if history.count > 100 {
            history = Array(history.suffix(100))
        }
        
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "optimization_history")
        }
    }
}

// MARK: - 指标收集器
class MetricsCollector {
    
    func collectMetrics() async -> OptimizationPerformanceMetrics {
        let memoryUsage = await getMemoryUsage()
        let cpuUsage = await getCPUUsage()
        let storageUsage = await getStorageUsage()
        let networkLatency = await getNetworkLatency()
        let databaseQueryTime = await getDatabaseQueryTime()
        
        return OptimizationPerformanceMetrics(
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            storageUsage: storageUsage,
            networkLatency: networkLatency,
            databaseQueryTime: databaseQueryTime,
            timestamp: Date()
        )
    }
    
    private func getMemoryUsage() async -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024 / 1024 // MB
        }
        
        return 0
    }
    
    private func getCPUUsage() async -> Double {
        // 简化的CPU使用率计算
        return Double.random(in: 10...30) // 模拟值
    }
    
    private func getStorageUsage() async -> Double {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let resourceValues = try documentsPath.resourceValues(forKeys: [.fileSizeKey])
            return Double(resourceValues.fileSize ?? 0) / 1024 / 1024 // MB
        } catch {
            return 0
        }
    }
    
    private func getNetworkLatency() async -> Double {
        // 简化的网络延迟测试
        let startTime = Date()
        
        do {
            let url = URL(string: "https://www.apple.com")!
            let (_, _) = try await URLSession.shared.data(from: url)
            return Date().timeIntervalSince(startTime) * 1000 // ms
        } catch {
            return 0
        }
    }
    
    private func getDatabaseQueryTime() async -> Double {
        let startTime = Date()
        
        let context = PersistenceController.shared.container.viewContext
        
        await context.perform {
            let request: NSFetchRequest<Product> = Product.fetchRequest()
            request.fetchLimit = 10
            _ = try? context.fetch(request)
        }
        
        return Date().timeIntervalSince(startTime) * 1000 // ms
    }
}

// MARK: - 数据结构

struct OptimizationPerformanceMetrics: Codable {
    let memoryUsage: Double // MB
    let cpuUsage: Double // %
    let storageUsage: Double // MB
    let networkLatency: Double // ms
    let databaseQueryTime: Double // ms
    let timestamp: Date
    
    init() {
        self.memoryUsage = 0
        self.cpuUsage = 0
        self.storageUsage = 0
        self.networkLatency = 0
        self.databaseQueryTime = 0
        self.timestamp = Date()
    }
    
    init(memoryUsage: Double, cpuUsage: Double, storageUsage: Double, networkLatency: Double, databaseQueryTime: Double, timestamp: Date) {
        self.memoryUsage = memoryUsage
        self.cpuUsage = cpuUsage
        self.storageUsage = storageUsage
        self.networkLatency = networkLatency
        self.databaseQueryTime = databaseQueryTime
        self.timestamp = timestamp
    }
}

struct OptimizationSuggestion: Identifiable, Codable {
    let id: UUID
    let type: OptimizationType
    let title: String
    let description: String
    let priority: Priority
    let action: OptimizationAction

    init(type: OptimizationType, title: String, description: String, priority: Priority, action: OptimizationAction) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.action = action
    }
}

enum OptimizationType: String, CaseIterable, Codable {
    case memory = "内存"
    case cpu = "CPU"
    case storage = "存储"
    case network = "网络"
    case database = "数据库"
}

enum OptimizationAction: String, CaseIterable, Codable {
    case clearCache = "清理缓存"
    case reduceBackgroundTasks = "减少后台任务"
    case cleanTempFiles = "清理临时文件"
    case optimizeNetwork = "优化网络"
    case optimizeDatabase = "优化数据库"
}

// PerformanceReport is defined in PerformanceMonitoringService.swift

struct OptimizationRecord: Identifiable, Codable {
    let id: UUID
    let type: OptimizationType
    let action: OptimizationAction
    let timestamp: Date
    let beforeMetrics: OptimizationPerformanceMetrics
    let success: Bool

    init(type: OptimizationType, action: OptimizationAction, timestamp: Date, beforeMetrics: OptimizationPerformanceMetrics, success: Bool) {
        self.id = UUID()
        self.type = type
        self.action = action
        self.timestamp = timestamp
        self.beforeMetrics = beforeMetrics
        self.success = success
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let pauseBackgroundTasks = Notification.Name("PauseBackgroundTasks")
}
