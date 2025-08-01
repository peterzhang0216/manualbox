//
//  UserFeedbackService.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  用户反馈服务 - 收集、分析和处理用户反馈
//

import Foundation
import SwiftUI
import Combine

// MARK: - 用户反馈服务
@MainActor
class UserFeedbackService: ObservableObject {
    static let shared = UserFeedbackService()
    
    // MARK: - Published Properties
    @Published private(set) var feedbackHistory: [FeedbackRecord] = []
    @Published private(set) var feedbackStatistics: FeedbackStatistics = FeedbackStatistics()
    @Published private(set) var pendingFeedback: [FeedbackRecord] = []
    @Published private(set) var feedbackTrends: [FeedbackTrend] = []
    @Published private(set) var isCollectionEnabled = true
    @Published private(set) var lastAnalysisDate: Date?
    
    // MARK: - Private Properties
    private let maxFeedbackHistory = 500
    private var cancellables = Set<AnyCancellable>()
    private let analysisEngine = FeedbackAnalysisEngine()
    
    // MARK: - Initialization
    private init() {
        loadFeedbackHistory()
        setupFeedbackCollection()
        schedulePeriodicAnalysis()
    }
    
    // MARK: - Public Methods
    
    /// 提交用户反馈
    func submitFeedback(
        type: FeedbackType,
        rating: Int? = nil,
        title: String,
        description: String,
        category: FeedbackCategory,
        attachments: [FeedbackAttachment] = [],
        userInfo: UserInfo? = nil
    ) async -> Bool {
        
        guard isCollectionEnabled else {
            print("📝 反馈收集已禁用")
            return false
        }
        
        let feedback = FeedbackRecord(
            type: type,
            rating: rating,
            title: title,
            description: description,
            category: category,
            attachments: attachments,
            userInfo: userInfo ?? getCurrentUserInfo(),
            timestamp: Date(),
            status: .pending
        )
        
        feedbackHistory.insert(feedback, at: 0)
        pendingFeedback.append(feedback)
        
        // 限制历史记录数量
        if feedbackHistory.count > maxFeedbackHistory {
            feedbackHistory.removeLast()
        }
        
        updateStatistics()
        saveFeedbackHistory()
        
        // 自动分类和优先级设置
        await categorizeFeedback(feedback)
        
        print("📝 用户反馈已提交: \(feedback.title) - \(feedback.category.displayName)")
        return true
    }
    
    /// 更新反馈状态
    func updateFeedbackStatus(_ feedbackId: UUID, status: FeedbackStatus, response: String? = nil) {
        if let index = feedbackHistory.firstIndex(where: { $0.id == feedbackId }) {
            feedbackHistory[index].status = status
            feedbackHistory[index].response = response
            feedbackHistory[index].updatedAt = Date()
            
            // 从待处理列表中移除
            if status != .pending {
                pendingFeedback.removeAll { $0.id == feedbackId }
            }
            
            saveFeedbackHistory()
            updateStatistics()
            
            print("📝 反馈状态已更新: \(feedbackHistory[index].title) - \(status.displayName)")
        }
    }
    
    /// 获取反馈统计
    func getFeedbackStatistics(timeRange: ErrorTimeRange = .last30Days) -> FeedbackStatistics {
        let filteredFeedback = filterFeedback(by: timeRange)
        return generateStatistics(from: filteredFeedback)
    }
    
    /// 获取反馈趋势
    func getFeedbackTrends(timeRange: ErrorTimeRange = .last30Days) -> [FeedbackTrend] {
        let filteredFeedback = filterFeedback(by: timeRange)
        return analyzeTrends(filteredFeedback)
    }
    
    /// 分析用户满意度
    func analyzeSatisfaction(timeRange: ErrorTimeRange = .last30Days) -> SatisfactionAnalysis {
        let filteredFeedback = filterFeedback(by: timeRange)
        return analysisEngine.analyzeSatisfaction(from: filteredFeedback)
    }
    
    /// 获取功能请求排名
    func getFeatureRequestRanking() -> [FeatureRequest] {
        let featureRequests = feedbackHistory.filter { $0.type == .featureRequest }
        return analysisEngine.rankFeatureRequests(from: featureRequests)
    }
    
    /// 获取常见问题
    func getCommonIssues(limit: Int = 10) -> [CommonIssue] {
        return analysisEngine.identifyCommonIssues(from: feedbackHistory, limit: limit)
    }
    
