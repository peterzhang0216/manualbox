import Foundation
import SwiftUI
import Combine

// MARK: - 图片缓存配置
struct ImageCacheConfiguration {
    let memoryLimit: Int // MB
    let diskLimit: Int // MB
    let maxConcurrentOperations: Int
    let compressionQuality: CGFloat
    let thumbnailSize: CGSize
    let enableDiskCache: Bool
    let cacheExpirationTime: TimeInterval
    
    static let `default` = ImageCacheConfiguration(
        memoryLimit: 100,
        diskLimit: 500,
        maxConcurrentOperations: 4,
        compressionQuality: 0.8,
        thumbnailSize: CGSize(width: 200, height: 200),
        enableDiskCache: true,
        cacheExpirationTime: 7 * 24 * 60 * 60 // 7天
    )
}

// MARK: - 图片处理选项
struct ImageProcessingOptions {
    let targetSize: CGSize?
    let compressionQuality: CGFloat
    let generateThumbnail: Bool
    let preserveAspectRatio: Bool
    
    static let `default` = ImageProcessingOptions(
        targetSize: nil,
        compressionQuality: 0.8,
        generateThumbnail: false,
        preserveAspectRatio: true
    )
}

// MARK: - 图片缓存条目
private class ImageCacheEntry {
    let image: PlatformImage
    let data: Data?
    let thumbnail: PlatformImage?
    let createdAt: Date
    let lastAccessedAt: Date
    let size: Int
    
    init(image: PlatformImage, data: Data? = nil, thumbnail: PlatformImage? = nil) {
        self.image = image
        self.data = data
        self.thumbnail = thumbnail
        self.createdAt = Date()
        self.lastAccessedAt = Date()
        self.size = data?.count ?? 0
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > 7 * 24 * 60 * 60 // 7天
    }
}

// MARK: - 优化的图片服务
@MainActor
class OptimizedImageService: ObservableObject {
    static let shared = OptimizedImageService()
    
    private let configuration: ImageCacheConfiguration
    private let memoryCache = NSCache<NSString, ImageCacheEntry>()
    private let diskCacheURL: URL
    private let operationQueue: OperationQueue
    private let compressionService: ImageCompressionService
    
    // 性能监控
    private let performanceMonitor: PlatformPerformanceManager?
    
    // 内存压力监控
    @Published var isLowMemoryMode = false
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    init(configuration: ImageCacheConfiguration = .default) {
        self.configuration = configuration
        self.compressionService = ImageCompressionService()
        self.performanceMonitor = ServiceContainer.shared.resolve(PlatformPerformanceManager.self)
        
        // 设置操作队列
        self.operationQueue = OperationQueue()
        self.operationQueue.maxConcurrentOperationCount = configuration.maxConcurrentOperations
        self.operationQueue.qualityOfService = .userInitiated
        
        // 设置磁盘缓存路径
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskCacheURL = cacheDir.appendingPathComponent("ImageCache")
        
        setupCache()
        setupMemoryPressureMonitoring()
        createDiskCacheDirectory()
    }
    
    // MARK: - 图片加载方法
    
    /// 异步加载图片
    func loadImage(from url: URL, options: ImageProcessingOptions = .default) async -> Result<PlatformImage, Error> {
        let startTime = CFAbsoluteTimeGetCurrent()
        let cacheKey = generateCacheKey(from: url)
        
        // 检查内存缓存
        if let cachedEntry = memoryCache.object(forKey: cacheKey as NSString) {
            recordPerformanceMetric(operation: "load_memory_cache", duration: CFAbsoluteTimeGetCurrent() - startTime)
            return .success(cachedEntry.image)
        }
        
        // 检查磁盘缓存
        if configuration.enableDiskCache {
            if let cachedImage = await loadFromDiskCache(cacheKey: cacheKey) {
                // 将磁盘缓存的图片加载到内存缓存
                let entry = ImageCacheEntry(image: cachedImage)
                memoryCache.setObject(entry, forKey: cacheKey as NSString)
                
                recordPerformanceMetric(operation: "load_disk_cache", duration: CFAbsoluteTimeGetCurrent() - startTime)
                return .success(cachedImage)
            }
        }
        
        // 从网络或文件系统加载
        return await loadImageFromSource(url: url, cacheKey: cacheKey, options: options, startTime: startTime)
    }
    
