import Foundation
import CoreData
import SwiftUI

// MARK: - 说明书版本管理服务
class ManualVersionService: ObservableObject {
    static let shared = ManualVersionService()
    
    @Published var versions: [ManualVersion] = []
    
    private init() {
        loadVersions()
    }
    
    // MARK: - 版本管理
    
    /// 创建新版本
    func createVersion(
        for manualId: UUID,
        fileData: Data,
        fileName: String,
        fileType: String,
        content: String? = nil,
        versionNote: String? = nil,
        changeType: VersionChangeType = .update
    ) async {
        let version = ManualVersion(
            id: UUID(),
            manualId: manualId,
            versionNumber: await getNextVersionNumber(for: manualId),
            fileData: fileData,
            fileName: fileName,
            fileType: fileType,
            content: content,
            versionNote: versionNote,
            changeType: changeType,
            createdAt: Date(),
            fileSize: Int64(fileData.count)
        )
        
        await MainActor.run {
            versions.append(version)
        }
        
        await saveVersions()
    }
    
    /// 获取指定说明书的所有版本
    func getVersions(for manualId: UUID) -> [ManualVersion] {
        return versions.filter { $0.manualId == manualId }
            .sorted { $0.versionNumber > $1.versionNumber }
    }
    
    /// 获取最新版本
    func getLatestVersion(for manualId: UUID) -> ManualVersion? {
        return getVersions(for: manualId).first
    }
    
    /// 获取指定版本
    func getVersion(id: UUID) -> ManualVersion? {
        return versions.first { $0.id == id }
    }
    
    /// 删除版本
    func deleteVersion(_ version: ManualVersion) async {
        await MainActor.run {
            versions.removeAll { $0.id == version.id }
        }
        
        await saveVersions()
    }
    
    /// 恢复到指定版本
    func restoreToVersion(_ version: ManualVersion) async -> Bool {
        // 创建新版本作为恢复点
        await createVersion(
            for: version.manualId,
            fileData: version.fileData,
            fileName: version.fileName,
            fileType: version.fileType,
            content: version.content,
            versionNote: "恢复到版本 \(version.versionNumber)",
            changeType: .restore
        )
        
        return true
    }
    
    // MARK: - 版本比较
    
    /// 比较两个版本的差异
    func compareVersions(_ version1: ManualVersion, _ version2: ManualVersion) -> VersionComparison {
        var changes: [VersionChange] = []
        
        // 比较文件名
        if version1.fileName != version2.fileName {
            changes.append(VersionChange(
                type: .fileName,
                oldValue: version1.fileName,
                newValue: version2.fileName
            ))
        }
        
        // 比较文件大小
        if version1.fileSize != version2.fileSize {
            changes.append(VersionChange(
                type: .fileSize,
                oldValue: "\(version1.fileSize) bytes",
                newValue: "\(version2.fileSize) bytes"
            ))
        }
        
        // 比较内容（如果有OCR内容）
        if let content1 = version1.content, let content2 = version2.content {
            if content1 != content2 {
                changes.append(VersionChange(
                    type: .content,
                    oldValue: "内容已更改",
                    newValue: "内容已更改"
                ))
            }
        }
        
        return VersionComparison(
            version1: version1,
            version2: version2,
            changes: changes,
            similarity: calculateSimilarity(version1, version2)
        )
    }
    
    // MARK: - 版本统计
    
    /// 获取版本统计信息
    func getVersionStatistics(for manualId: UUID) -> VersionStatistics {
        let manualVersions = getVersions(for: manualId)
        
        let totalVersions = manualVersions.count
        let totalSize = manualVersions.reduce(0) { $0 + $1.fileSize }
        let changeTypes = Dictionary(grouping: manualVersions, by: { $0.changeType })
            .mapValues { $0.count }
        
        let oldestVersion = manualVersions.min { $0.createdAt < $1.createdAt }
        let newestVersion = manualVersions.max { $0.createdAt < $1.createdAt }
        
        return VersionStatistics(
            totalVersions: totalVersions,
            totalSize: totalSize,
            changeTypeCounts: changeTypes,
            oldestVersion: oldestVersion,
            newestVersion: newestVersion,
            averageSize: totalVersions > 0 ? totalSize / Int64(totalVersions) : 0
        )
    }
    
    // MARK: - 版本清理
    
    /// 清理旧版本（保留指定数量的最新版本）
    func cleanupOldVersions(for manualId: UUID, keepCount: Int = 10) async {
        let manualVersions = getVersions(for: manualId)
        
        if manualVersions.count > keepCount {
            let versionsToDelete = Array(manualVersions.dropFirst(keepCount))
            
            await MainActor.run {
                for version in versionsToDelete {
                    versions.removeAll { $0.id == version.id }
                }
            }
            
            await saveVersions()
        }
    }
    
