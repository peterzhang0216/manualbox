import SwiftUI

// MARK: - 设置搜索功能

struct SettingsSearchView: View {
    @Binding var searchText: String
    @State private var searchResults: [SettingsSearchResult] = []
    
    var body: some View {
        NavigationStack {
            if searchText.isEmpty {
                SettingsSearchPlaceholder()
            } else if searchResults.isEmpty {
                SettingsSearchEmpty(searchText: searchText)
            } else {
                SettingsSearchResults(results: searchResults)
            }
        }
        .navigationTitle("搜索设置")
        .searchable(text: $searchText, prompt: "搜索设置项...")
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let lowercaseQuery = query.lowercased()
        var results: [SettingsSearchResult] = []
        
        // 搜索主面板
        for panel in SettingsPanel.allCases {
            if panel.title.lowercased().contains(lowercaseQuery) ||
               panel.description.lowercased().contains(lowercaseQuery) {
                results.append(SettingsSearchResult(
                    type: .panel,
                    panel: panel,
                    subPanel: nil,
                    title: panel.title,
                    description: panel.description,
                    icon: panel.icon,
                    color: panel.color
                ))
            }
        }
        
        // 搜索子面板
        for subPanel in SettingsSubPanel.allCases {
            if subPanel.title.lowercased().contains(lowercaseQuery) ||
               subPanel.description.lowercased().contains(lowercaseQuery) {
                results.append(SettingsSearchResult(
                    type: .subPanel,
                    panel: subPanel.parentPanel,
                    subPanel: subPanel,
                    title: subPanel.title,
                    description: subPanel.description,
                    icon: subPanel.icon,
                    color: subPanel.color
                ))
            }
        }
        
        // 搜索设置项关键词
        let settingsKeywords = getSettingsKeywords()
        for keyword in settingsKeywords {
            if keyword.keywords.contains(where: { $0.lowercased().contains(lowercaseQuery) }) {
                if !results.contains(where: { $0.subPanel == keyword.subPanel }) {
                    results.append(SettingsSearchResult(
                        type: .keyword,
                        panel: keyword.subPanel.parentPanel,
                        subPanel: keyword.subPanel,
                        title: keyword.subPanel.title,
                        description: "包含: \(keyword.keywords.joined(separator: ", "))",
                        icon: keyword.subPanel.icon,
                        color: keyword.subPanel.color
                    ))
                }
            }
        }
        
        searchResults = results
    }
    
    private func getSettingsKeywords() -> [SettingsKeyword] {
        return [
            SettingsKeyword(subPanel: .notificationPermissions, keywords: ["通知", "权限", "推送", "提醒"]),
            SettingsKeyword(subPanel: .reminderSettings, keywords: ["提醒", "时间", "计划", "保修"]),
            SettingsKeyword(subPanel: .silentPeriod, keywords: ["免打扰", "静音", "勿扰"]),
            SettingsKeyword(subPanel: .themeMode, keywords: ["主题", "深色", "浅色", "外观"]),
            SettingsKeyword(subPanel: .themeColors, keywords: ["颜色", "色彩", "主题色"]),
            SettingsKeyword(subPanel: .displayOptions, keywords: ["显示", "动画", "对比度", "可访问性"]),
            SettingsKeyword(subPanel: .languageSettings, keywords: ["语言", "中文", "英文", "国际化"]),
            SettingsKeyword(subPanel: .defaultParameters, keywords: ["默认", "参数", "保修期"]),
            SettingsKeyword(subPanel: .ocrSettings, keywords: ["OCR", "识别", "文字", "扫描"]),
            SettingsKeyword(subPanel: .advancedOptions, keywords: ["高级", "实验", "开发者"]),
            SettingsKeyword(subPanel: .backupRestore, keywords: ["备份", "恢复", "云同步"]),
            SettingsKeyword(subPanel: .importExport, keywords: ["导入", "导出", "迁移"]),
            SettingsKeyword(subPanel: .dataCleanup, keywords: ["清理", "重置", "删除", "缓存"]),
            SettingsKeyword(subPanel: .appInfo, keywords: ["版本", "信息", "关于"]),
            SettingsKeyword(subPanel: .helpSupport, keywords: ["帮助", "支持", "反馈", "联系"]),
            SettingsKeyword(subPanel: .legalTerms, keywords: ["隐私", "协议", "条款", "法律"])
        ]
    }
}

// MARK: - 搜索结果数据模型

struct SettingsSearchResult: Identifiable, Hashable {
    let id = UUID()
    let type: SearchResultType
    let panel: SettingsPanel
    let subPanel: SettingsSubPanel?
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    enum SearchResultType {
        case panel
        case subPanel
        case keyword
    }
}

struct SettingsKeyword {
    let subPanel: SettingsSubPanel
    let keywords: [String]
}

// MARK: - 搜索界面组件

struct SettingsSearchPlaceholder: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("搜索设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("输入关键词快速找到您需要的设置项")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("搜索建议:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    SearchSuggestionRow(icon: "bell.fill", text: "通知、提醒、推送")
                    SearchSuggestionRow(icon: "paintbrush.fill", text: "主题、颜色、外观")
                    SearchSuggestionRow(icon: "gear", text: "默认、参数、设置")
                    SearchSuggestionRow(icon: "externaldrive.fill", text: "备份、导出、数据")
                }
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground)
    }
}

struct SearchSuggestionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct SettingsSearchEmpty: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("未找到相关设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("没有找到包含 \"\(searchText)\" 的设置项")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Text("请尝试其他关键词或浏览设置分类")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground)
    }
}

struct SettingsSearchResults: View {
    let results: [SettingsSearchResult]
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        List {
            ForEach(results) { result in
                NavigationLink(destination: destinationView(for: result)) {
                    SettingsSearchResultRow(result: result)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
    }
    
    @ViewBuilder
    private func destinationView(for result: SettingsSearchResult) -> some View {
        SettingsDetailViewWithPanel(panel: result.panel, title: result.title)
    }
}

// MARK: - Settings Detail View with Panel
struct SettingsDetailViewWithPanel: View {
    let panel: SettingsPanel
    let title: String
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: SettingsViewModel

    init(panel: SettingsPanel, title: String) {
        self.panel = panel
        self.title = title
        // 创建一个临时的 viewContext 来初始化 viewModel
        let context = PersistenceController.shared.container.viewContext
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(viewContext: context))
    }

    var body: some View {
        SettingsDetailView(viewModel: viewModel)
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                Task {
                    await viewModel.handle(.selectPanel(panel))
                }
            }
    }
}

struct SettingsSearchResultRow: View {
    let result: SettingsSearchResult
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: result.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(result.color)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(result.color.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(result.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if result.type == .keyword {
                Text("关键词")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.2))
                    )
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsSearchView(searchText: .constant(""))
}