    /// 生成反馈报告
    func generateFeedbackReport(timeRange: ErrorTimeRange = .last30Days) async -> FeedbackReport {
        let filteredFeedback = filterFeedback(by: timeRange)
        return await analysisEngine.generateReport(from: filteredFeedback, timeRange: timeRange)
    }
    
    /// 导出反馈数据
    func exportFeedbackData(format: ExportFormat = .json, includePersonalInfo: Bool = false) -> Data? {
        let exportData = feedbackHistory.map { feedback in
            var exportFeedback = feedback
            if !includePersonalInfo {
                exportFeedback.userInfo = nil
            }
            return exportFeedback
        }
        
        switch format {
        case .json:
            return try? JSONEncoder().encode(exportData)
        case .csv:
            return generateCSVData(from: exportData)
        }
    }
    
    /// 设置反馈收集状态
    func setFeedbackCollectionEnabled(_ enabled: Bool) {
        isCollectionEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "FeedbackCollectionEnabled")
        
        print("📝 反馈收集已\(enabled ? "启用" : "禁用")")
    }
    
    /// 清除反馈历史
    func clearFeedbackHistory() {
        feedbackHistory.removeAll()
        pendingFeedback.removeAll()
        feedbackStatistics = FeedbackStatistics()
        feedbackTrends.removeAll()
        saveFeedbackHistory()
        
        print("🧹 反馈历史已清除")
    }
    
    // MARK: - Private Methods
    
    private func setupFeedbackCollection() {
        // 监听应用事件以收集隐式反馈
        NotificationCenter.default.publisher(for: .userInteraction)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleUserInteraction(notification)
                }
            }
            .store(in: &cancellables)
    }
    
    private func schedulePeriodicAnalysis() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in // 每小时
            Task { @MainActor in
                await self.performPeriodicAnalysis()
            }
        }
    }
    
    private func performPeriodicAnalysis() async {
        updateStatistics()
        feedbackTrends = getFeedbackTrends()
        lastAnalysisDate = Date()
        
        // 检查需要关注的反馈
        await checkForCriticalFeedback()
        
        print("📊 反馈分析已完成")
    }
    
    private func categorizeFeedback(_ feedback: FeedbackRecord) async {
        // 使用简单的关键词匹配进行自动分类
        let keywords = feedback.description.lowercased()
        
        var suggestedCategory = feedback.category
        var priority = FeedbackPriority.medium
        
        // 性能相关
        if keywords.contains("慢") || keywords.contains("卡顿") || keywords.contains("延迟") {
            suggestedCategory = .performance
            priority = .high
        }
        // 崩溃相关
        else if keywords.contains("崩溃") || keywords.contains("闪退") || keywords.contains("无响应") {
            suggestedCategory = .bug
            priority = .critical
        }
        // 界面相关
        else if keywords.contains("界面") || keywords.contains("布局") || keywords.contains("显示") {
            suggestedCategory = .ui
            priority = .medium
        }
        // 功能请求
        else if keywords.contains("希望") || keywords.contains("建议") || keywords.contains("增加") {
            suggestedCategory = .feature
            priority = .low
        }
        
        // 更新反馈记录
        if let index = feedbackHistory.firstIndex(where: { $0.id == feedback.id }) {
            feedbackHistory[index].suggestedCategory = suggestedCategory
            feedbackHistory[index].priority = priority
            saveFeedbackHistory()
        }
    }
    
    private func checkForCriticalFeedback() async {
        let recentFeedback = filterFeedback(by: .last24Hours)
        
        // 检查严重问题
        let criticalFeedback = recentFeedback.filter { feedback in
            feedback.priority == .critical || 
            (feedback.rating != nil && feedback.rating! <= 2) ||
            feedback.description.lowercased().contains("崩溃")
        }
        
        if !criticalFeedback.isEmpty {
            print("🚨 发现 \(criticalFeedback.count) 个严重反馈需要关注")
            
            // 在实际应用中，这里可以发送通知给开发团队
            for feedback in criticalFeedback {
                print("🚨 严重反馈: \(feedback.title)")
            }
        }
    }
    
    private func handleUserInteraction(_ notification: Notification) async {
        // 处理用户交互事件，收集隐式反馈
        guard let interaction = notification.object as? UserInteraction else { return }
        
        // 根据交互类型收集反馈
        switch interaction.type {
        case .appCrash:
            await submitFeedback(
                type: .bug,
                title: "应用崩溃",
                description: "应用在使用过程中发生崩溃",
                category: .bug
            )
            
        case .performanceIssue:
            await submitFeedback(
                type: .bug,
                title: "性能问题",
                description: "应用响应缓慢或卡顿",
                category: .performance
            )
            
        default:
            break
        }
    }
    
    private func filterFeedback(by timeRange: ErrorTimeRange) -> [FeedbackRecord] {
        let cutoffDate = timeRange.cutoffDate
        return feedbackHistory.filter { $0.timestamp >= cutoffDate }
    }
    
    private func generateStatistics(from feedback: [FeedbackRecord]) -> FeedbackStatistics {
        let totalFeedback = feedback.count
        let ratedFeedback = feedback.compactMap { $0.rating }
        let averageRating = ratedFeedback.isEmpty ? 0.0 : Double(ratedFeedback.reduce(0, +)) / Double(ratedFeedback.count)
        
        let categoryCount = Dictionary(grouping: feedback, by: { $0.category })
            .mapValues { $0.count }
        
        let statusCount = Dictionary(grouping: feedback, by: { $0.status })
            .mapValues { $0.count }
        
        let responseRate = Double(feedback.filter { $0.status == .resolved }.count) / Double(max(totalFeedback, 1))
        
        return FeedbackStatistics(
            totalFeedback: totalFeedback,
            averageRating: averageRating,
            categoryDistribution: categoryCount,
            statusDistribution: statusCount,
            responseRate: responseRate,
            pendingCount: pendingFeedback.count
        )
    }
    
    private func analyzeTrends(_ feedback: [FeedbackRecord]) -> [FeedbackTrend] {
        let groupedByDay = Dictionary(grouping: feedback) { feedback in
            Calendar.current.startOfDay(for: feedback.timestamp)
        }
        
        return groupedByDay.map { (date, feedbackList) in
            let ratings = feedbackList.compactMap { $0.rating }
            let averageRating = ratings.isEmpty ? 0.0 : Double(ratings.reduce(0, +)) / Double(ratings.count)
            
            return FeedbackTrend(
                date: date,
                count: feedbackList.count,
                averageRating: averageRating,
                categories: Dictionary(grouping: feedbackList, by: { $0.category })
                    .mapValues { $0.count }
            )
        }.sorted { $0.date < $1.date }
    }
    
    private func getCurrentUserInfo() -> UserInfo {
        return UserInfo(
            deviceModel: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            locale: Locale.current.identifier
        )
    }
    
    private func generateCSVData(from feedback: [FeedbackRecord]) -> Data? {
        var csvContent = "Timestamp,Type,Rating,Title,Category,Status,Description\n"
        
        for record in feedback {
            let row = [
                record.timestamp.ISO8601Format(),
                record.type.displayName,
                record.rating?.description ?? "",
                record.title.replacingOccurrences(of: ",", with: ";"),
                record.category.displayName,
                record.status.displayName,
                record.description.replacingOccurrences(of: ",", with: ";").prefix(100).description
            ].joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        return csvContent.data(using: .utf8)
    }
    
    private func loadFeedbackHistory() {
        if let data = UserDefaults.standard.data(forKey: "FeedbackHistory"),
           let history = try? JSONDecoder().decode([FeedbackRecord].self, from: data) {
            feedbackHistory = history
            pendingFeedback = history.filter { $0.status == .pending }
            updateStatistics()
        }
        
        isCollectionEnabled = UserDefaults.standard.bool(forKey: "FeedbackCollectionEnabled")
        if !UserDefaults.standard.bool(forKey: "FeedbackSettingsInitialized") {
            isCollectionEnabled = true
            UserDefaults.standard.set(true, forKey: "FeedbackCollectionEnabled")
            UserDefaults.standard.set(true, forKey: "FeedbackSettingsInitialized")
        }
    }
    
    private func saveFeedbackHistory() {
        if let data = try? JSONEncoder().encode(feedbackHistory) {
            UserDefaults.standard.set(data, forKey: "FeedbackHistory")
        }
    }
    
    private func updateStatistics() {
        feedbackStatistics = generateStatistics(from: feedbackHistory)
    }
}

