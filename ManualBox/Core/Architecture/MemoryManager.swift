//
//  MemoryManager.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/22.
//

import Foundation
import SwiftUI
import Combine
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 内存管理器协议
protocol MemoryManagerProtocol {
    func clearCache()
    func optimizeMemoryUsage()
    func monitorMemoryPressure()
    var currentMemoryUsage: MemoryUsage { get }
    func registerMemoryPressureHandler(_ handler: @escaping (MemoryPressureLevel) -> Void)
    func setMemoryWarningThreshold(_ threshold: Int64)
}

// MARK: - 内存使用信息
struct MemoryUsage {
    let physical: Int64      // 物理内存使用
    let virtual: Int64       // 虚拟内存使用
    let compressed: Int64    // 压缩内存
    let footprint: Int64     // 内存足迹
    let available: Int64     // 可用内存
    let pressure: MemoryPressureLevel
    
    var physicalMB: Double { Double(physical) / 1024 / 1024 }
    var virtualMB: Double { Double(virtual) / 1024 / 1024 }
    var footprintMB: Double { Double(footprint) / 1024 / 1024 }
    var availableMB: Double { Double(available) / 1024 / 1024 }
}

// MARK: - 内存压力级别
enum MemoryPressureLevel: String, CaseIterable {
    case normal = "normal"
    case warning = "warning"
    case urgent = "urgent"
    case critical = "critical"
    
    var description: String {
        switch self {
        case .normal: return "正常"
        case .warning: return "警告"
        case .urgent: return "紧急"
        case .critical: return "严重"
        }
    }
    
    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .yellow
        case .urgent: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - 缓存管理器
class CacheManager {
    static let shared = CacheManager()
    
#if canImport(AppKit)
    private let imageCache = NSCache<NSString, NSImage>()
#else
    private let imageCache = NSCache<NSString, UIImage>()
#endif
    private let dataCache = NSCache<NSString, NSData>()
    private let objectCache = NSCache<NSString, AnyObject>()
    
    private init() {
        setupCaches()
        setupMemoryWarningNotification()
    }
    
    private func setupCaches() {
        // 图片缓存配置
        imageCache.countLimit = 100
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // 数据缓存配置
        dataCache.countLimit = 200
        dataCache.totalCostLimit = 20 * 1024 * 1024 // 20MB
        
        // 对象缓存配置
        objectCache.countLimit = 500
        objectCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }
    
    private func setupMemoryWarningNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        clearAllCaches()
    }
    
    func clearAllCaches() {
        imageCache.removeAllObjects()
        dataCache.removeAllObjects()
        objectCache.removeAllObjects()
        
        // 强制垃圾回收
        autoreleasepool {
            // 清空自动释放池
        }
    }
    
    func clearImageCache() {
        imageCache.removeAllObjects()
    }
    
    func clearDataCache() {
        dataCache.removeAllObjects()
    }
    
    func clearObjectCache() {
        objectCache.removeAllObjects()
    }
    
