//
//  QuickOperationsService.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import Foundation
import SwiftUI
import CoreData
import Combine

// MARK: - 快速操作服务
@MainActor
class QuickOperationsService: ObservableObject {
    static let shared = QuickOperationsService()
    
    @Published var isQuickActionPanelVisible = false
    @Published var recentActions: [QuickAction] = []
    @Published var favoriteActions: [QuickAction] = []
    @Published var searchText = ""
    @Published var filteredActions: [QuickAction] = []
    
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    private let maxRecentActions = 10
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        setupSearchBinding()
        loadFavoriteActions()
        setupAllActions()
    }
    
    // MARK: - 所有可用操作
    
    var allActions: [QuickAction] = []
    
    private func setupAllActions() {
        allActions = [
            // 产品操作
            QuickAction(
                id: "add_product",
                title: "添加产品",
                subtitle: "快速添加新产品",
                icon: "plus.circle",
                category: .product,
                keyboardShortcut: "⌘N",
                action: { await self.addProduct() }
            ),
            QuickAction(
                id: "quick_add_product",
                title: "快速添加产品",
                subtitle: "使用简化表单添加产品",
                icon: "plus.circle.fill",
                category: .product,
                keyboardShortcut: "⌘⇧N",
                action: { await self.quickAddProduct() }
            ),
            QuickAction(
                id: "scan_product",
                title: "扫描添加产品",
                subtitle: "通过相机扫描添加产品",
                icon: "camera.viewfinder",
                category: .product,
                keyboardShortcut: "⌘⌥N",
                action: { await self.scanProduct() }
            ),
            
            // 搜索操作
            QuickAction(
                id: "search_products",
                title: "搜索产品",
                subtitle: "在所有产品中搜索",
                icon: "magnifyingglass",
                category: .search,
                keyboardShortcut: "⌘F",
                action: { await self.searchProducts() }
            ),
            QuickAction(
                id: "search_manuals",
                title: "搜索说明书",
                subtitle: "在说明书内容中搜索",
                icon: "doc.text.magnifyingglass",
                category: .search,
                keyboardShortcut: "⌘⇧F",
                action: { await self.searchManuals() }
            ),
            
            // 批量操作
            QuickAction(
                id: "batch_edit",
                title: "批量编辑",
                subtitle: "批量编辑选中的产品",
                icon: "square.and.pencil",
                category: .batch,
                keyboardShortcut: "⌘E",
                action: { await self.batchEdit() }
            ),
            QuickAction(
                id: "batch_delete",
                title: "批量删除",
                subtitle: "删除选中的产品",
                icon: "trash.fill",
                category: .batch,
                keyboardShortcut: "⌘⌫",
                action: { await self.batchDelete() }
            ),
            QuickAction(
                id: "batch_export",
                title: "批量导出",
                subtitle: "导出选中的产品数据",
                icon: "square.and.arrow.up",
                category: .batch,
                keyboardShortcut: "⌘⇧E",
                action: { await self.batchExport() }
            ),
            
            // 导航操作
            QuickAction(
                id: "goto_dashboard",
                title: "数据统计",
                subtitle: "查看数据统计仪表板",
                icon: "chart.bar",
                category: .navigation,
                keyboardShortcut: "⌘1",
                action: { await self.gotoDashboard() }
            ),
            QuickAction(
                id: "goto_products",
                title: "产品列表",
                subtitle: "查看所有产品",
                icon: "cube.box",
                category: .navigation,
                keyboardShortcut: "⌘2",
                action: { await self.gotoProducts() }
            ),
            QuickAction(
                id: "goto_categories",
                title: "分类管理",
                subtitle: "管理产品分类",
                icon: "folder",
                category: .navigation,
                keyboardShortcut: "⌘3",
                action: { await self.gotoCategories() }
            ),
            QuickAction(
                id: "goto_settings",
                title: "设置",
                subtitle: "打开应用设置",
                icon: "gearshape",
                category: .navigation,
                keyboardShortcut: "⌘,",
                action: { await self.gotoSettings() }
            ),
            
            // 数据操作
            QuickAction(
                id: "sync_data",
                title: "同步数据",
                subtitle: "立即同步到iCloud",
                icon: "icloud.and.arrow.up",
                category: .data,
                keyboardShortcut: "⌘R",
                action: { await self.syncData() }
            ),
            QuickAction(
                id: "backup_data",
                title: "备份数据",
                subtitle: "创建本地备份",
                icon: "externaldrive",
                category: .data,
                keyboardShortcut: "⌘B",
                action: { await self.backupData() }
            ),
            QuickAction(
                id: "import_data",
                title: "导入数据",
                subtitle: "从文件导入数据",
                icon: "square.and.arrow.down",
                category: .data,
                keyboardShortcut: "⌘I",
                action: { await self.importData() }
            ),
            
            // 分析操作
            QuickAction(
                id: "usage_analysis",
                title: "使用分析",
                subtitle: "查看产品使用分析",
                icon: "chart.bar.doc.horizontal",
                category: .analysis,
                keyboardShortcut: "⌘⌥A",
                action: { await self.showUsageAnalysis() }
            ),
            QuickAction(
                id: "cost_analysis",
                title: "成本分析",
                subtitle: "查看成本分析报告",
                icon: "dollarsign.circle",
                category: .analysis,
                keyboardShortcut: "⌘⌥C",
                action: { await self.showCostAnalysis() }
            )
        ]
        
        filteredActions = allActions
    }
    
    // MARK: - 搜索绑定
    
    private func setupSearchBinding() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] searchText in
                self?.filterActions(searchText: searchText)
            }
            .store(in: &cancellables)
    }
    
    private func filterActions(searchText: String) {
        if searchText.isEmpty {
            filteredActions = allActions
        } else {
            filteredActions = allActions.filter { action in
                action.title.localizedCaseInsensitiveContains(searchText) ||
                action.subtitle.localizedCaseInsensitiveContains(searchText) ||
                action.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - 快速操作面板控制
    
    func showQuickActionPanel() {
        isQuickActionPanelVisible = true
    }
    
    func hideQuickActionPanel() {
        isQuickActionPanelVisible = false
        searchText = ""
    }
    
    func toggleQuickActionPanel() {
        isQuickActionPanelVisible.toggle()
        if !isQuickActionPanelVisible {
            searchText = ""
        }
    }
    
    // MARK: - 操作执行
    
    func executeAction(_ action: QuickAction) async {
        // 添加到最近使用
        addToRecentActions(action)
        
        // 隐藏面板
        hideQuickActionPanel()
        
        // 执行操作
        await action.action()
    }
    
    private func addToRecentActions(_ action: QuickAction) {
        // 移除已存在的相同操作
        recentActions.removeAll { $0.id == action.id }
        
        // 添加到开头
        recentActions.insert(action, at: 0)
        
        // 限制数量
        if recentActions.count > maxRecentActions {
            recentActions = Array(recentActions.prefix(maxRecentActions))
        }
        
        // 保存到UserDefaults
        saveRecentActions()
    }
    
    // MARK: - 收藏操作管理
    
    func toggleFavorite(_ action: QuickAction) {
        if favoriteActions.contains(where: { $0.id == action.id }) {
            favoriteActions.removeAll { $0.id == action.id }
        } else {
            favoriteActions.append(action)
        }
        saveFavoriteActions()
    }
    
    func isFavorite(_ action: QuickAction) -> Bool {
        return favoriteActions.contains { $0.id == action.id }
    }
    
    // MARK: - 数据持久化
    
    private func saveRecentActions() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(recentActions.map { $0.id }) {
            UserDefaults.standard.set(data, forKey: "QuickOperations.RecentActions")
        }
    }
    
    private func loadRecentActions() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "QuickOperations.RecentActions"),
           let actionIds = try? decoder.decode([String].self, from: data) {
            recentActions = actionIds.compactMap { id in
                allActions.first { $0.id == id }
            }
        }
    }
    
    private func saveFavoriteActions() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(favoriteActions.map { $0.id }) {
            UserDefaults.standard.set(data, forKey: "QuickOperations.FavoriteActions")
        }
    }
    
    private func loadFavoriteActions() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "QuickOperations.FavoriteActions"),
           let actionIds = try? decoder.decode([String].self, from: data) {
            favoriteActions = actionIds.compactMap { id in
                allActions.first { $0.id == id }
            }
        }
    }

    // MARK: - 操作实现

    // 产品操作
    private func addProduct() async {
        NotificationCenter.default.post(name: .createNewProduct, object: nil)
    }

    private func quickAddProduct() async {
        NotificationCenter.default.post(name: .showQuickAddProduct, object: nil)
    }

    private func scanProduct() async {
        NotificationCenter.default.post(name: .showScanProduct, object: nil)
    }

    // 搜索操作
    private func searchProducts() async {
        NotificationCenter.default.post(name: .focusSearchBar, object: nil)
    }

    private func searchManuals() async {
        NotificationCenter.default.post(name: .showManualSearch, object: nil)
    }

    // 批量操作
    private func batchEdit() async {
        NotificationCenter.default.post(name: .showBatchEdit, object: nil)
    }

    private func batchDelete() async {
        NotificationCenter.default.post(name: .showBatchDelete, object: nil)
    }

    private func batchExport() async {
        NotificationCenter.default.post(name: .showBatchExport, object: nil)
    }

    // 导航操作
    private func gotoDashboard() async {
        NotificationCenter.default.post(name: .navigateToDashboard, object: nil)
    }

    private func gotoProducts() async {
        NotificationCenter.default.post(name: .navigateToProducts, object: nil)
    }

    private func gotoCategories() async {
        NotificationCenter.default.post(name: .navigateToCategories, object: nil)
    }

    private func gotoSettings() async {
        NotificationCenter.default.post(name: .navigateToSettings, object: nil)
    }

    // 数据操作
    private func syncData() async {
        NotificationCenter.default.post(name: .performSync, object: nil)
    }

    private func backupData() async {
        NotificationCenter.default.post(name: .performBackup, object: nil)
    }

    private func importData() async {
        NotificationCenter.default.post(name: .showImportData, object: nil)
    }

    // 分析操作
    private func showUsageAnalysis() async {
        NotificationCenter.default.post(name: .showUsageAnalysis, object: nil)
    }

    private func showCostAnalysis() async {
        NotificationCenter.default.post(name: .showCostAnalysis, object: nil)
    }
}

