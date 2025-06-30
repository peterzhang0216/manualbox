//
//  MainTabView.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import SwiftUI
import CoreData
import Foundation
import Combine

struct MainTabView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("accentColor") private var accentColorKey: String = "accentColor"
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var notificationManager: AppNotificationManager
    @StateObject private var notificationObserver = NotificationObserver()
    
    @State var selectedTab: SelectionValue? = .main(0)
    @State var selectedProduct: Product? = nil
    
    // 产品相关状态
    @State var searchText = ""
    @State var isEditing = false
    
    // 设置状态管理
    @StateObject var settingsViewModel: SettingsViewModel
    
    // 产品选择管理器
    @StateObject private var productSelectionManager: ProductSelectionManager
    
    // 详情面板状态管理器
    @StateObject private var detailPanelStateManager = DetailPanelStateManager()
    
    // 初始化器
    init() {
        let context = PersistenceController.shared.container.viewContext
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(viewContext: context))
        _productSelectionManager = StateObject(wrappedValue: ProductSelectionManager(viewContext: context))
    }
    
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) var categoriesRaw: FetchedResults<Category>
    
    // 自定义排序的分类列表，确保"其他"在最后
    var categories: [Category] {
        return categoriesRaw.sorted { category1, category2 in
            let priority1 = category1.sortPriority
            let priority2 = category2.sortPriority
            
            if priority1 != priority2 {
                return priority1 < priority2
            } else {
                return category1.categoryName < category2.categoryName
            }
        }
    }
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) var tags: FetchedResults<Tag>
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Product.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \Product.createdAt, ascending: false)
        ],
        animation: .default
    )
    var products: FetchedResults<Product>
    
    // 计算属性：过滤后的产品列表
    var filteredProducts: [Product] {
        return Array(products).filter { product in
            if searchText.isEmpty {
                return true
            }
            let searchLower = searchText.lowercased()
            return product.name?.lowercased().contains(searchLower) == true ||
                   product.brand?.lowercased().contains(searchLower) == true ||
                   product.model?.lowercased().contains(searchLower) == true
        }
    }
    
    // 上下文感知的默认值
    func getContextualDefaults() -> (Category?, Tag?) {
        guard let selectedTab = selectedTab else {
            return (nil, nil) // 在"所有商品"页面，不设置默认值
        }
        
        switch selectedTab {
        case .main(_):
            // 在主页面（所有商品、分类管理、标签管理等），不设置默认值
            return (nil, nil)
        case .category(let id):
            // 在特定分类页面，设置该分类为默认值
            let category = categories.first(where: { $0.id == id })
            return (category, nil)
        case .tag(let id):
            // 在特定标签页面，设置该标签为默认值
            let tag = tags.first(where: { $0.id == id })
            return (nil, tag)
        case .settings:
            // 在设置页面，不设置默认值
            return (nil, nil)
        }
    }
    
    var body: some View {
        mainView
            .preferredColorScheme(computedColorScheme)
            .accentColor(computedAccentColor)
            .environmentObject(detailPanelStateManager)
            .quickOperationsPanel()
            .enhancedKeyboardShortcuts()
            .toolbar(content: {
                ToolbarItemGroup(placement: .primaryAction) {
                    NavigationLink(destination: UsageGuideListView()) {
                        Label("使用指南", systemImage: "doc.text.below.ecg")
                    }
                    
                    NavigationLink(destination: WarrantyManagementView()) {
                        Label("保修管理", systemImage: "shield.checkered")
                    }
                    
                    NavigationLink(destination: ProductValuationView()) {
                        Label("产品估值", systemImage: "chart.bar.doc.horizontal")
                    }
                    
                    Button(action: {
                        QuickOperationsService.shared.showQuickActionPanel()
                    }) {
                        Label("快速操作", systemImage: "command")
                    }
                    .keyboardShortcut("k", modifiers: .command)
                    
                    Button(action: {
                        let (defaultCategory, defaultTag) = getContextualDefaults()
                        detailPanelStateManager.showAddProduct(defaultCategory: defaultCategory, defaultTag: defaultTag)
                    }) {
                        Label("添加产品", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            })
            .onAppNotification(.createNewProduct) { _ in
                let (defaultCategory, defaultTag) = getContextualDefaults()
                detailPanelStateManager.showAddProduct(defaultCategory: defaultCategory, defaultTag: defaultTag)
            }
            .onAppNotification(.showQuickAddProduct) { _ in
                let (defaultCategory, defaultTag) = getContextualDefaults()
                detailPanelStateManager.showQuickAddProduct(defaultCategory: defaultCategory, defaultTag: defaultTag)
            }
            .onAppNotification(.focusSearchBar) { _ in
                // 聚焦搜索栏的逻辑
                NotificationCenter.default.post(name: .focusProductSearch, object: nil)
            }
            .onAppNotification(.performSync) { _ in
                // 执行同步的逻辑
                Task {
                    await CloudKitSyncService.shared.performManualSync()
                }
            }
            .onAppear {
                notificationManager.updateAllWarrantyReminders(in: viewContext)
                setupNotificationObservers()
                setupProductSelectionObserver()
                
                // 初始化产品选择
                productSelectionManager.send(.updateAvailableProducts(Array(products)))
                productSelectionManager.smartSelectProduct(from: filteredProducts, context: .default)
            }
            .onChange(of: detailPanelStateManager.currentState) { oldState, newState in
                handleDetailPanelStateChange(newState)
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                // 当选中的标签页改变时，清空选中的商品
                if oldValue != newValue {
                    productSelectionManager.send(.clearSelection)
                    selectedProduct = nil
                }
            }
            .onChange(of: filteredProducts) { oldValue, newValue in
                // 当筛选结果改变时，更新产品选择管理器
                productSelectionManager.send(.updateFilteredProducts(newValue))
            }
            .onChange(of: Array(products)) { oldValue, newValue in
                // 当产品列表改变时，更新可用产品
                productSelectionManager.send(.updateAvailableProducts(newValue))
            }
    }
    
    // MARK: - 主视图
    
    private var mainView: some View {
        UnifiedSplitView(
            selection: $selectedTab,
            selectedItem: $selectedProduct,
            sidebar: { sidebarContent },
            content: { contentView },
            detail: { detailView }
        )
    }
    
    @ViewBuilder
    private var sidebarContent: some View {
        #if os(macOS)
        SidebarView(selection: $selectedTab)
        #else
        EmptyView()
        #endif
    }
    
    // 用于存储Combine订阅
    @State private var cancellables = Set<AnyCancellable>()
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AppNotificationManager())
    }
}