    // 缓存访问方法
#if canImport(AppKit)
    func setImage(_ image: NSImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // 估算内存成本
        imageCache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func getImage(forKey key: String) -> NSImage? {
        return imageCache.object(forKey: key as NSString)
    }
#else
    func setImage(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // 估算内存成本
        imageCache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func getImage(forKey key: String) -> UIImage? {
        return imageCache.object(forKey: key as NSString)
    }
#endif
    
    func setData(_ data: Data, forKey key: String) {
        dataCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
    }
    
    func getData(forKey key: String) -> Data? {
        return dataCache.object(forKey: key as NSString) as Data?
    }
    
    func setObject(_ object: AnyObject, forKey key: String) {
        objectCache.setObject(object, forKey: key as NSString)
    }
    
    func getObject(forKey key: String) -> AnyObject? {
        return objectCache.object(forKey: key as NSString)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 内存管理器实现
@MainActor
class MemoryManager: MemoryManagerProtocol, ObservableObject {
    static let shared = MemoryManager()
    
    @Published var currentMemoryUsage: MemoryUsage
    @Published var memoryPressureLevel: MemoryPressureLevel = .normal
    @Published var memoryHistory: [MemoryUsageSnapshot] = []
    @Published var isMonitoring = false
    
    private var memoryPressureHandlers: [(MemoryPressureLevel) -> Void] = []
    private var memoryWarningThreshold: Int64 = 300 * 1024 * 1024 // 300MB
    private var monitoringTimer: Timer?
    private var pressureSource: DispatchSourceMemoryPressure?
    
    private let cacheManager = CacheManager.shared
    private let performanceMonitor = ManualBoxPerformanceMonitoringService.shared
    
    struct MemoryUsageSnapshot {
        let timestamp: Date
        let usage: MemoryUsage
    }
    
    private init() {
        self.currentMemoryUsage = Self.getCurrentMemoryUsage()
        setupMemoryPressureMonitoring()
        startMemoryMonitoring()
    }
    
    // MARK: - 公共接口实现
    
    nonisolated func clearCache() {
        let startMemory = Self.getCurrentMemoryUsage().physical
        
        cacheManager.clearAllCaches()
        
        // 清理其他缓存
        URLCache.shared.removeAllCachedResponses()
        
        // 强制垃圾回收
        autoreleasepool {
            // 清空自动释放池
        }
        
        let endMemory = Self.getCurrentMemoryUsage().physical
        let freedMemory = startMemory - endMemory
        
        performanceMonitor.recordMetric(
            "memory_cache_cleared",
            value: Double(freedMemory) / 1024 / 1024,
            unit: "MB",
            tags: ["operation": "cache_clear"]
        )
        
        updateMemoryUsage()
    }
    
    nonisolated func optimizeMemoryUsage() {
        let token = performanceMonitor.startOperation("memory_optimization", category: .memory)
        defer { performanceMonitor.endOperation(token) }
        
        let initialMemory = currentMemoryUsage.physical
        
        // 1. 清理缓存
        clearCache()
        
        // 2. 清理临时文件
        clearTemporaryFiles()
        
        // 3. 优化图片内存使用
        optimizeImageMemory()
        
        // 4. 清理未使用的对象
        cleanupUnusedObjects()
        
        // 5. 强制内存整理
        performMemoryCompaction()
        
        updateMemoryUsage()
        
        let finalMemory = currentMemoryUsage.physical
        let memoryFreed = initialMemory - finalMemory
        
        performanceMonitor.recordMetric(
            "memory_optimization_completed",
            value: Double(memoryFreed) / 1024 / 1024,
            unit: "MB",
            tags: ["freed_memory": String(memoryFreed)]
        )
        
        print("🧹 [MemoryManager] 内存优化完成，释放了 \(Double(memoryFreed) / 1024 / 1024) MB")
    }
    
    nonisolated func monitorMemoryPressure() {
        if !isMonitoring {
            startMemoryMonitoring()
        }
    }
    
    nonisolated func registerMemoryPressureHandler(_ handler: @escaping (MemoryPressureLevel) -> Void) {
        memoryPressureHandlers.append(handler)
    }
    
    nonisolated func setMemoryWarningThreshold(_ threshold: Int64) {
        memoryWarningThreshold = threshold
    }
    
    // MARK: - 私有方法
    
    private func setupMemoryPressureMonitoring() {
        pressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .urgent, .critical], queue: .main)
        
        pressureSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let event = self.pressureSource?.mask
            var pressureLevel: MemoryPressureLevel = .normal
            
            if event?.contains(.critical) == true {
                pressureLevel = .critical
            } else if event?.contains(.urgent) == true {
                pressureLevel = .urgent
            } else if event?.contains(.warning) == true {
                pressureLevel = .warning
            }
            
            Task { @MainActor in
                self.handleMemoryPressure(pressureLevel)
            }
        }
        
        pressureSource?.resume()
    }
    
    private func startMemoryMonitoring() {
        isMonitoring = true
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.updateMemoryUsage()
                self.checkMemoryThresholds()
                self.recordMemorySnapshot()
            }
        }
    }
    
    private func stopMemoryMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func updateMemoryUsage() {
        currentMemoryUsage = Self.getCurrentMemoryUsage()
        
        // 更新压力级别
        let newPressureLevel = determinePressureLevel(from: currentMemoryUsage)
        if newPressureLevel != memoryPressureLevel {
            memoryPressureLevel = newPressureLevel
            handleMemoryPressure(newPressureLevel)
        }
    }
    
    private func determinePressureLevel(from usage: MemoryUsage) -> MemoryPressureLevel {
        let physicalMB = usage.physicalMB
        
        if physicalMB > 500 {
            return .critical
        } else if physicalMB > 350 {
            return .urgent
        } else if physicalMB > 250 {
            return .warning
        } else {
            return .normal
        }
    }
    
    private func handleMemoryPressure(_ level: MemoryPressureLevel) {
        print("⚠️ [MemoryManager] 内存压力级别: \(level.description)")
        
        // 通知所有处理器
        for handler in memoryPressureHandlers {
            handler(level)
        }
        
        // 根据压力级别采取行动
        switch level {
        case .normal:
            break
        case .warning:
            cacheManager.clearImageCache()
        case .urgent:
            cacheManager.clearAllCaches()
            clearTemporaryFiles()
        case .critical:
            optimizeMemoryUsage()
        }
        
        // 记录内存压力事件
        performanceMonitor.recordMetric(
            "memory_pressure_event",
            value: Double(level.rawValue.count),
            unit: "level",
            tags: ["pressure_level": level.rawValue]
        )
    }
    
    private func checkMemoryThresholds() {
        if currentMemoryUsage.physical > memoryWarningThreshold {
            handleMemoryPressure(.warning)
        }
    }
    
    private func recordMemorySnapshot() {
        let snapshot = MemoryUsageSnapshot(timestamp: Date(), usage: currentMemoryUsage)
        memoryHistory.append(snapshot)
        
        // 限制历史记录数量
        if memoryHistory.count > 1000 {
            memoryHistory.removeFirst(memoryHistory.count - 1000)
        }
    }
    
    private func clearTemporaryFiles() {
        let tempDir = NSTemporaryDirectory()
        let fileManager = FileManager.default
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(atPath: tempDir)
            for file in tempFiles {
                let filePath = (tempDir as NSString).appendingPathComponent(file)
                try? fileManager.removeItem(atPath: filePath)
            }
        } catch {
            print("❌ [MemoryManager] 清理临时文件失败: \(error)")
        }
    }
    
    private func optimizeImageMemory() {
        // 清理图片缓存
        cacheManager.clearImageCache()
        
        // 可以在这里添加更多图片内存优化逻辑
        // 例如：压缩内存中的图片、释放不可见的图片等
    }
    
    private func cleanupUnusedObjects() {
        // 强制执行垃圾回收
        autoreleasepool {
            // 清空自动释放池中的对象
        }
    }
    
    private func performMemoryCompaction() {
        // 在iOS中，我们无法直接控制内存压缩
        // 但可以通过清理和重组来帮助系统优化内存使用
        
        // 清理所有缓存
        clearCache()
        
        // 触发自动释放池清理
        for _ in 0..<3 {
            autoreleasepool {
                // 多次清理自动释放池
            }
        }
    }
    
    // MARK: - 静态方法
    
    static func getCurrentMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            // 获取系统内存信息
            let physicalMemory = ProcessInfo.processInfo.physicalMemory
            let availableMemory = physicalMemory - UInt64(info.resident_size)
            
            return MemoryUsage(
                physical: Int64(info.resident_size),
                virtual: Int64(info.virtual_size),
                compressed: 0, // iOS不直接提供压缩内存信息
                footprint: Int64(info.resident_size),
                available: Int64(availableMemory),
                pressure: .normal
            )
        } else {
            return MemoryUsage(
                physical: 0,
                virtual: 0,
                compressed: 0,
                footprint: 0,
                available: 0,
                pressure: .normal
            )
        }
    }
    
    deinit {
        stopMemoryMonitoring()
        pressureSource?.cancel()
    }
}