    /// 清理所有版本历史
    func clearAllVersions() async {
        await MainActor.run {
            versions.removeAll()
        }
        
        await saveVersions()
    }
    
    // MARK: - 导入导出
    
    /// 导出版本历史
    func exportVersionHistory(for manualId: UUID) -> Data? {
        let manualVersions = getVersions(for: manualId)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(manualVersions)
    }
    
    /// 导入版本历史
    func importVersionHistory(from data: Data) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let importedVersions = try decoder.decode([ManualVersion].self, from: data)
        
        await MainActor.run {
            versions.append(contentsOf: importedVersions)
        }
        
        await saveVersions()
    }
    
    // MARK: - 私有方法
    
    private func getNextVersionNumber(for manualId: UUID) async -> Int {
        let manualVersions = getVersions(for: manualId)
        let maxVersion = manualVersions.max { $0.versionNumber < $1.versionNumber }?.versionNumber ?? 0
        return maxVersion + 1
    }
    
    private func calculateSimilarity(_ version1: ManualVersion, _ version2: ManualVersion) -> Double {
        // 简单的相似度计算
        var similarity = 1.0
        
        // 文件名相似度
        if version1.fileName != version2.fileName {
            similarity -= 0.1
        }
        
        // 文件大小相似度
        let sizeDiff = abs(version1.fileSize - version2.fileSize)
        let maxSize = max(version1.fileSize, version2.fileSize)
        if maxSize > 0 {
            similarity -= Double(sizeDiff) / Double(maxSize) * 0.3
        }
        
        // 内容相似度（如果有）
        if let content1 = version1.content, let content2 = version2.content {
            if content1 != content2 {
                similarity -= 0.2
            }
        }
        
        return max(0.0, similarity)
    }
    
    private func loadVersions() {
        if let data = UserDefaults.standard.data(forKey: "ManualVersions"),
           let loadedVersions = try? JSONDecoder().decode([ManualVersion].self, from: data) {
            versions = loadedVersions
        }
    }
    
    private func saveVersions() async {
        if let data = try? JSONEncoder().encode(versions) {
            UserDefaults.standard.set(data, forKey: "ManualVersions")
        }
    }
}

// MARK: - 版本数据模型

/// 说明书版本
struct ManualVersion: Codable, Identifiable {
    let id: UUID
    let manualId: UUID
    let versionNumber: Int
    let fileData: Data
    let fileName: String
    let fileType: String
    let content: String?
    let versionNote: String?
    let changeType: VersionChangeType
    let createdAt: Date
    let fileSize: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var versionString: String {
        return "v\(versionNumber)"
    }
}

/// 版本变更类型
enum VersionChangeType: String, Codable, CaseIterable {
    case initial = "initial"
    case update = "update"
    case restore = "restore"
    case `import` = "import"
    case ocr = "ocr"

    var displayName: String {
        switch self {
        case .initial:
            return "初始版本"
        case .update:
            return "更新"
        case .restore:
            return "恢复"
        case .`import`:
            return "导入"
        case .ocr:
            return "OCR处理"
        }
    }

    var icon: String {
        switch self {
        case .initial:
            return "plus.circle"
        case .update:
            return "arrow.up.circle"
        case .restore:
            return "arrow.counterclockwise.circle"
        case .`import`:
            return "square.and.arrow.down"
        case .ocr:
            return "doc.text.viewfinder"
        }
    }

    var color: Color {
        switch self {
        case .initial:
            return .green
        case .update:
            return .blue
        case .restore:
            return .orange
        case .import:
            return .purple
        case .ocr:
            return .indigo
        }
    }
}

/// 版本比较结果
struct VersionComparison {
    let version1: ManualVersion
    let version2: ManualVersion
    let changes: [VersionChange]
    let similarity: Double

    var hasChanges: Bool {
        return !changes.isEmpty
    }

    var similarityPercentage: String {
        return String(format: "%.1f%%", similarity * 100)
    }
}

/// 版本变更项
struct VersionChange {
    let type: VersionChangeField
    let oldValue: String
    let newValue: String
}

/// 版本变更字段类型
enum VersionChangeField: String, CaseIterable {
    case fileName = "fileName"
    case fileSize = "fileSize"
    case content = "content"

    var displayName: String {
        switch self {
        case .fileName:
            return "文件名"
        case .fileSize:
            return "文件大小"
        case .content:
            return "内容"
        }
    }
}

/// 版本统计信息
struct VersionStatistics {
    let totalVersions: Int
    let totalSize: Int64
    let changeTypeCounts: [VersionChangeType: Int]
    let oldestVersion: ManualVersion?
    let newestVersion: ManualVersion?
    let averageSize: Int64

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var formattedAverageSize: String {
        ByteCountFormatter.string(fromByteCount: averageSize, countStyle: .file)
    }
}