    /// 加载并处理图片数据
    func processImageData(_ data: Data, options: ImageProcessingOptions = .default) async -> Result<ProcessedImageResult, Error> {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            guard let originalImage = PlatformImage(data: data) else {
                return .failure(ImageProcessingError.invalidImageData)
            }

            var processedImage = originalImage
            var processedData = data
            var thumbnail: PlatformImage?

            // 调整大小
            if let targetSize = options.targetSize {
                processedImage = resizeImage(originalImage, to: targetSize, preserveAspectRatio: options.preserveAspectRatio)
            }

            // 压缩图片
            if options.compressionQuality < 1.0 {
                processedData = try await compressionService.compressImage(
                    data: await imageToData(processedImage),
                    quality: Float(options.compressionQuality)
                )
                processedImage = PlatformImage(data: processedData) ?? processedImage
            }

            // 生成缩略图
            if options.generateThumbnail {
                thumbnail = generateThumbnail(from: processedImage)
            }

            let result = ProcessedImageResult(
                originalImage: originalImage,
                processedImage: processedImage,
                processedData: processedData,
                thumbnail: thumbnail,
                originalSize: data.count,
                processedSize: processedData.count
            )

            let duration = CFAbsoluteTimeGetCurrent() - startTime
            recordPerformanceMetric(operation: "process_image", duration: duration)

            return .success(result)
        } catch {
            return .failure(error)
        }
    }
    
    /// 预加载图片
    func preloadImages(urls: [URL]) {
        Task {
            for url in urls {
                _ = await loadImage(from: url)
            }
        }
    }
    
    // MARK: - 缓存管理
    
    /// 清理过期缓存
    func cleanupExpiredCache() async {
        // 清理内存缓存中的过期条目
        // NSCache 不提供 allKeys 方法，我们使用不同的策略
        // 简单地清理所有缓存，让系统重新加载
        memoryCache.removeAllObjects()

        // 清理磁盘缓存
        if configuration.enableDiskCache {
            await cleanupDiskCache()
        }
    }
    
    /// 获取缓存统计信息
    func getCacheStatistics() -> ImageCacheStatistics {
        // NSCache 不提供直接获取条目数量的方法
        // 我们使用估算值或其他指标
        let memoryCount = 0 // NSCache 不支持获取条目数量
        let diskSize = getDiskCacheSize()

        return ImageCacheStatistics(
            memoryCount: memoryCount,
            diskSize: diskSize,
            memoryLimit: configuration.memoryLimit * 1024 * 1024,
            diskLimit: configuration.diskLimit * 1024 * 1024
        )
    }
    
    /// 清空所有缓存
    func clearAllCache() {
        memoryCache.removeAllObjects()
        
        if configuration.enableDiskCache {
            try? FileManager.default.removeItem(at: diskCacheURL)
            createDiskCacheDirectory()
        }
    }
    
    // MARK: - 私有方法
    
    private func setupCache() {
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = configuration.memoryLimit * 1024 * 1024
        
        // 监听内存警告
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        #else
        NotificationCenter.default.addObserver(
            forName: .NSApplicationDidReceiveMemoryWarning,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        #endif
    }
    
    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        memoryPressureSource?.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.handleMemoryPressure()
            }
        }

        memoryPressureSource?.resume()
    }
    
    private func handleMemoryWarning() {
        isLowMemoryMode = true

        // 清理内存缓存
        memoryCache.removeAllObjects()

        // 延迟恢复正常模式
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            self.isLowMemoryMode = false
        }
    }
    
    private func handleMemoryPressure() {
        handleMemoryWarning()
    }
    
    private func createDiskCacheDirectory() {
        try? FileManager.default.createDirectory(
            at: diskCacheURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    private func generateCacheKey(from url: URL) -> String {
        return url.absoluteString.data(using: .utf8)?.base64EncodedString() ?? url.lastPathComponent
    }
    
    private func loadFromDiskCache(cacheKey: String) async -> PlatformImage? {
        let fileURL = diskCacheURL.appendingPathComponent(cacheKey)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return PlatformImage(data: data)
        } catch {
            return nil
        }
    }
    
    private func saveToDiskCache(image: PlatformImage, cacheKey: String) {
        guard configuration.enableDiskCache else { return }

        Task {
            let fileURL = diskCacheURL.appendingPathComponent(cacheKey)
            let imageData = await imageToData(image)

            try? imageData.write(to: fileURL)
        }
    }
    
    private func loadImageFromSource(
        url: URL,
        cacheKey: String,
        options: ImageProcessingOptions,
        startTime: CFAbsoluteTime
    ) async -> Result<PlatformImage, Error> {
        do {
            let data: Data
            
            if url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                let (downloadedData, _) = try await URLSession.shared.data(from: url)
                data = downloadedData
            }
            
            let processResult = await processImageData(data, options: options)
            
            switch processResult {
            case .success(let result):
                // 缓存处理后的图片
                let entry = ImageCacheEntry(
                    image: result.processedImage,
                    data: result.processedData,
                    thumbnail: result.thumbnail
                )
                memoryCache.setObject(entry, forKey: cacheKey as NSString)
                
                // 保存到磁盘缓存
                saveToDiskCache(image: result.processedImage, cacheKey: cacheKey)
                
                recordPerformanceMetric(operation: "load_source", duration: CFAbsoluteTimeGetCurrent() - startTime)
                return .success(result.processedImage)
                
            case .failure(let error):
                return .failure(error)
            }
        } catch {
            return .failure(error)
        }
    }
    
    private func resizeImage(_ image: PlatformImage, to targetSize: CGSize, preserveAspectRatio: Bool) -> PlatformImage {
        let size = preserveAspectRatio ? calculateAspectFitSize(imageSize: image.size, targetSize: targetSize) : targetSize
        
        #if os(macOS)
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        resizedImage.unlockFocus()
        return resizedImage
        #else
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resizedImage
        #endif
    }
    
    private func generateThumbnail(from image: PlatformImage) -> PlatformImage {
        return resizeImage(image, to: configuration.thumbnailSize, preserveAspectRatio: true)
    }
    
    private func calculateAspectFitSize(imageSize: CGSize, targetSize: CGSize) -> CGSize {
        let aspectRatio = imageSize.width / imageSize.height
        let targetAspectRatio = targetSize.width / targetSize.height
        
        if aspectRatio > targetAspectRatio {
            return CGSize(width: targetSize.width, height: targetSize.width / aspectRatio)
        } else {
            return CGSize(width: targetSize.height * aspectRatio, height: targetSize.height)
        }
    }
    
    private func imageToData(_ image: PlatformImage) async -> Data {
        #if os(macOS)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .jpeg, properties: [:]) else {
            return Data()
        }
        return data
        #else
        return image.jpegData(compressionQuality: configuration.compressionQuality) ?? Data()
        #endif
    }
    
    private func cleanupDiskCache() async {
        await Task.detached {
            guard let enumerator = FileManager.default.enumerator(at: self.diskCacheURL, includingPropertiesForKeys: [.creationDateKey]) else {
                return
            }

            let expirationDate = Date().addingTimeInterval(-self.configuration.cacheExpirationTime)

            while let fileURL = enumerator.nextObject() as? URL {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey])
                    if let creationDate = resourceValues.creationDate,
                       creationDate < expirationDate {
                        try FileManager.default.removeItem(at: fileURL)
                    }
                } catch {
                    // 忽略错误，继续清理其他文件
                }
            }
        }.value
    }
    
    private func getDiskCacheSize() -> Int {
        guard let enumerator = FileManager.default.enumerator(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize = 0

        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += resourceValues.fileSize ?? 0
            } catch {
                // 忽略错误
            }
        }

        return totalSize
    }
    
    private func recordPerformanceMetric(operation: String, duration: TimeInterval) {
        performanceMonitor?.recordMetric(
            name: "image.\(operation)",
            value: duration,
            type: .timing
        )
    }
}

// MARK: - 辅助结构

struct ProcessedImageResult {
    let originalImage: PlatformImage
    let processedImage: PlatformImage
    let processedData: Data
    let thumbnail: PlatformImage?
    let originalSize: Int
    let processedSize: Int
    
    var compressionRatio: Double {
        guard originalSize > 0 else { return 0 }
        return Double(processedSize) / Double(originalSize)
    }
}

struct ImageCacheStatistics {
    let memoryCount: Int
    let diskSize: Int
    let memoryLimit: Int
    let diskLimit: Int
    
    var memoryUsagePercentage: Double {
        guard memoryLimit > 0 else { return 0 }
        return Double(diskSize) / Double(memoryLimit) * 100
    }
    
    var diskUsagePercentage: Double {
        guard diskLimit > 0 else { return 0 }
        return Double(diskSize) / Double(diskLimit) * 100
    }
}

enum ImageProcessingError: Error {
    case invalidImageData
    case compressionFailed
    case resizeFailed
    case cacheWriteFailed
}

// MARK: - 通知扩展
#if os(macOS)
extension Notification.Name {
    static let NSApplicationDidReceiveMemoryWarning = Notification.Name("NSApplicationDidReceiveMemoryWarning")
}
#endif
