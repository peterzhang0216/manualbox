import Foundation
import CoreData
import SwiftUI

// MARK: - 说明书标注服务
class ManualAnnotationService: ObservableObject {
    static let shared = ManualAnnotationService()
    
    @Published var annotations: [ManualAnnotation] = []
    
    private init() {
        loadAnnotations()
    }
    
    // MARK: - 标注管理
    
    /// 添加标注
    func addAnnotation(
        manualId: UUID,
        text: String,
        range: NSRange,
        type: AnnotationType,
        note: String? = nil,
        color: AnnotationColor = .yellow
    ) async {
        let annotation = ManualAnnotation(
            id: UUID(),
            manualId: manualId,
            text: text,
            range: range,
            type: type,
            note: note,
            color: color,
            createdAt: Date()
        )
        
        await MainActor.run {
            annotations.append(annotation)
        }
        
        await saveAnnotations()
    }
    
    /// 更新标注
    func updateAnnotation(
        _ annotation: ManualAnnotation,
        text: String? = nil,
        note: String? = nil,
        color: AnnotationColor? = nil
    ) async {
        await MainActor.run {
            if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
                if let text = text {
                    annotations[index].text = text
                }
                if let note = note {
                    annotations[index].note = note
                }
                if let color = color {
                    annotations[index].color = color
                }
                annotations[index].updatedAt = Date()
            }
        }
        
        await saveAnnotations()
    }
    
    /// 删除标注
    func deleteAnnotation(_ annotation: ManualAnnotation) async {
        await MainActor.run {
            annotations.removeAll { $0.id == annotation.id }
        }
        
        await saveAnnotations()
    }
    
    /// 获取说明书的标注
    func getAnnotations(for manualId: UUID) -> [ManualAnnotation] {
        return annotations.filter { $0.manualId == manualId }
    }
    
    /// 获取标注的文本范围
    func getAnnotatedTextRanges(for manualId: UUID) -> [NSRange] {
        return getAnnotations(for: manualId).map { $0.range }
    }
    
    // MARK: - 标注搜索
    
    /// 搜索标注
    func searchAnnotations(query: String) -> [ManualAnnotation] {
        let lowercasedQuery = query.lowercased()
        return annotations.filter { annotation in
            annotation.text.lowercased().contains(lowercasedQuery) ||
            (annotation.note?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    /// 按类型过滤标注
    func filterAnnotations(by type: AnnotationType) -> [ManualAnnotation] {
        return annotations.filter { $0.type == type }
    }
    
    /// 按颜色过滤标注
    func filterAnnotations(by color: AnnotationColor) -> [ManualAnnotation] {
        return annotations.filter { $0.color == color }
    }
    
    // MARK: - 标注统计
    
    /// 获取标注统计
    func getAnnotationStatistics() -> AnnotationStatistics {
        let totalAnnotations = annotations.count
        let typeCounts = Dictionary(grouping: annotations, by: { $0.type })
            .mapValues { $0.count }
        let colorCounts = Dictionary(grouping: annotations, by: { $0.color })
            .mapValues { $0.count }
        
        return AnnotationStatistics(
            totalAnnotations: totalAnnotations,
            typeCounts: typeCounts,
            colorCounts: colorCounts,
            recentAnnotations: Array(annotations.suffix(10))
        )
    }
    
    // MARK: - 标注导出
    
    /// 导出标注为文本
    func exportAnnotationsAsText(for manualId: UUID) -> String {
        let manualAnnotations = getAnnotations(for: manualId)
        var exportText = "说明书标注导出\n"
        exportText += "=" * 50 + "\n\n"
        
        for annotation in manualAnnotations.sorted(by: { $0.createdAt < $1.createdAt }) {
            exportText += "标注文本: \(annotation.text)\n"
            exportText += "类型: \(annotation.type.displayName)\n"
            exportText += "颜色: \(annotation.color.displayName)\n"
            if let note = annotation.note {
                exportText += "笔记: \(note)\n"
            }
            exportText += "创建时间: \(formatDate(annotation.createdAt))\n"
            exportText += "-" * 30 + "\n\n"
        }
        
        return exportText
    }
    
    /// 导出标注为JSON
    func exportAnnotationsAsJSON(for manualId: UUID) -> Data? {
        let manualAnnotations = getAnnotations(for: manualId)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(manualAnnotations)
    }
    
    // MARK: - 标注导入
    
    /// 从JSON导入标注
    func importAnnotations(from data: Data) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let importedAnnotations = try decoder.decode([ManualAnnotation].self, from: data)
        
        await MainActor.run {
            annotations.append(contentsOf: importedAnnotations)
        }
        
        await saveAnnotations()
    }
    
    // MARK: - 标注同步
    
    /// 同步标注到CloudKit
    func syncAnnotations() async {
        // 这里可以实现CloudKit同步逻辑
        print("标注同步功能待实现")
    }
    
    // MARK: - 私有方法
    
    /// 保存标注
    private func saveAnnotations() async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(annotations) {
            let url = getAnnotationsFileURL()
            try? data.write(to: url)
        }
    }
    
    /// 加载标注
    private func loadAnnotations() {
        let url = getAnnotationsFileURL()
        if let data = try? Data(contentsOf: url),
           let loadedAnnotations = try? JSONDecoder().decode([ManualAnnotation].self, from: data) {
            annotations = loadedAnnotations
        }
    }
    
    /// 获取标注文件URL
    private func getAnnotationsFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("manual_annotations.json")
    }
    
    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 标注模型