// MARK: - SwiftUI 视图扩展
extension View {
    func onMemoryPressure(_ action: @escaping (MemoryPressureLevel) -> Void) -> some View {
        self.onAppear {
            MemoryManager.shared.registerMemoryPressureHandler(action)
        }
    }
}

// MARK: - 内存使用视图
struct MemoryUsageView: View {
    @StateObject private var memoryManager = MemoryManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("内存使用情况")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(memoryManager.memoryPressureLevel.color)
                    .frame(width: 12, height: 12)
                
                Text(memoryManager.memoryPressureLevel.description)
                    .font(.caption)
                    .foregroundColor(memoryManager.memoryPressureLevel.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                MemoryManagerUsageRow(
                    title: "物理内存",
                    value: memoryManager.currentMemoryUsage.physicalMB,
                    unit: "MB"
                )
                
                MemoryManagerUsageRow(
                    title: "虚拟内存",
                    value: memoryManager.currentMemoryUsage.virtualMB,
                    unit: "MB"
                )
                
                MemoryManagerUsageRow(
                    title: "可用内存",
                    value: memoryManager.currentMemoryUsage.availableMB,
                    unit: "MB"
                )
            }
            
            HStack {
                Button("清理缓存") {
                    Task {
                        await memoryManager.clearCache()
                    }
                }
                .buttonStyle(.bordered)
                
                Button("优化内存") {
                    Task {
                        await memoryManager.optimizeMemoryUsage()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct MemoryManagerUsageRow: View {
    let title: String
    let value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(String(format: "%.1f", value)) \(unit)")
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}