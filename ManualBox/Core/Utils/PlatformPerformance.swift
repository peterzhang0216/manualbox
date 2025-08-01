import SwiftUI
import Combine

// MARK: - 性能指标类型
enum MetricType: String, CaseIterable {
    case all = "all"
    case timing = "timing"
    case counter = "counter"
    case gauge = "gauge"
}

// MARK: - 平台性能管理器
class PlatformPerformanceManager: ObservableObject {
    static let shared = PlatformPerformanceManager()
    
    @Published var memoryUsage: Double = 0
    @Published var isLowMemoryMode: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var metrics: [String: Double] = [:]
    
    init() {
        setupMemoryMonitoring()
    }
    
    // MARK: - 性能指标记录方法
    
    func recordDatabaseOperation(operation: String, entityName: String, duration: TimeInterval) {
        let metricName = "db.\(operation).\(entityName)"
        recordMetric(name: metricName, value: duration, type: .timing)
    }
    
    func recordMetric(name: String, value: Double, type: MetricType) {
        DispatchQueue.main.async {
            let key = "\(name).\(type.rawValue)"
            self.metrics[key] = value
            
            // 如果是性能关键指标，进行日志记录
            if type == .timing && value > 1.0 {
                print("⚠️ 性能警告: \(name) 耗时 \(String(format: "%.2f", value))秒")
            }
        }
    }
    
    func getMetric(name: String, type: MetricType) -> Double? {
        let key = "\(name).\(type.rawValue)"
        return metrics[key]
    }
    
    private func setupMemoryMonitoring() {
        #if os(iOS)
        // iOS 内存监控
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleLowMemory()
            }
            .store(in: &cancellables)
        
        // 定期检查内存使用情况
        Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMemoryUsage()
            }
            .store(in: &cancellables)
        #else
        // macOS 内存监控
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMemoryUsage()
            }
            .store(in: &cancellables)
        #endif
    }
    
    private func updateMemoryUsage() {
        let usage = getMemoryUsage()
        DispatchQueue.main.async {
            self.memoryUsage = usage
            
            #if os(iOS)
            self.isLowMemoryMode = usage > 0.8 // 80% 以上启用低内存模式
            #else
            self.isLowMemoryMode = usage > 0.9 // macOS 可以使用更多内存
            #endif
        }
    }
    
    private func getMemoryUsage() -> Double {
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
            let usedMemory = Double(info.resident_size)
            
            #if os(iOS)
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            #else
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            #endif
            
            return usedMemory / totalMemory
        }
        
        return 0
    }
    
    private func handleLowMemory() {
        DispatchQueue.main.async {
            self.isLowMemoryMode = true
            // 发送内存警告通知
            NotificationCenter.default.post(name: .lowMemoryWarning, object: nil)
        }
    }
}

// MARK: - 平台特定的图像缓存
class PlatformImageCache {
    static let shared = PlatformImageCache()
    
    private let cache = NSCache<NSString, PlatformImage>()
    private let maxCacheSize: Int
    
    init() {
        #if os(macOS)
        maxCacheSize = 200 // macOS 可以缓存更多图片
        #else
        maxCacheSize = 50 // iOS 限制缓存大小
        #endif
        
        cache.countLimit = maxCacheSize
        
        // 监听内存警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: .lowMemoryWarning,
            object: nil
        )
    }
    
    func setImage(_ image: PlatformImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func image(forKey key: String) -> PlatformImage? {
        return cache.object(forKey: key as NSString)
    }
    
    @objc private func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - 平台特定的动画配置
struct PlatformAnimations {
    
    static var defaultSpring: Animation {
        #if os(macOS)
        return .spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)
        #else
        return .spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)
        #endif
    }
    
    static var quickTransition: Animation {
        #if os(macOS)
        return .easeInOut(duration: 0.2)
        #else
        return .easeInOut(duration: 0.25)
        #endif
    }
    
    static var slowTransition: Animation {
        #if os(macOS)
        return .easeInOut(duration: 0.4)
        #else
        return .easeInOut(duration: 0.5)
        #endif
    }
    
    static func reduceMotion() -> Animation? {
        #if os(iOS)
        if UIAccessibility.isReduceMotionEnabled {
            return nil
        }
        #endif
        return defaultSpring
    }
}

extension Notification.Name {
    static let lowMemoryWarning = Notification.Name("LowMemoryWarning")
}

// MARK: - 性能感知的视图修饰器
struct PerformanceAwareModifier: ViewModifier {
    @StateObject private var performanceManager = PlatformPerformanceManager.shared
    
    func body(content: Content) -> some View {
        content
            .animation(
                performanceManager.isLowMemoryMode ? nil : PlatformAnimations.defaultSpring,
                value: performanceManager.isLowMemoryMode
            )
            .background(
                performanceManager.isLowMemoryMode ? 
                Color.clear : PlatformAdapter.backgroundColor
            )
    }
}

extension View {
    func performanceAware() -> some View {
        modifier(PerformanceAwareModifier())
    }
}