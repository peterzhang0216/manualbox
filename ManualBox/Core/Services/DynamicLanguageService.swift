//
//  DynamicLanguageService.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - 动态语言切换服务
@MainActor
class DynamicLanguageService: ObservableObject {
    static let shared = DynamicLanguageService()
    
    @Published var isLanguageSwitching = false
    @Published var switchProgress: Double = 0.0
    @Published var currentLanguageInfo: LanguageInfo?
    
    private var cancellables = Set<AnyCancellable>()
    private let localizationManager = LocalizationManager.shared
    
    init() {
        setupLanguageObserver()
        updateCurrentLanguageInfo()
    }
    
    // MARK: - 语言切换观察
    
    private func setupLanguageObserver() {
        NotificationCenter.default.publisher(for: .languageChanged)
            .sink { [weak self] _ in
                self?.handleLanguageChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleLanguageChange() {
        performLanguageSwitch()
    }
    
    // MARK: - 语言切换动画
    
    func performLanguageSwitch() {
        guard !isLanguageSwitching else { return }
        
        isLanguageSwitching = true
        switchProgress = 0.0
        
        // 模拟语言切换过程
        withAnimation(.easeInOut(duration: 0.5)) {
            switchProgress = 0.3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.switchProgress = 0.7
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.switchProgress = 1.0
            }
            
            // 更新语言信息
            self.updateCurrentLanguageInfo()
            
            // 完成切换
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isLanguageSwitching = false
                self.switchProgress = 0.0
            }
        }
    }
    
    private func updateCurrentLanguageInfo() {
        currentLanguageInfo = localizationManager.supportedLanguages.first { 
            $0.code == localizationManager.currentLanguage 
        }
    }
    
    // MARK: - 语言切换预检查
    
    func canSwitchLanguage(to languageCode: String) -> Bool {
        return localizationManager.supportedLanguages.contains { $0.code == languageCode }
    }
    
    func switchLanguage(to languageCode: String, animated: Bool = true) {
        guard canSwitchLanguage(to: languageCode) else { return }
        
        if animated {
            performLanguageSwitch()
        }
        
        localizationManager.setLanguage(languageCode)
    }
    
    // MARK: - 语言切换建议
    
    func getLanguageSuggestions() -> [LanguageInfo] {
        let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        let currentLanguage = localizationManager.currentLanguage
        
        var suggestions: [LanguageInfo] = []
        
        // 如果当前不是系统语言，建议系统语言
        if currentLanguage != "auto" && currentLanguage != systemLanguage {
            if let systemLangInfo = localizationManager.supportedLanguages.first(where: { $0.code == systemLanguage }) {
                suggestions.append(systemLangInfo)
            }
        }
        
        // 建议常用语言
        let popularLanguages = ["en", "zh-Hans", "ja", "ko"]
        for langCode in popularLanguages {
            if langCode != currentLanguage,
               let langInfo = localizationManager.supportedLanguages.first(where: { $0.code == langCode }) {
                suggestions.append(langInfo)
            }
        }
        
        return Array(suggestions.prefix(3))
    }
    
    // MARK: - 语言使用统计
    
    func recordLanguageUsage(_ languageCode: String) {
        let key = "language_usage_\(languageCode)"
        let currentCount = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(currentCount + 1, forKey: key)
        
        // 记录最后使用时间
        let timeKey = "language_last_used_\(languageCode)"
        UserDefaults.standard.set(Date(), forKey: timeKey)
    }
    
    func getLanguageUsageStats() -> [LanguageUsageStats] {
        var stats: [LanguageUsageStats] = []
        
        for language in localizationManager.supportedLanguages {
            let usageKey = "language_usage_\(language.code)"
            let timeKey = "language_last_used_\(language.code)"
            
            let usageCount = UserDefaults.standard.integer(forKey: usageKey)
            let lastUsed = UserDefaults.standard.object(forKey: timeKey) as? Date
            
            stats.append(LanguageUsageStats(
                language: language,
                usageCount: usageCount,
                lastUsed: lastUsed
            ))
        }
        
        return stats.sorted { $0.usageCount > $1.usageCount }
    }
    
    // MARK: - 语言切换历史
    
    func recordLanguageSwitch(from: String, to: String) {
        var history = getLanguageSwitchHistory()
        
        let record = LanguageSwitchRecord(
            fromLanguage: from,
            toLanguage: to,
            timestamp: Date()
        )
        
        history.append(record)
        
        // 只保留最近50条记录
        if history.count > 50 {
            history = Array(history.suffix(50))
        }
        
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "language_switch_history")
        }
    }
    
    func getLanguageSwitchHistory() -> [LanguageSwitchRecord] {
        guard let data = UserDefaults.standard.data(forKey: "language_switch_history"),
              let history = try? JSONDecoder().decode([LanguageSwitchRecord].self, from: data) else {
            return []
        }
        return history
    }
    
    // MARK: - 语言偏好学习
    
    func learnLanguagePreferences() {
        let stats = getLanguageUsageStats()
        let history = getLanguageSwitchHistory()
        
        // 分析用户的语言使用模式
        var preferences: [String: Double] = [:]
        
        // 基于使用频率
        for stat in stats {
            let frequency = Double(stat.usageCount)
            preferences[stat.language.code] = frequency
        }
        
        // 基于切换历史
        for record in history.suffix(20) { // 只考虑最近20次切换
            preferences[record.toLanguage, default: 0] += 1.0
        }
        
        // 保存偏好
        UserDefaults.standard.set(preferences, forKey: "language_preferences")
    }
    
    func getPreferredLanguages() -> [LanguageInfo] {
        guard let preferences = UserDefaults.standard.dictionary(forKey: "language_preferences") as? [String: Double] else {
            return []
        }
        
        let sortedPreferences = preferences.sorted { $0.value > $1.value }
        
        return sortedPreferences.compactMap { (code, _) in
            localizationManager.supportedLanguages.first { $0.code == code }
        }
    }
}

// MARK: - 数据结构

struct LanguageUsageStats: Identifiable {
    let id = UUID()
    let language: LanguageInfo
    let usageCount: Int
    let lastUsed: Date?
    
    var usageFrequency: String {
        switch usageCount {
        case 0:
            return "从未使用"
        case 1...5:
            return "偶尔使用"
        case 6...20:
            return "经常使用"
        default:
            return "频繁使用"
        }
    }
}

struct LanguageSwitchRecord: Identifiable, Codable {
    let id: UUID
    let fromLanguage: String
    let toLanguage: String
    let timestamp: Date

    init(fromLanguage: String, toLanguage: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.fromLanguage = fromLanguage
        self.toLanguage = toLanguage
        self.timestamp = timestamp
    }
}

// MARK: - 语言切换覆盖视图
struct LanguageSwitchOverlay: View {
    @StateObject private var languageService = DynamicLanguageService.shared
    
    var body: some View {
        if languageService.isLanguageSwitching {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 语言切换动画
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "globe")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(languageService.switchProgress * 360))
                    }
                    
                    // 进度条
                    VStack(spacing: 8) {
                        Text("正在切换语言...".localized)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ProgressView(value: languageService.switchProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 200)
                        
                        if let currentLang = languageService.currentLanguageInfo {
                            HStack {
                                Text(currentLang.flag)
                                Text("切换到 \(currentLang.nativeName)".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(30)
                .background(ModernColors.Background.primary)
                .cornerRadius(20)
                .shadow(radius: 10)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: languageService.isLanguageSwitching)
        }
    }
}

// MARK: - 预览
struct DynamicLanguageService_Previews: PreviewProvider {
    static var previews: some View {
        LanguageSwitchOverlay()
    }
}
