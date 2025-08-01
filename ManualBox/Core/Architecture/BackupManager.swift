//
//  BackupManager.swift
//  ManualBox
//
//  Created by AI Assistant on 2025/7/22.
//

import Foundation
import CoreData
import Combine

// MARK: - 备份管理器协议
protocol BackupManager {
    func createBackup() async -> BackupResult
    func restoreBackup(_ backup: Backup) async -> RestoreResult
    func listBackups() -> [Backup]
    func deleteBackup(_ backup: Backup) async -> Bool
    func scheduleAutomaticBackup(interval: TimeInterval) async
    func validateBackup(_ backup: Backup) async -> BackupValidationResult
}

// MARK: - 备份结果
enum BackupResult {
    case success(Backup)
    case failure(BackupError)
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var backup: Backup? {
        if case .success(let backup) = self { return backup }
        return nil
    }
    
    var error: BackupError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

// MARK: - 恢复结果
enum RestoreResult {
    case success(RestoreInfo)
    case failure(RestoreError)
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    struct RestoreInfo {
        let restoredEntities: Int
        let skippedEntities: Int
        let duration: TimeInterval
        let warnings: [String]
    }
}

// MARK: - 备份验证结果
struct BackupValidationResult {
    let isValid: Bool
    let issues: [ValidationIssue]
    let statistics: BackupStatistics
    
    struct ValidationIssue {
        let severity: Severity
        let message: String
        let entityType: String?
        
        enum Severity {
            case warning, error, critical
        }
    }
    
    struct BackupStatistics {
        let totalEntities: Int
        let corruptedEntities: Int
        let missingRelationships: Int
        let dataIntegrityScore: Double
    }
}

// MARK: - 备份信息
struct Backup: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let version: String
    let size: Int64
    let checksum: String
    let description: String?
    let metadata: BackupMetadata
    let filePath: URL
    
    struct BackupMetadata: Codable {
        let appVersion: String
        let coreDataModelVersion: String
        let entityCounts: [String: Int]
        let compressionRatio: Double
        let backupType: BackupType
        let isIncremental: Bool
        let baseBackupId: UUID?
    }
    
    enum BackupType: String, Codable, CaseIterable {
        case full = "full"
        case incremental = "incremental"
        case differential = "differential"
        
        var description: String {
            switch self {
            case .full: return "完整备份"
            case .incremental: return "增量备份"
            case .differential: return "差异备份"
            }
        }
    }
    
    var sizeInMB: Double {
        return Double(size) / 1024 / 1024
    }
    
    var isExpired: Bool {
        let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: createdAt) ?? createdAt
        return Date() > expirationDate
    }
}

// MARK: - 备份错误
enum BackupError: LocalizedError {
    case insufficientSpace
    case accessDenied
    case corruptedData
    case networkUnavailable
    case encryptionFailed
    case compressionFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .insufficientSpace:
            return "存储空间不足"
        case .accessDenied:
            return "访问被拒绝"
        case .corruptedData:
            return "数据损坏"
        case .networkUnavailable:
            return "网络不可用"
        case .encryptionFailed:
            return "加密失败"
        case .compressionFailed:
            return "压缩失败"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - 恢复错误
enum RestoreError: LocalizedError {
    case backupNotFound
    case corruptedBackup
    case incompatibleVersion
    case insufficientSpace
    case accessDenied
    case decryptionFailed
    case decompressionFailed
    case dataConflict
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .backupNotFound:
            return "备份文件未找到"
        case .corruptedBackup:
            return "备份文件损坏"
        case .incompatibleVersion:
            return "备份版本不兼容"
        case .insufficientSpace:
            return "存储空间不足"
        case .accessDenied:
            return "访问被拒绝"
        case .decryptionFailed:
            return "解密失败"
        case .decompressionFailed:
            return "解压失败"
        case .dataConflict:
            return "数据冲突"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - 备份管理器实现
@MainActor
class ManualBoxBackupManager: BackupManager, ObservableObject {
    static let shared = ManualBoxBackupManager()
    
    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var backupProgress: Double = 0.0
    @Published var restoreProgress: Double = 0.0
    @Published var availableBackups: [Backup] = []
    