// MARK: - 快速操作模型

struct QuickAction: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let category: QuickActionCategory
    let keyboardShortcut: String?
    let action: () async -> Void

    init(id: String, title: String, subtitle: String, icon: String, category: QuickActionCategory, keyboardShortcut: String? = nil, action: @escaping () async -> Void) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.category = category
        self.keyboardShortcut = keyboardShortcut
        self.action = action
    }

    // Codable 实现
    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, icon, category, keyboardShortcut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        icon = try container.decode(String.self, forKey: .icon)
        category = try container.decode(QuickActionCategory.self, forKey: .category)
        keyboardShortcut = try container.decodeIfPresent(String.self, forKey: .keyboardShortcut)
        action = { }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(icon, forKey: .icon)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(keyboardShortcut, forKey: .keyboardShortcut)
    }
}

enum QuickActionCategory: String, CaseIterable, Codable {
    case product = "产品"
    case search = "搜索"
    case batch = "批量操作"
    case navigation = "导航"
    case data = "数据"
    case analysis = "分析"

    var icon: String {
        switch self {
        case .product: return "cube.box"
        case .search: return "magnifyingglass"
        case .batch: return "square.stack.3d.up"
        case .navigation: return "arrow.left.arrow.right"
        case .data: return "externaldrive"
        case .analysis: return "chart.bar"
        }
    }