// MARK: - 反馈记录
struct FeedbackRecord: Identifiable, Codable {
    let id = UUID()
    let type: FeedbackType
    let rating: Int?
    let title: String
    let description: String
    let category: FeedbackCategory
    let attachments: [FeedbackAttachment]
    let userInfo: UserInfo?
    let timestamp: Date
    var status: FeedbackStatus
    var response: String?
    var updatedAt: Date?
    var suggestedCategory: FeedbackCategory?
    var priority: FeedbackPriority = .medium
}

// MARK: - 反馈类型
enum FeedbackType: String, CaseIterable, Codable {
    case bug = "bug"
    case featureRequest = "feature_request"
    case improvement = "improvement"
    case compliment = "compliment"
    case complaint = "complaint"
    case question = "question"
    
    var displayName: String {
        switch self {
        case .bug: return "错误报告"
        case .featureRequest: return "功能请求"
        case .improvement: return "改进建议"
        case .compliment: return "表扬"
        case .complaint: return "投诉"
        case .question: return "问题咨询"
        }
    }
    
    var icon: String {
        switch self {
        case .bug: return "ant.fill"
        case .featureRequest: return "lightbulb.fill"
        case .improvement: return "arrow.up.circle.fill"
        case .compliment: return "heart.fill"
        case .complaint: return "exclamationmark.triangle.fill"
        case .question: return "questionmark.circle.fill"
        }
    }
}