    private let persistenceController: PersistenceController
    private let performanceMonitor: ManualBoxPerformanceMonitoringService
    private let errorHandler: ManualBoxErrorHandlingService
    private let fileManager = FileManager.default
    
    private var backupTimer: Timer?
    private var automaticBackupInterval: TimeInterval = 24 * 60 * 60 // 24小时
    
    // 备份存储路径
    private lazy var backupDirectory: URL = {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupURL = documentsURL.appendingPathComponent("Backups")
        
        if !fileManager.fileExists(atPath: backupURL.path) {
            try? fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
        }
        
        return backupURL
    }()
    
    private init() {
        self.persistenceController = PersistenceController.shared
        self.performanceMonitor = ManualBoxPerformanceMonitoringService.shared
        self.errorHandler = ManualBoxErrorHandlingService.shared
        
        loadAvailableBackups()
        scheduleAutomaticBackup(interval: automaticBackupInterval)
    }
    
    // MARK: - 公共接口实现
    
    func createBackup() async -> BackupResult {
        let token = performanceMonitor.startOperation("create_backup", category: .database)
        defer { performanceMonitor.endOperation(token) }
        
        isBackingUp = true
        backupProgress = 0.0
        
        do {
            // 检查存储空间
            let availableSpace = try getAvailableStorageSpace()
            let estimatedBackupSize = try await estimateBackupSize()
            
            if availableSpace < estimatedBackupSize * 2 { // 需要2倍空间用于压缩
                return .failure(.insufficientSpace)
            }
            
            backupProgress = 0.1
            
            // 创建备份元数据
            let metadata = try await createBackupMetadata()
            backupProgress = 0.2
            
            // 导出数据
            let exportedData = try await exportCoreData()
            backupProgress = 0.6
            
            // 压缩数据
            let compressedData = try compressData(exportedData)
            backupProgress = 0.8
            
            // 计算校验和
            let checksum = calculateChecksum(compressedData)
            
            // 创建备份文件
            let backupId = UUID()
            let fileName = "backup_\(backupId.uuidString)_\(Date().timeIntervalSince1970).mbbackup"
            let filePath = backupDirectory.appendingPathComponent(fileName)
            
            try compressedData.write(to: filePath)
            
            let backup = Backup(
                id: backupId,
                createdAt: Date(),
                version: "1.0",
                size: Int64(compressedData.count),
                checksum: checksum,
                description: "自动备份",
                metadata: metadata,
                filePath: filePath
            )
            
            // 保存备份信息
            try saveBackupInfo(backup)
            
            backupProgress = 1.0
            isBackingUp = false
            
            // 更新可用备份列表
            loadAvailableBackups()
            
            // 清理过期备份
            await cleanupExpiredBackups()
            
            return .success(backup)
            
        } catch {
            isBackingUp = false
            backupProgress = 0.0
            
            let backupError: BackupError
            if let nsError = error as NSError? {
                switch nsError.code {
                case NSFileWriteFileExistsError:
                    backupError = .accessDenied
                case NSFileWriteVolumeReadOnlyError:
                    backupError = .accessDenied
                default:
                    backupError = .unknown(error)
                }
            } else {
                backupError = .unknown(error)
            }
            
            return .failure(backupError)
        }
    }
    