    var color: Color {
        switch self {
        case .product: return .blue
        case .search: return .green
        case .batch: return .orange
        case .navigation: return .purple
        case .data: return .red
        case .analysis: return .pink
        }
    }
}

// MARK: - 通知扩展

extension Notification.Name {
    static let createNewProduct = Notification.Name("CreateNewProduct")
    static let showQuickAddProduct = Notification.Name("ShowQuickAddProduct")
    static let showScanProduct = Notification.Name("ShowScanProduct")
    static let focusSearchBar = Notification.Name("FocusSearchBar")
    static let showManualSearch = Notification.Name("ShowManualSearch")
    static let showBatchEdit = Notification.Name("ShowBatchEdit")
    static let showBatchDelete = Notification.Name("ShowBatchDelete")
    static let showBatchExport = Notification.Name("ShowBatchExport")
    static let navigateToDashboard = Notification.Name("NavigateToDashboard")
    static let navigateToProducts = Notification.Name("NavigateToProducts")
    static let navigateToCategories = Notification.Name("NavigateToCategories")
    static let navigateToSettings = Notification.Name("NavigateToSettings")
    static let performSync = Notification.Name("PerformSync")
    static let performBackup = Notification.Name("PerformBackup")
    static let showImportData = Notification.Name("ShowImportData")
    static let showUsageAnalysis = Notification.Name("ShowUsageAnalysis")
    static let showCostAnalysis = Notification.Name("ShowCostAnalysis")
    static let focusProductSearch = Notification.Name("FocusProductSearch")
}