// MARK: - 反馈分类
enum FeedbackCategory: String, CaseIterable, Codable {
    case general = "general"
    case ui = "ui"
    case performance = "performance"
    case feature = "feature"
    case bug = "bug"
    case sync = "sync"
    case accessibility = "accessibility"
    case security = "security"
    
    var displayName: String {
        switch self {
        case .general: return "一般"
        case .ui: return "用户界面"
        case .performance: return "性能"
        case .feature: return "功能"
        case .bug: return "错误"
        case .sync: return "同步"
        case .accessibility: return "无障碍"
        case .security: return "安全"
        }
    }
}

// MARK: - 反馈状态
enum FeedbackStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case resolved = "resolved"
    case closed = "closed"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "待处理"
        case .inProgress: return "处理中"
        case .resolved: return "已解决"
        case .closed: return "已关闭"
        case .rejected: return "已拒绝"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .inProgress: return .blue
        case .resolved: return .green
        case .closed: return .gray
        case .rejected: return .red
        }
    }
}

// MARK: - 反馈优先级
enum FeedbackPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "严重"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - 反馈附件
struct FeedbackAttachment: Codable {
    let id = UUID()
    let type: AttachmentType
    let filename: String
    let data: Data
    let mimeType: String
}

enum AttachmentType: String, Codable {
    case image = "image"
    case video = "video"
    case log = "log"
    case document = "document"
}

// MARK: - 用户信息
struct UserInfo: Codable {
    let deviceModel: String
    let systemVersion: String
    let appVersion: String
    let locale: String
}

// MARK: - 反馈统计
struct FeedbackStatistics {
    let totalFeedback: Int
    let averageRating: Double
    let categoryDistribution: [FeedbackCategory: Int]
    let statusDistribution: [FeedbackStatus: Int]
    let responseRate: Double
    let pendingCount: Int
    
    init() {
        self.totalFeedback = 0
        self.averageRating = 0.0
        self.categoryDistribution = [:]
        self.statusDistribution = [:]
        self.responseRate = 0.0
        self.pendingCount = 0
    }
    
    init(totalFeedback: Int, averageRating: Double, categoryDistribution: [FeedbackCategory: Int], statusDistribution: [FeedbackStatus: Int], responseRate: Double, pendingCount: Int) {
        self.totalFeedback = totalFeedback
        self.averageRating = averageRating
        self.categoryDistribution = categoryDistribution
        self.statusDistribution = statusDistribution
        self.responseRate = responseRate
        self.pendingCount = pendingCount
    }
}

// MARK: - 反馈趋势
struct FeedbackTrend: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    let averageRating: Double
    let categories: [FeedbackCategory: Int]
}

// MARK: - 满意度分析
struct SatisfactionAnalysis {
    let overallSatisfaction: Double
    let trendDirection: TrendDirection
    let satisfactionByCategory: [FeedbackCategory: Double]
    let improvementAreas: [String]
    let positiveHighlights: [String]
}

// MARK: - 功能请求
struct FeatureRequest: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let requestCount: Int
    let averageRating: Double
    let category: FeedbackCategory
    let priority: FeedbackPriority
}

// MARK: - 常见问题
struct CommonIssue: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let occurrenceCount: Int
    let category: FeedbackCategory
    let suggestedSolution: String?
}

