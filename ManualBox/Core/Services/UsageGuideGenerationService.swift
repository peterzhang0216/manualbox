//
//  UsageGuideGenerationService.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import Foundation
import CoreData
import NaturalLanguage
import Combine

// MARK: - 使用指南生成服务
@MainActor
class UsageGuideGenerationService: ObservableObject {
    static let shared = UsageGuideGenerationService()
    
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0
    @Published var generatedGuides: [ProductUsageGuide] = []
    @Published var lastError: GuideGenerationError?
    
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }
    
    // MARK: - 主要生成方法
    
    /// 为产品生成使用指南
    func generateUsageGuide(for product: Product) async throws -> ProductUsageGuide {
        isGenerating = true
        generationProgress = 0
        
        defer {
            isGenerating = false
            generationProgress = 0
        }
        
        do {
            // 步骤1: 收集产品信息
            generationProgress = 0.1
            let productInfo = collectProductInformation(product)
            
            // 步骤2: 分析说明书内容
            generationProgress = 0.3
            let manualAnalysis = try await analyzeManualContent(product.productManuals)
            
            // 步骤3: 提取关键信息
            generationProgress = 0.5
            let keyInformation = extractKeyInformation(from: manualAnalysis)
            
            // 步骤4: 生成指南结构
            generationProgress = 0.7
            let guideStructure = generateGuideStructure(productInfo: productInfo, keyInfo: keyInformation)
            
            // 步骤5: 生成具体内容
            generationProgress = 0.9
            let guide = try await generateGuideContent(structure: guideStructure, product: product)
            
            generationProgress = 1.0
            
            // 保存生成的指南
            await saveGeneratedGuide(guide)
            
            return guide
        } catch {
            lastError = error as? GuideGenerationError ?? .unknown(error.localizedDescription)
            throw error
        }
    }
    
    /// 批量生成使用指南
    func generateUsageGuides(for products: [Product]) async throws -> [ProductUsageGuide] {
        isGenerating = true
        generationProgress = 0
        
        defer {
            isGenerating = false
            generationProgress = 0
        }
        
        var guides: [ProductUsageGuide] = []
        let totalProducts = products.count
        
        for (index, product) in products.enumerated() {
            do {
                let guide = try await generateUsageGuide(for: product)
                guides.append(guide)
                
                generationProgress = Double(index + 1) / Double(totalProducts)
            } catch {
                print("为产品 \(product.productName) 生成指南失败: \(error)")
                continue
            }
        }
        
        return guides
    }
    
    // MARK: - 产品信息收集
    
    private func collectProductInformation(_ product: Product) -> ProductInformation {
        return ProductInformation(
            id: product.id ?? UUID(),
            name: product.productName,
            brand: product.productBrand,
            model: product.productModel,
            category: product.category?.categoryName,
            tags: product.productTags.map { $0.tagName },
            purchaseDate: product.order?.orderDate,
            warrantyPeriod: nil, // 需要从 warrantyEndDate 计算
            notes: product.productNotes
        )
    }
    
    // MARK: - 说明书内容分析
    
    private func analyzeManualContent(_ manuals: [Manual]) async throws -> ManualAnalysisResult {
        var combinedContent = ""
        var analysisResults: [SingleManualAnalysis] = []
        
        for manual in manuals {
            guard let content = manual.content, !content.isEmpty else { continue }
            
            combinedContent += content + "\n\n"
            
            let analysis = try await analyzeSingleManual(manual)
            analysisResults.append(analysis)
        }
        
        return ManualAnalysisResult(
            combinedContent: combinedContent,
            individualAnalyses: analysisResults,
            detectedLanguage: detectPrimaryLanguage(combinedContent),
            contentLength: combinedContent.count,
            structuralElements: extractStructuralElements(combinedContent)
        )
    }
    
    private func analyzeSingleManual(_ manual: Manual) async throws -> SingleManualAnalysis {
        guard let content = manual.content else {
            throw GuideGenerationError.noManualContent
        }
        
        return SingleManualAnalysis(
            manualId: manual.id ?? UUID(),
            fileName: manual.fileName ?? "未知文件",
            contentSections: extractContentSections(content),
            keyTerms: extractKeyTerms(content),
            instructions: extractInstructions(content),
            warnings: extractWarnings(content),
            specifications: extractSpecifications(content),
            troubleshooting: extractTroubleshooting(content)
        )
    }
    
    // MARK: - 关键信息提取
    
    private func extractKeyInformation(from analysis: ManualAnalysisResult) -> KeyInformation {
        let allSections = analysis.individualAnalyses.flatMap { $0.contentSections }
        let allInstructions = analysis.individualAnalyses.flatMap { $0.instructions }
        let allWarnings = analysis.individualAnalyses.flatMap { $0.warnings }
        let allSpecifications = analysis.individualAnalyses.flatMap { $0.specifications }
        let allTroubleshooting = analysis.individualAnalyses.flatMap { $0.troubleshooting }
        
        return KeyInformation(
            setupInstructions: filterSetupInstructions(allInstructions),
            basicOperations: filterBasicOperations(allInstructions),
            advancedFeatures: filterAdvancedFeatures(allInstructions),
            maintenanceGuidelines: filterMaintenanceGuidelines(allInstructions),
            safetyWarnings: allWarnings,
            technicalSpecifications: allSpecifications,
            commonIssues: allTroubleshooting,
            importantNotes: extractImportantNotes(analysis.combinedContent)
        )
    }
    
    // MARK: - 指南结构生成
    
    private func generateGuideStructure(productInfo: ProductInformation, keyInfo: KeyInformation) -> GuideStructure {
        var sections: [GuideSection] = []
        
        // 1. 产品概述
        sections.append(GuideSection(
            id: UUID(),
            title: "产品概述",
            type: .overview,
            priority: 1,
            content: generateOverviewContent(productInfo)
        ))
        
        // 2. 初始设置
        if !keyInfo.setupInstructions.isEmpty {
            sections.append(GuideSection(
                id: UUID(),
                title: "初始设置",
                type: .setup,
                priority: 2,
                content: keyInfo.setupInstructions
            ))
        }
        
        // 3. 基本操作
        if !keyInfo.basicOperations.isEmpty {
            sections.append(GuideSection(
                id: UUID(),
                title: "基本操作",
                type: .basicOperations,
                priority: 3,
                content: keyInfo.basicOperations
            ))
        }
        
        // 4. 高级功能
        if !keyInfo.advancedFeatures.isEmpty {
            sections.append(GuideSection(
                id: UUID(),
                title: "高级功能",
                type: .advancedFeatures,
                priority: 4,
                content: keyInfo.advancedFeatures
            ))
        }
        
        // 5. 维护保养
        if !keyInfo.maintenanceGuidelines.isEmpty {
            sections.append(GuideSection(
                id: UUID(),
                title: "维护保养",
                type: .maintenance,
                priority: 5,
                content: keyInfo.maintenanceGuidelines
            ))
        }
        
        // 6. 安全注意事项
        if !keyInfo.safetyWarnings.isEmpty {
            sections.append(GuideSection(
                id: UUID(),
                title: "安全注意事项",
                type: .safety,
                priority: 6,
                content: keyInfo.safetyWarnings
            ))
        }
        
        // 7. 故障排除
        if !keyInfo.commonIssues.isEmpty {
            sections.append(GuideSection(
                id: UUID(),
                title: "故障排除",
                type: .troubleshooting,
                priority: 7,
                content: keyInfo.commonIssues
            ))
        }
        
        // 8. 技术规格
        if !keyInfo.technicalSpecifications.isEmpty {
            sections.append(GuideSection(
                id: UUID(),
                title: "技术规格",
                type: .specifications,
                priority: 8,
                content: keyInfo.technicalSpecifications
            ))
        }
        
        return GuideStructure(
            sections: sections.sorted { $0.priority < $1.priority },
            estimatedReadingTime: calculateReadingTime(sections),
            difficultyLevel: assessDifficultyLevel(sections)
        )
    }
    
    // MARK: - 指南内容生成
    
    private func generateGuideContent(structure: GuideStructure, product: Product) async throws -> ProductUsageGuide {
        let guide = ProductUsageGuide(
            id: UUID(),
            productId: product.id ?? UUID(),
            productName: product.productName,
            title: "《\(product.productName)》使用指南",
            subtitle: generateSubtitle(product),
            sections: structure.sections,
            estimatedReadingTime: structure.estimatedReadingTime,
            difficultyLevel: structure.difficultyLevel,
            generatedAt: Date(),
            version: "1.0",
            language: "zh-CN"
        )
        
        return guide
    }
    
    // MARK: - 辅助方法
    
    private func generateOverviewContent(_ productInfo: ProductInformation) -> [String] {
        var content: [String] = []
        
        content.append("产品名称：\(productInfo.name)")
        
        if !productInfo.brand.isEmpty {
            content.append("品牌：\(productInfo.brand)")
        }
        
        if !productInfo.model.isEmpty {
            content.append("型号：\(productInfo.model)")
        }
        
        if let category = productInfo.category {
            content.append("分类：\(category)")
        }
        
        if let purchaseDate = productInfo.purchaseDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            content.append("购买日期：\(formatter.string(from: purchaseDate))")
        }
        
        if let warrantyPeriod = productInfo.warrantyPeriod, warrantyPeriod > 0 {
            content.append("保修期：\(warrantyPeriod)个月")
        }
        
        if !productInfo.notes.isEmpty {
            content.append("备注：\(productInfo.notes)")
        }
        
        return content
    }
    
    private func generateSubtitle(_ product: Product) -> String {
        if !product.productBrand.isEmpty && !product.productModel.isEmpty {
            return "\(product.productBrand) \(product.productModel) 快速上手指南"
        } else if !product.productBrand.isEmpty {
            return "\(product.productBrand) 产品使用指南"
        } else {
            return "产品使用指南"
        }
    }
    
    private func calculateReadingTime(_ sections: [GuideSection]) -> Int {
        let totalWords = sections.reduce(0) { total, section in
            total + section.content.joined(separator: " ").count
        }
        // 假设平均阅读速度为每分钟200字
        return max(1, totalWords / 200)
    }
    
    private func assessDifficultyLevel(_ sections: [GuideSection]) -> DifficultyLevel {
        let hasAdvancedFeatures = sections.contains { $0.type == .advancedFeatures }
        let hasTroubleshooting = sections.contains { $0.type == .troubleshooting }
        let totalSections = sections.count
        
        if hasAdvancedFeatures && hasTroubleshooting && totalSections > 6 {
            return .advanced
        } else if (hasAdvancedFeatures || hasTroubleshooting) && totalSections > 4 {
            return .intermediate
        } else {
            return .beginner
        }
    }
    
    // MARK: - 内容分析方法

    private func detectPrimaryLanguage(_ content: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(content)
        return recognizer.dominantLanguage?.rawValue ?? "zh-CN"
    }

    private func extractStructuralElements(_ content: String) -> [String] {
        var elements: [String] = []

        // 提取标题（通常以数字开头或包含特定关键词）
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isLikelyTitle(trimmed) {
                elements.append(trimmed)
            }
        }

        return elements
    }

    private func isLikelyTitle(_ text: String) -> Bool {
        // 检查是否像标题
        let titlePatterns = [
            "^\\d+\\.", // 以数字开头
            "^第\\d+章", // 章节
            "^\\d+\\s*、", // 中文编号
            "步骤", "设置", "操作", "功能", "注意", "警告", "规格"
        ]

        for pattern in titlePatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        return text.count < 50 && text.count > 3 && !text.contains("。")
    }

    private func extractContentSections(_ content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var sections: [String] = []
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if isLikelyTitle(trimmed) && !currentSection.isEmpty {
                sections.append(currentSection.trimmingCharacters(in: .whitespacesAndNewlines))
                currentSection = trimmed + "\n"
            } else {
                currentSection += line + "\n"
            }
        }

        if !currentSection.isEmpty {
            sections.append(currentSection.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return sections.filter { !$0.isEmpty }
    }

    private func extractKeyTerms(_ content: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = content

        var keyTerms: [String] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]

        tagger.enumerateTags(in: content.startIndex..<content.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if tag == .noun || tag == .verb {
                let term = String(content[tokenRange])
                if term.count > 2 && !keyTerms.contains(term) {
                    keyTerms.append(term)
                }
            }
            return true
        }

        return Array(keyTerms.prefix(20)) // 限制数量
    }

    private func extractInstructions(_ content: String) -> [String] {
        let instructionKeywords = ["步骤", "操作", "方法", "如何", "请", "先", "然后", "接下来", "最后"]
        return extractContentByKeywords(content, keywords: instructionKeywords)
    }

    private func extractWarnings(_ content: String) -> [String] {
        let warningKeywords = ["警告", "注意", "小心", "禁止", "不要", "避免", "危险", "重要"]
        return extractContentByKeywords(content, keywords: warningKeywords)
    }

    private func extractSpecifications(_ content: String) -> [String] {
        let specKeywords = ["规格", "参数", "尺寸", "重量", "功率", "电压", "容量", "性能"]
        return extractContentByKeywords(content, keywords: specKeywords)
    }

    private func extractTroubleshooting(_ content: String) -> [String] {
        let troubleKeywords = ["故障", "问题", "错误", "异常", "无法", "不能", "失败", "排除", "解决"]
        return extractContentByKeywords(content, keywords: troubleKeywords)
    }

    private func extractContentByKeywords(_ content: String, keywords: [String]) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var matchedContent: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            for keyword in keywords {
                if trimmed.localizedCaseInsensitiveContains(keyword) && !trimmed.isEmpty {
                    matchedContent.append(trimmed)
                    break
                }
            }
        }

        return matchedContent
    }

    private func extractImportantNotes(_ content: String) -> [String] {
        let noteKeywords = ["重要", "提示", "建议", "推荐", "最佳", "优化"]
        return extractContentByKeywords(content, keywords: noteKeywords)
    }

    // MARK: - 内容过滤方法

    private func filterSetupInstructions(_ instructions: [String]) -> [String] {
        let setupKeywords = ["设置", "安装", "初始", "配置", "连接", "开机", "启动"]
        return instructions.filter { instruction in
            setupKeywords.contains { instruction.localizedCaseInsensitiveContains($0) }
        }
    }

    private func filterBasicOperations(_ instructions: [String]) -> [String] {
        let basicKeywords = ["基本", "简单", "开始", "使用", "操作", "功能"]
        return instructions.filter { instruction in
            basicKeywords.contains { instruction.localizedCaseInsensitiveContains($0) }
        }
    }

    private func filterAdvancedFeatures(_ instructions: [String]) -> [String] {
        let advancedKeywords = ["高级", "进阶", "专业", "自定义", "设定", "配置"]
        return instructions.filter { instruction in
            advancedKeywords.contains { instruction.localizedCaseInsensitiveContains($0) }
        }
    }

    private func filterMaintenanceGuidelines(_ instructions: [String]) -> [String] {
        let maintenanceKeywords = ["维护", "保养", "清洁", "保存", "存储", "定期"]
        return instructions.filter { instruction in
            maintenanceKeywords.contains { instruction.localizedCaseInsensitiveContains($0) }
        }
    }

    // MARK: - 数据保存

    private func saveGeneratedGuide(_ guide: ProductUsageGuide) async {
        generatedGuides.append(guide)

        // 这里可以添加持久化存储逻辑
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(guide) {
            UserDefaults.standard.set(data, forKey: "GeneratedGuide_\(guide.id)")
        }
    }
}
