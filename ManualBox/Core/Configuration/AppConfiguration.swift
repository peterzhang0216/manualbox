import Foundation
import SwiftUI

// MARK: - 应用配置协议
protocol AppConfigurationProtocol {
    var appVersion: String { get }
    var buildNumber: String { get }
    var isDebugMode: Bool { get }
    var environmentType: EnvironmentType { get }
    var databaseConfiguration: DatabaseConfiguration { get }
    var cloudKitConfiguration: CloudKitConfiguration { get }
    var performanceConfiguration: PerformanceConfiguration { get }
}

// MARK: - 环境类型
enum EnvironmentType: String, CaseIterable {
    case development = "Development"
    case staging = "Staging"
    case production = "Production"
    
    var displayName: String {
        switch self {
        case .development: return "开发环境"
        case .staging: return "测试环境"
        case .production: return "生产环境"
        }
    }
}

// MARK: - 数据库配置
struct DatabaseConfiguration {
    let useCloudKit: Bool
    let enableRemoteNotifications: Bool
    let historyTrackingEnabled: Bool
    let batchSize: Int
    let fetchLimit: Int
    
    static let `default` = DatabaseConfiguration(
        useCloudKit: true,
        enableRemoteNotifications: true,
        historyTrackingEnabled: true,
        batchSize: 50,
        fetchLimit: 100
    )
}

// MARK: - CloudKit 配置
struct CloudKitConfiguration {
    let containerIdentifier: String
    let enableSync: Bool
    let syncInterval: TimeInterval
    let retryAttempts: Int
    
    static let `default` = CloudKitConfiguration(
        containerIdentifier: "iCloud.com.yourcompany.ManualBox",
        enableSync: true,
        syncInterval: 300, // 5 minutes
        retryAttempts: 3
    )
}

// MARK: - 性能配置
struct PerformanceConfiguration {
    let enablePerformanceMonitoring: Bool
    let maxMemoryUsage: Int // MB
    let imageCompressionQuality: Float
    let thumbnailSize: CGSize
    let cachePolicy: CachePolicy
    
    static let `default` = PerformanceConfiguration(
        enablePerformanceMonitoring: true,
        maxMemoryUsage: 200,
        imageCompressionQuality: 0.8,
        thumbnailSize: CGSize(width: 150, height: 150),
        cachePolicy: .automatic
    )
}

enum CachePolicy {
    case aggressive  // 激进缓存，高内存使用
    case balanced    // 平衡缓存
    case conservative // 保守缓存，低内存使用
    case automatic   // 根据设备自动选择
}

// MARK: - 主应用配置实现
class AppConfiguration: AppConfigurationProtocol, ObservableObject {
    static let shared = AppConfiguration()
    
    // MARK: - 基本信息
    let appVersion: String
    let buildNumber: String
    let isDebugMode: Bool
    
    // MARK: - 环境配置
    @Published var environmentType: EnvironmentType
    @Published var databaseConfiguration: DatabaseConfiguration
    @Published var cloudKitConfiguration: CloudKitConfiguration
    @Published var performanceConfiguration: PerformanceConfiguration
    
    private init() {
        // 从 Info.plist 读取基本信息
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        #if DEBUG
        self.isDebugMode = true
        self.environmentType = .development
        #else
        self.isDebugMode = false
        self.environmentType = .production
        #endif
        
        // 加载配置
        self.databaseConfiguration = Self.loadDatabaseConfiguration()
        self.cloudKitConfiguration = Self.loadCloudKitConfiguration()
        self.performanceConfiguration = Self.loadPerformanceConfiguration()
    }
    
    // MARK: - 配置加载
    private static func loadDatabaseConfiguration() -> DatabaseConfiguration {
        let userDefaults = UserDefaults.standard
        
        return DatabaseConfiguration(
            useCloudKit: userDefaults.object(forKey: "database.useCloudKit") as? Bool ?? DatabaseConfiguration.default.useCloudKit,
            enableRemoteNotifications: userDefaults.object(forKey: "database.enableRemoteNotifications") as? Bool ?? DatabaseConfiguration.default.enableRemoteNotifications,
            historyTrackingEnabled: userDefaults.object(forKey: "database.historyTrackingEnabled") as? Bool ?? DatabaseConfiguration.default.historyTrackingEnabled,
            batchSize: userDefaults.object(forKey: "database.batchSize") as? Int ?? DatabaseConfiguration.default.batchSize,
            fetchLimit: userDefaults.object(forKey: "database.fetchLimit") as? Int ?? DatabaseConfiguration.default.fetchLimit
        )
    }
    
    private static func loadCloudKitConfiguration() -> CloudKitConfiguration {
        let userDefaults = UserDefaults.standard
        
        return CloudKitConfiguration(
            containerIdentifier: Bundle.main.infoDictionary?["CloudKitContainerIdentifier"] as? String ?? CloudKitConfiguration.default.containerIdentifier,
            enableSync: userDefaults.object(forKey: "cloudkit.enableSync") as? Bool ?? CloudKitConfiguration.default.enableSync,
            syncInterval: userDefaults.object(forKey: "cloudkit.syncInterval") as? TimeInterval ?? CloudKitConfiguration.default.syncInterval,
            retryAttempts: userDefaults.object(forKey: "cloudkit.retryAttempts") as? Int ?? CloudKitConfiguration.default.retryAttempts
        )
    }
    