// MARK: - 反馈报告
struct FeedbackReport {
    let generatedAt: Date
    let timeRange: String
    let statistics: FeedbackStatistics
    let trends: [FeedbackTrend]
    let satisfactionAnalysis: SatisfactionAnalysis
    let topIssues: [CommonIssue]
    let featureRequests: [FeatureRequest]
    let recommendations: [String]
}

// MARK: - 反馈分析引擎
class FeedbackAnalysisEngine {
    func analyzeSatisfaction(from feedback: [FeedbackRecord]) -> SatisfactionAnalysis {
        let ratedFeedback = feedback.compactMap { $0.rating }
        let overallSatisfaction = ratedFeedback.isEmpty ? 0.0 : Double(ratedFeedback.reduce(0, +)) / Double(ratedFeedback.count)
        
        // 计算趋势方向（简化实现）
        let recentRatings = feedback.prefix(10).compactMap { $0.rating }
        let olderRatings = feedback.dropFirst(10).prefix(10).compactMap { $0.rating }
        
        let recentAvg = recentRatings.isEmpty ? 0.0 : Double(recentRatings.reduce(0, +)) / Double(recentRatings.count)
        let olderAvg = olderRatings.isEmpty ? 0.0 : Double(olderRatings.reduce(0, +)) / Double(olderRatings.count)
        
        let trendDirection: TrendDirection
        if recentAvg > olderAvg + 0.5 {
            trendDirection = .up
        } else if recentAvg < olderAvg - 0.5 {
            trendDirection = .down
        } else {
            trendDirection = .stable
        }
        
        // 按分类计算满意度
        let satisfactionByCategory = Dictionary(grouping: feedback.filter { $0.rating != nil }, by: { $0.category })
            .mapValues { categoryFeedback in
                let ratings = categoryFeedback.compactMap { $0.rating }
                return ratings.isEmpty ? 0.0 : Double(ratings.reduce(0, +)) / Double(ratings.count)
            }
        
        // 识别改进领域和积极亮点
        let lowRatingFeedback = feedback.filter { $0.rating != nil && $0.rating! <= 2 }
        let highRatingFeedback = feedback.filter { $0.rating != nil && $0.rating! >= 4 }
        
        let improvementAreas = Array(Set(lowRatingFeedback.map { $0.category.displayName })).prefix(5).map { String($0) }
        let positiveHighlights = Array(Set(highRatingFeedback.map { $0.title })).prefix(5).map { String($0) }
        
        return SatisfactionAnalysis(
            overallSatisfaction: overallSatisfaction,
            trendDirection: trendDirection,
            satisfactionByCategory: satisfactionByCategory,
            improvementAreas: improvementAreas,
            positiveHighlights: positiveHighlights
        )
    }
    
    func rankFeatureRequests(from feedback: [FeedbackRecord]) -> [FeatureRequest] {
        let featureRequests = Dictionary(grouping: feedback, by: { $0.title })
            .compactMap { (title, requests) -> FeatureRequest? in
                guard !requests.isEmpty else { return nil }
                
                let ratings = requests.compactMap { $0.rating }
                let averageRating = ratings.isEmpty ? 0.0 : Double(ratings.reduce(0, +)) / Double(ratings.count)
                
                return FeatureRequest(
                    title: title,
                    description: requests.first?.description ?? "",
                    requestCount: requests.count,
                    averageRating: averageRating,
                    category: requests.first?.category ?? .feature,
                    priority: requests.count > 5 ? .high : .medium
                )
            }
        
        return featureRequests.sorted { $0.requestCount > $1.requestCount }
    }
    
    func identifyCommonIssues(from feedback: [FeedbackRecord], limit: Int) -> [CommonIssue] {
        let bugReports = feedback.filter { $0.type == .bug || $0.category == .bug }
        
        let commonIssues = Dictionary(grouping: bugReports, by: { $0.title })
            .compactMap { (title, issues) -> CommonIssue? in
                guard issues.count > 1 else { return nil }
                
                return CommonIssue(
                    title: title,
                    description: issues.first?.description ?? "",
                    occurrenceCount: issues.count,
                    category: issues.first?.category ?? .bug,
                    suggestedSolution: generateSuggestedSolution(for: issues.first?.description ?? "")
                )
            }
        
        return Array(commonIssues.sorted { $0.occurrenceCount > $1.occurrenceCount }.prefix(limit))
    }
    