    func restoreBackup(_ backup: Backup) async -> RestoreResult {
        let token = performanceMonitor.startOperation("restore_backup", category: .database)
        defer { performanceMonitor.endOperation(token) }
        
        isRestoring = true
        restoreProgress = 0.0
        
        do {
            // 验证备份文件
            let validationResult = await validateBackup(backup)
            if !validationResult.isValid {
                let criticalIssues = validationResult.issues.filter { $0.severity == .critical }
                if !criticalIssues.isEmpty {
                    return .failure(.corruptedBackup)
                }
            }
            
            restoreProgress = 0.1
            
            // 读取备份文件
            let backupData = try Data(contentsOf: backup.filePath)
            restoreProgress = 0.2
            
            // 验证校验和
            let calculatedChecksum = calculateChecksum(backupData)
            if calculatedChecksum != backup.checksum {
                return .failure(.corruptedBackup)
            }
            
            // 解压数据
            let decompressedData = try decompressData(backupData)
            restoreProgress = 0.4
            
            // 解析备份数据
            let backupContent = try JSONDecoder().decode(BackupContent.self, from: decompressedData)
            restoreProgress = 0.5
            
            // 创建新的上下文进行恢复
            let backgroundContext = persistenceController.newBackgroundContext()
            
            var restoredCount = 0
            var skippedCount = 0
            var warnings: [String] = []
            
            // 恢复数据
            try await backgroundContext.perform {
                // 恢复分类
                for categoryData in backupContent.categories {
                    if try self.restoreCategory(categoryData, context: backgroundContext) {
                        restoredCount += 1
                    } else {
                        skippedCount += 1
                        warnings.append("跳过分类: \(categoryData.name)")
                    }
                }
                
                self.restoreProgress = 0.6
                
                // 恢复标签
                for tagData in backupContent.tags {
                    if try self.restoreTag(tagData, context: backgroundContext) {
                        restoredCount += 1
                    } else {
                        skippedCount += 1
                        warnings.append("跳过标签: \(tagData.name)")
                    }
                }
                
                self.restoreProgress = 0.7
                
                // 恢复产品
                for productData in backupContent.products {
                    if try self.restoreProduct(productData, context: backgroundContext) {
                        restoredCount += 1
                    } else {
                        skippedCount += 1
                        warnings.append("跳过产品: \(productData.name)")
                    }
                }
                
                self.restoreProgress = 0.9
                
                // 保存上下文
                if backgroundContext.hasChanges {
                    try backgroundContext.save()
                }
            }
            
            restoreProgress = 1.0
            isRestoring = false
            
            let restoreInfo = RestoreResult.RestoreInfo(
                restoredEntities: restoredCount,
                skippedEntities: skippedCount,
                duration: 0, // 可以计算实际持续时间
                warnings: warnings
            )
            
            return .success(restoreInfo)
            
        } catch {
            isRestoring = false
            restoreProgress = 0.0
            
            let restoreError: RestoreError
            if let decodingError = error as? DecodingError {
                restoreError = .corruptedBackup
            } else if let nsError = error as NSError? {
                switch nsError.code {
                case NSFileReadNoSuchFileError:
                    restoreError = .backupNotFound
                case NSFileReadNoPermissionError:
                    restoreError = .accessDenied
                default:
                    restoreError = .unknown(error)
                }
            } else {
                restoreError = .unknown(error)
            }
            
            return .failure(restoreError)
        }
    }
    
    func listBackups() -> [Backup] {
        return availableBackups.sorted { $0.createdAt > $1.createdAt }
    }
    
    func deleteBackup(_ backup: Backup) async -> Bool {
        do {
            // 删除备份文件
            try fileManager.removeItem(at: backup.filePath)
            
            // 删除备份信息文件
            let infoPath = backupDirectory.appendingPathComponent("\(backup.id.uuidString).info")
            try? fileManager.removeItem(at: infoPath)
            
            // 更新可用备份列表
            loadAvailableBackups()
            
            return true
        } catch {
            print("删除备份失败: \(error)")
            return false
        }
    }
    
    func scheduleAutomaticBackup(interval: TimeInterval) async {
        automaticBackupInterval = interval
        
        // 取消现有定时器
        backupTimer?.invalidate()
        
        // 创建新的定时器
        backupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performAutomaticBackup()
            }
        }
    }
    