struct ManualAnnotation: Codable, Identifiable {
    let id: UUID
    let manualId: UUID
    var text: String
    let range: NSRange
    let type: AnnotationType
    var note: String?
    var color: AnnotationColor
    let createdAt: Date
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, manualId, text, range, type, note, color, createdAt, updatedAt
    }
    
    init(id: UUID, manualId: UUID, text: String, range: NSRange, type: AnnotationType, note: String?, color: AnnotationColor, createdAt: Date) {
        self.id = id
        self.manualId = manualId
        self.text = text
        self.range = range
        self.type = type
        self.note = note
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        manualId = try container.decode(UUID.self, forKey: .manualId)
        text = try container.decode(String.self, forKey: .text)
        
        // 解码NSRange
        let rangeData = try container.decode(Data.self, forKey: .range)
        range = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSValue.self, from: rangeData)?.rangeValue ?? NSRange()
        
        type = try container.decode(AnnotationType.self, forKey: .type)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        color = try container.decode(AnnotationColor.self, forKey: .color)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(manualId, forKey: .manualId)
        try container.encode(text, forKey: .text)
        
        // 编码NSRange
        let rangeData = try NSKeyedArchiver.archivedData(withRootObject: NSValue(range: range), requiringSecureCoding: true)
        try container.encode(rangeData, forKey: .range)
        
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(color, forKey: .color)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - 标注类型
enum AnnotationType: String, Codable, CaseIterable {
    case highlight = "highlight"
    case underline = "underline"
    case note = "note"
    case bookmark = "bookmark"
    case important = "important"
    
    var displayName: String {
        switch self {
        case .highlight:
            return "高亮"
        case .underline:
            return "下划线"
        case .note:
            return "笔记"
        case .bookmark:
            return "书签"
        case .important:
            return "重要"
        }
    }
    
    var icon: String {
        switch self {
        case .highlight:
            return "highlighter"
        case .underline:
            return "underline"
        case .note:
            return "note.text"
        case .bookmark:
            return "bookmark"
        case .important:
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - 标注颜色
enum AnnotationColor: String, Codable, CaseIterable {
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case red = "red"
    case purple = "purple"
    case orange = "orange"
    
    var displayName: String {
        switch self {
        case .yellow:
            return "黄色"
        case .green:
            return "绿色"
        case .blue:
            return "蓝色"
        case .red:
            return "红色"
        case .purple:
            return "紫色"
        case .orange:
            return "橙色"
        }
    }
    
    var color: Color {
        switch self {
        case .yellow:
            return .yellow
        case .green:
            return .green
        case .blue:
            return .blue
        case .red:
            return .red
        case .purple:
            return .purple
        case .orange:
            return .orange
        }
    }
}

// MARK: - 标注统计
struct AnnotationStatistics {
    let totalAnnotations: Int
    let typeCounts: [AnnotationType: Int]
    let colorCounts: [AnnotationColor: Int]
    let recentAnnotations: [ManualAnnotation]
}

// MARK: - 字符串扩展
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
} 