    func generateReport(from feedback: [FeedbackRecord], timeRange: ErrorTimeRange) async -> FeedbackReport {
        let statistics = generateStatistics(from: feedback)
        let trends = generateTrends(from: feedback)
        let satisfactionAnalysis = analyzeSatisfaction(from: feedback)
        let topIssues = identifyCommonIssues(from: feedback, limit: 10)
        let featureRequests = rankFeatureRequests(from: feedback.filter { $0.type == .featureRequest })
        let recommendations = generateRecommendations(from: feedback)
        
        return FeedbackReport(
            generatedAt: Date(),
            timeRange: timeRange.displayName,
            statistics: statistics,
            trends: trends,
            satisfactionAnalysis: satisfactionAnalysis,
            topIssues: topIssues,
            featureRequests: Array(featureRequests.prefix(10)),
            recommendations: recommendations
        )
    }
    
    private func generateStatistics(from feedback: [FeedbackRecord]) -> FeedbackStatistics {
        let totalFeedback = feedback.count
        let ratedFeedback = feedback.compactMap { $0.rating }
        let averageRating = ratedFeedback.isEmpty ? 0.0 : Double(ratedFeedback.reduce(0, +)) / Double(ratedFeedback.count)
        
        let categoryCount = Dictionary(grouping: feedback, by: { $0.category })
            .mapValues { $0.count }
        
        let statusCount = Dictionary(grouping: feedback, by: { $0.status })
            .mapValues { $0.count }
        
        let responseRate = Double(feedback.filter { $0.status == .resolved }.count) / Double(max(totalFeedback, 1))
        let pendingCount = feedback.filter { $0.status == .pending }.count
        
        return FeedbackStatistics(
            totalFeedback: totalFeedback,
            averageRating: averageRating,
            categoryDistribution: categoryCount,
            statusDistribution: statusCount,
            responseRate: responseRate,
            pendingCount: pendingCount
        )
    }
    
    private func generateTrends(from feedback: [FeedbackRecord]) -> [FeedbackTrend] {
        let groupedByDay = Dictionary(grouping: feedback) { feedback in
            Calendar.current.startOfDay(for: feedback.timestamp)
        }
        
        return groupedByDay.map { (date, feedbackList) in
            let ratings = feedbackList.compactMap { $0.rating }
            let averageRating = ratings.isEmpty ? 0.0 : Double(ratings.reduce(0, +)) / Double(ratings.count)
            
            return FeedbackTrend(
                date: date,
                count: feedbackList.count,
                averageRating: averageRating,
                categories: Dictionary(grouping: feedbackList, by: { $0.category })
                    .mapValues { $0.count }
            )
        }.sorted { $0.date < $1.date }
    }
    
    private func generateRecommendations(from feedback: [FeedbackRecord]) -> [String] {
        var recommendations: [String] = []
        
        // 基于满意度的建议
        let lowRatingCount = feedback.filter { $0.rating != nil && $0.rating! <= 2 }.count
        if lowRatingCount > feedback.count / 4 {
            recommendations.append("用户满意度较低，建议优先处理低评分反馈")
        }
        
        // 基于常见问题的建议
        let bugCount = feedback.filter { $0.type == .bug }.count
        if bugCount > feedback.count / 3 {
            recommendations.append("错误报告较多，建议加强质量保证和测试")
        }
        
        // 基于功能请求的建议
        let featureRequestCount = feedback.filter { $0.type == .featureRequest }.count
        if featureRequestCount > feedback.count / 4 {
            recommendations.append("功能请求较多，建议评估用户需求并规划新功能")
        }
        
        return recommendations
    }
    
    private func generateSuggestedSolution(for description: String) -> String? {
        let keywords = description.lowercased()
        
        if keywords.contains("崩溃") || keywords.contains("闪退") {
            return "检查相关代码逻辑，增加异常处理"
        } else if keywords.contains("慢") || keywords.contains("卡顿") {
            return "优化性能，检查是否有阻塞主线程的操作"
        } else if keywords.contains("界面") || keywords.contains("显示") {
            return "检查UI布局和约束设置"
        } else if keywords.contains("同步") {
            return "检查网络连接和同步逻辑"
        }
        
        return nil
    }
}

// MARK: - 用户交互事件
struct UserInteraction {
    let type: InteractionType
    let timestamp: Date
    let context: [String: Any]
}

enum InteractionType {
    case appCrash
    case performanceIssue
    case featureUsage
    case errorEncountered
}

// MARK: - 通知扩展
extension Notification.Name {
    static let userInteraction = Notification.Name("UserInteraction")
}