    func validateBackup(_ backup: Backup) async -> BackupValidationResult {
        var issues: [BackupValidationResult.ValidationIssue] = []
        var statistics = BackupValidationResult.BackupStatistics(
            totalEntities: 0,
            corruptedEntities: 0,
            missingRelationships: 0,
            dataIntegrityScore: 0.0
        )
        
        do {
            // 检查文件是否存在
            if !fileManager.fileExists(atPath: backup.filePath.path) {
                issues.append(BackupValidationResult.ValidationIssue(
                    severity: .critical,
                    message: "备份文件不存在",
                    entityType: nil
                ))
                return BackupValidationResult(isValid: false, issues: issues, statistics: statistics)
            }
            
            // 检查文件大小
            let attributes = try fileManager.attributesOfItem(atPath: backup.filePath.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if fileSize != backup.size {
                issues.append(BackupValidationResult.ValidationIssue(
                    severity: .error,
                    message: "文件大小不匹配",
                    entityType: nil
                ))
            }
            
            // 验证校验和
            let backupData = try Data(contentsOf: backup.filePath)
            let calculatedChecksum = calculateChecksum(backupData)
            
            if calculatedChecksum != backup.checksum {
                issues.append(BackupValidationResult.ValidationIssue(
                    severity: .critical,
                    message: "校验和不匹配，备份可能已损坏",
                    entityType: nil
                ))
            }
            
            // 尝试解压和解析数据
            do {
                let decompressedData = try decompressData(backupData)
                let backupContent = try JSONDecoder().decode(BackupContent.self, from: decompressedData)
                
                statistics.totalEntities = backupContent.categories.count + 
                                         backupContent.tags.count + 
                                         backupContent.products.count
                
                // 计算数据完整性评分
                let totalExpected = backup.metadata.entityCounts.values.reduce(0, +)
                let integrityScore = totalExpected > 0 ? Double(statistics.totalEntities) / Double(totalExpected) : 1.0
                statistics.dataIntegrityScore = min(1.0, integrityScore)
                
            } catch {
                issues.append(BackupValidationResult.ValidationIssue(
                    severity: .critical,
                    message: "无法解析备份内容",
                    entityType: nil
                ))
            }
            
        } catch {
            issues.append(BackupValidationResult.ValidationIssue(
                severity: .critical,
                message: "验证过程中发生错误: \(error.localizedDescription)",
                entityType: nil
            ))
        }
        
        let isValid = !issues.contains { $0.severity == .critical }
        return BackupValidationResult(isValid: isValid, issues: issues, statistics: statistics)
    }
    
    // MARK: - 私有方法
    
    private func loadAvailableBackups() {
        var backups: [Backup] = []
        
        do {
            let backupFiles = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
            
            for file in backupFiles where file.pathExtension == "info" {
                if let backup = loadBackupInfo(from: file) {
                    backups.append(backup)
                }
            }
        } catch {
            print("加载备份列表失败: \(error)")
        }
        
        availableBackups = backups
    }
    
    private func loadBackupInfo(from url: URL) -> Backup? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Backup.self, from: data)
        } catch {
            print("加载备份信息失败: \(error)")
            return nil
        }
    }
    
    private func saveBackupInfo(_ backup: Backup) throws {
        let infoPath = backupDirectory.appendingPathComponent("\(backup.id.uuidString).info")
        let data = try JSONEncoder().encode(backup)
        try data.write(to: infoPath)
    }
    
    private func performAutomaticBackup() async {
        // 检查是否需要备份
        let lastBackup = availableBackups.max { $0.createdAt < $1.createdAt }
        
        if let lastBackup = lastBackup {
            let timeSinceLastBackup = Date().timeIntervalSince(lastBackup.createdAt)
            if timeSinceLastBackup < automaticBackupInterval {
                return // 还不需要备份
            }
        }
        
        let result = await createBackup()
        if case .success(let backup) = result {
            print("自动备份完成: \(backup.id)")
        } else if case .failure(let error) = result {
            print("自动备份失败: \(error.localizedDescription)")
        }
    }
    
    private func cleanupExpiredBackups() async {
        let expiredBackups = availableBackups.filter { $0.isExpired }
        
        for backup in expiredBackups {
            await deleteBackup(backup)
        }
    }
    
    private func getAvailableStorageSpace() throws -> Int64 {
        let attributes = try fileManager.attributesOfFileSystem(forPath: backupDirectory.path)
        return attributes[.systemFreeSize] as? Int64 ?? 0
    }
    
    private func estimateBackupSize() async throws -> Int64 {
        // 估算备份大小的简单实现
        // 实际实现中可以更精确地计算
        return 10 * 1024 * 1024 // 10MB 估算
    }
    
    private func createBackupMetadata() async throws -> Backup.BackupMetadata {
        let context = persistenceController.container.viewContext
        
        var entityCounts: [String: Int] = [:]
        
        // 计算各实体数量
        let entityNames = ["Product", "Category", "Tag", "Order", "Manual", "RepairRecord"]
        for entityName in entityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            let count = try context.count(for: request)
            entityCounts[entityName] = count
        }
        
        return Backup.BackupMetadata(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            coreDataModelVersion: "1.0",
            entityCounts: entityCounts,
            compressionRatio: 0.7, // 估算压缩比
            backupType: .full,
            isIncremental: false,
            baseBackupId: nil
        )
    }
    
    private func exportCoreData() async throws -> Data {
        // 简化的导出实现
        // 实际实现中需要导出所有实体数据
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            // 导出分类
            let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
            let categories = try context.fetch(categoryRequest)
            let categoryData = categories.map { CategoryBackupData(from: $0) }
            
            // 导出标签
            let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            let tags = try context.fetch(tagRequest)
            let tagData = tags.map { TagBackupData(from: $0) }
            
            // 导出产品
            let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
            let products = try context.fetch(productRequest)
            let productData = products.map { ProductBackupData(from: $0) }
            
            let backupContent = BackupContent(
                categories: categoryData,
                tags: tagData,
                products: productData
            )
            
            return try JSONEncoder().encode(backupContent)
        }
    }
    
    private func compressData(_ data: Data) throws -> Data {
        // 使用压缩算法压缩数据
        return try (data as NSData).compressed(using: .lzfse) as Data
    }
    
    private func decompressData(_ data: Data) throws -> Data {
        // 解压数据
        return try (data as NSData).decompressed(using: .lzfse) as Data
    }
    
    private func calculateChecksum(_ data: Data) -> String {
        // 计算SHA-256校验和
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func restoreCategory(_ categoryData: CategoryBackupData, context: NSManagedObjectContext) throws -> Bool {
        // 检查是否已存在
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", categoryData.name)
        
        let existingCategories = try context.fetch(request)
        if !existingCategories.isEmpty {
            return false // 跳过已存在的分类
        }
        
        // 创建新分类
        let category = Category(context: context)
        category.id = categoryData.id
        category.name = categoryData.name
        category.createdAt = categoryData.createdAt
        category.updatedAt = categoryData.updatedAt
        
        return true
    }
    
    private func restoreTag(_ tagData: TagBackupData, context: NSManagedObjectContext) throws -> Bool {
        // 检查是否已存在
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", tagData.name)
        
        let existingTags = try context.fetch(request)
        if !existingTags.isEmpty {
            return false // 跳过已存在的标签
        }
        
        // 创建新标签
        let tag = Tag(context: context)
        tag.id = tagData.id
        tag.name = tagData.name
        tag.createdAt = tagData.createdAt
        tag.updatedAt = tagData.updatedAt
        
        return true
    }
    
    private func restoreProduct(_ productData: ProductBackupData, context: NSManagedObjectContext) throws -> Bool {
        // 检查是否已存在
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@ AND brand ==[cd] %@", 
                                      productData.name, productData.brand ?? "")
        
        let existingProducts = try context.fetch(request)
        if !existingProducts.isEmpty {
            return false // 跳过已存在的产品
        }
        
        // 创建新产品
        let product = Product(context: context)
        product.id = productData.id
        product.name = productData.name
        product.brand = productData.brand
        product.model = productData.model
        product.createdAt = productData.createdAt
        product.updatedAt = productData.updatedAt
        
        return true
    }
    
    deinit {
        backupTimer?.invalidate()
    }
}

// MARK: - 备份内容数据结构
struct BackupContent: Codable {
    let categories: [CategoryBackupData]
    let tags: [TagBackupData]
    let products: [ProductBackupData]
}

struct CategoryBackupData: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    
    init(from category: Category) {
        self.id = category.id ?? UUID()
        self.name = category.name ?? ""
        self.createdAt = category.createdAt ?? Date()
        self.updatedAt = category.updatedAt ?? Date()
    }
}

struct TagBackupData: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    
    init(from tag: Tag) {
        self.id = tag.id ?? UUID()
        self.name = tag.name ?? ""
        self.createdAt = tag.createdAt ?? Date()
        self.updatedAt = tag.updatedAt ?? Date()
    }
}

struct ProductBackupData: Codable {
    let id: UUID
    let name: String
    let brand: String?
    let model: String?
    let createdAt: Date
    let updatedAt: Date
    
    init(from product: Product) {
        self.id = product.id ?? UUID()
        self.name = product.name ?? ""
        self.brand = product.brand
        self.model = product.model
        self.createdAt = product.createdAt ?? Date()
        self.updatedAt = product.updatedAt ?? Date()
    }
}

// MARK: - CommonCrypto 导入
import CommonCrypto