    private static func loadPerformanceConfiguration() -> PerformanceConfiguration {
        let userDefaults = UserDefaults.standard
        
        // 根据设备类型自动调整性能配置
        let devicePerformanceLevel = PlatformAdapter.devicePerformanceLevel
        let baseConfig = PerformanceConfiguration.default
        
        let maxMemory = userDefaults.object(forKey: "performance.maxMemoryUsage") as? Int ?? {
            switch devicePerformanceLevel {
            case .high: return 300
            case .medium: return 200
            case .low: return 100
            }
        }()
        
        let cachePolicy: CachePolicy = {
            if let policyString = userDefaults.string(forKey: "performance.cachePolicy") {
                switch policyString {
                case "aggressive": return .aggressive
                case "balanced": return .balanced
                case "conservative": return .conservative
                default: return .automatic
                }
            }
            return .automatic
        }()
        
        return PerformanceConfiguration(
            enablePerformanceMonitoring: userDefaults.object(forKey: "performance.enableMonitoring") as? Bool ?? baseConfig.enablePerformanceMonitoring,
            maxMemoryUsage: maxMemory,
            imageCompressionQuality: userDefaults.object(forKey: "performance.imageCompressionQuality") as? Float ?? baseConfig.imageCompressionQuality,
            thumbnailSize: baseConfig.thumbnailSize,
            cachePolicy: cachePolicy
        )
    }
    
    // MARK: - 配置保存
    func saveConfiguration() {
        let userDefaults = UserDefaults.standard
        
        // 保存数据库配置
        userDefaults.set(databaseConfiguration.useCloudKit, forKey: "database.useCloudKit")
        userDefaults.set(databaseConfiguration.enableRemoteNotifications, forKey: "database.enableRemoteNotifications")
        userDefaults.set(databaseConfiguration.historyTrackingEnabled, forKey: "database.historyTrackingEnabled")
        userDefaults.set(databaseConfiguration.batchSize, forKey: "database.batchSize")
        userDefaults.set(databaseConfiguration.fetchLimit, forKey: "database.fetchLimit")
        
        // 保存 CloudKit 配置
        userDefaults.set(cloudKitConfiguration.enableSync, forKey: "cloudkit.enableSync")
        userDefaults.set(cloudKitConfiguration.syncInterval, forKey: "cloudkit.syncInterval")
        userDefaults.set(cloudKitConfiguration.retryAttempts, forKey: "cloudkit.retryAttempts")
        
        // 保存性能配置
        userDefaults.set(performanceConfiguration.enablePerformanceMonitoring, forKey: "performance.enableMonitoring")
        userDefaults.set(performanceConfiguration.maxMemoryUsage, forKey: "performance.maxMemoryUsage")
        userDefaults.set(performanceConfiguration.imageCompressionQuality, forKey: "performance.imageCompressionQuality")
        
        let cachePolicyString = switch performanceConfiguration.cachePolicy {
        case .aggressive: "aggressive"
        case .balanced: "balanced"
        case .conservative: "conservative"
        case .automatic: "automatic"
        }
        userDefaults.set(cachePolicyString, forKey: "performance.cachePolicy")
        
        userDefaults.synchronize()
    }
    
    // MARK: - 配置重置
    func resetToDefaults() {
        databaseConfiguration = DatabaseConfiguration.default
        cloudKitConfiguration = CloudKitConfiguration.default
        performanceConfiguration = PerformanceConfiguration.default
        saveConfiguration()
    }
    
    // MARK: - 环境切换 (仅开发模式)
    func switchEnvironment(to environment: EnvironmentType) {
        guard isDebugMode else { return }
        environmentType = environment
    }
}

// MARK: - SwiftUI 环境键
struct AppConfigurationKey: EnvironmentKey {
    static let defaultValue: AppConfiguration = AppConfiguration.shared
}

extension EnvironmentValues {
    var appConfiguration: AppConfiguration {
        get { self[AppConfigurationKey.self] }
        set { self[AppConfigurationKey.self] = newValue }
    }
}

extension View {
    func appConfiguration(_ configuration: AppConfiguration) -> some View {
        environment(\.appConfiguration, configuration)
    }
}

// MARK: - 配置验证
extension AppConfiguration {
    
    func validateConfiguration() -> [ConfigurationError] {
        var errors: [ConfigurationError] = []
        
        // 验证数据库配置
        if databaseConfiguration.batchSize <= 0 {
            errors.append(.invalidBatchSize)
        }
        
        if databaseConfiguration.fetchLimit <= 0 {
            errors.append(.invalidFetchLimit)
        }
        
        // 验证 CloudKit 配置
        if cloudKitConfiguration.syncInterval < 60 {
            errors.append(.invalidSyncInterval)
        }
        
        if cloudKitConfiguration.retryAttempts < 0 || cloudKitConfiguration.retryAttempts > 10 {
            errors.append(.invalidRetryAttempts)
        }
        
        // 验证性能配置
        if performanceConfiguration.maxMemoryUsage < 50 || performanceConfiguration.maxMemoryUsage > 1000 {
            errors.append(.invalidMemoryLimit)
        }
        
        if performanceConfiguration.imageCompressionQuality < 0.1 || performanceConfiguration.imageCompressionQuality > 1.0 {
            errors.append(.invalidCompressionQuality)
        }
        
        return errors
    }
}

enum ConfigurationError: LocalizedError {
    case invalidBatchSize
    case invalidFetchLimit
    case invalidSyncInterval
    case invalidRetryAttempts
    case invalidMemoryLimit
    case invalidCompressionQuality
    
    var errorDescription: String? {
        switch self {
        case .invalidBatchSize:
            return "批处理大小必须大于 0"
        case .invalidFetchLimit:
            return "获取限制必须大于 0"
        case .invalidSyncInterval:
            return "同步间隔不能少于 60 秒"
        case .invalidRetryAttempts:
            return "重试次数必须在 0-10 之间"
        case .invalidMemoryLimit:
            return "内存限制必须在 50-1000 MB 之间"
        case .invalidCompressionQuality:
            return "图片压缩质量必须在 0.1-1.0 之间"
        }
    }
}