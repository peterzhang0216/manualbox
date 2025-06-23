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

// 创建 EnvironmentKey 传递选中产品状态
struct SelectedProductKey: EnvironmentKey {
    static var defaultValue: Binding<Product?> = .constant(nil)
}

extension EnvironmentValues {
    var selectedProduct: Binding<Product?> {
        get { self[SelectedProductKey.self] }
        set { self[SelectedProductKey.self] = newValue }
    }
}

struct MainTabView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("accentColor") private var accentColorKey: String = "accentColor"
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var notificationManager: AppNotificationManager
    @StateObject private var notificationObserver = NotificationObserver()

    @State private var selectedTab: SelectionValue? = .main(0)
    @State private var selectedProduct: Product? = nil

    // 产品相关状态
    @State private var searchText = ""
    @State private var isEditing = false

    // 设置状态管理
    @StateObject private var settingsViewModel: SettingsViewModel

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
    ) private var categoriesRaw: FetchedResults<Category>

    // 自定义排序的分类列表，确保"其他"在最后
    private var categories: [Category] {
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
    ) private var tags: FetchedResults<Tag>
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Product.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \Product.createdAt, ascending: false)
        ],
        animation: .default
    )
    private var products: FetchedResults<Product>
    
    // 计算属性：过滤后的产品列表
    private var filteredProducts: [Product] {
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
    
    // 删除产品函数
    private func deleteProducts(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredProducts[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                // 处理错误
                print("删除产品失败: \(error)")
            }
        }
    }
    
    var body: some View {
        mainView
            .preferredColorScheme(computedColorScheme)
            .accentColor(computedAccentColor)
            .environmentObject(detailPanelStateManager)
        .toolbar(content: {
            SwiftUI.ToolbarItem(placement: .primaryAction) {
                Button(action: { detailPanelStateManager.showAddProduct() }) {
                    Label("添加产品", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        })
        .onAppNotification(.createNewProduct) { _ in
            detailPanelStateManager.showAddProduct()
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

    // MARK: - 计算属性

    private var computedColorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var computedAccentColor: Color {
        switch accentColorKey {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        case "red": return .red
        default: return .accentColor
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

    @ViewBuilder
    private var contentView: some View {
        ZStack {
            if let selection = selectedTab {
                contentForSelection(selection)
            } else {
                defaultProductListView
            }
        }
    }

    @ViewBuilder
    private func contentForSelection(_ selection: SelectionValue) -> some View {
        switch selection {
        case .main(let index):
            mainContentView(for: index)
        case .category(let id):
            categoryContentView(for: id)
        case .tag(let id):
            tagContentView(for: id)
        case .settings(let panel):
            settingsDetailView(for: panel)
        }
    }

    @ViewBuilder
    private func mainContentView(for index: Int) -> some View {
        switch index {
        case 0:
            productListView
        case 1:
            categoryPlaceholderView
        case 2:
            tagPlaceholderView
        case 3:
            RepairRecordsView()
        default:
            defaultProductListView
        }
    }

    @ViewBuilder
    private func categoryContentView(for id: UUID) -> some View {
        if let category = categories.first(where: { $0.id == id }) {
            CategoryDetailView(category: category)
                .environment(\.selectedProduct, $selectedProduct)
                .productSelectionManager(productSelectionManager)
                .adaptiveLayout()
        } else {
            productListView
        }
    }

    @ViewBuilder
    private func tagContentView(for id: UUID) -> some View {
        if let tag = tags.first(where: { $0.id == id }) {
            TagDetailView(tag: tag)
                .environment(\.selectedProduct, $selectedProduct)
                .productSelectionManager(productSelectionManager)
                .adaptiveLayout()
        } else {
            productListView
        }
    }

    @ViewBuilder
    private var productListView: some View {
        EnhancedProductListView(
            filteredProducts: filteredProducts,
            searchText: searchText,
            deleteProducts: deleteProducts
        )
        .environment(\.selectedProduct, $selectedProduct)
        .productSelectionManager(productSelectionManager)
        .adaptiveLayout()
    }

    @ViewBuilder
    private var defaultProductListView: some View {
        EnhancedProductListView(
            filteredProducts: filteredProducts,
            searchText: searchText,
            deleteProducts: deleteProducts
        )
        .environment(\.selectedProduct, $selectedProduct)
        .productSelectionManager(productSelectionManager)
    }

    @ViewBuilder
    private var categoryPlaceholderView: some View {
        // 根据详情面板状态决定显示内容
        if detailPanelStateManager.currentState == .addCategory ||
           detailPanelStateManager.currentState.isEditingCategory {
            CategoriesView()
                .environment(\.selectedProduct, $selectedProduct)
                .productSelectionManager(productSelectionManager)
                .adaptiveLayout()
        } else {
            ContentUnavailableView {
                Label("分类管理", systemImage: "folder")
            } description: {
                Text("请从左侧选择一个分类查看相关产品，或点击右上角的 + 按钮添加新分类")
            } actions: {
                Button("添加分类") {
                    detailPanelStateManager.showAddCategory()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 20)
        }
    }

    @ViewBuilder
    private var tagPlaceholderView: some View {
        // 根据详情面板状态决定显示内容
        if detailPanelStateManager.currentState == .addTag ||
           detailPanelStateManager.currentState.isEditingTag {
            TagsView()
                .environment(\.selectedProduct, $selectedProduct)
                .productSelectionManager(productSelectionManager)
                .adaptiveLayout()
        } else {
            ContentUnavailableView {
                Label("标签管理", systemImage: "tag")
            } description: {
                Text("请从左侧选择一个标签查看相关产品，或点击右上角的 + 按钮添加新标签")
            } actions: {
                Button("添加标签") {
                    detailPanelStateManager.showAddTag()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 20)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        UnifiedDetailPanel()
            .environmentObject(detailPanelStateManager)
    }

    @ViewBuilder
    private func detailForSelection(_ selection: SelectionValue) -> some View {
        switch selection {
        case .main(let index):
            mainDetailView(for: index)
        case .settings(let panel):
            settingsDetailPanelView(for: panel)
        case .category(let id):
            categoryDetailView(for: id)
        case .tag(let id):
            tagDetailView(for: id)
        }
    }

    @ViewBuilder
    private func mainDetailView(for index: Int) -> some View {
        switch index {
        case 0:
            productDetailOrPlaceholder
        case 1:
            CategoryDetailView(category: categories.first ?? Category(context: viewContext))
        case 2:
            TagDetailView(tag: tags.first ?? Tag(context: viewContext))
        case 3:
            EmptyView()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func categoryDetailView(for id: UUID) -> some View {
        if let category = categories.first(where: { $0.id == id }) {
            if let product = selectedProduct {
                ProductDetailView(product: product)
                    .id(product.id?.uuidString ?? "unknown")
            } else {
                ContentUnavailableView {
                    Label("请选择产品", systemImage: "hand.tap")
                } description: {
                    Text("从左侧\"\(category.categoryName)\"分类中选择一个产品查看详情")
                }
                .padding(.top, 20)
            }
        }
    }

    @ViewBuilder
    private func tagDetailView(for id: UUID) -> some View {
        if let tag = tags.first(where: { $0.id == id }) {
            if let product = selectedProduct {
                ProductDetailView(product: product)
                    .id(product.id?.uuidString ?? "unknown")
            } else {
                ContentUnavailableView {
                    Label("请选择产品", systemImage: "hand.tap")
                } description: {
                    Text("从左侧\"\(tag.tagName)\"标签中选择一个产品查看详情")
                }
                .padding(.top, 20)
            }
        }
    }

    @ViewBuilder
    private var productDetailOrPlaceholder: some View {
        if let product = selectedProduct {
            ProductDetailView(product: product)
                .id(product.id?.uuidString ?? "unknown")
        } else {
            ContentUnavailableView {
                Label("暂无选中商品", systemImage: "shippingbox")
            } description: {
                Text("请从列表中选择一个商品查看详情")
            }
            .padding(.top, 20)
        }
    }

    @ViewBuilder
    private var emptyDetailView: some View {
        ContentUnavailableView {
            Label("暂无选中内容", systemImage: "square.3.layers.3d")
        } description: {
            Text("请从左侧选择要查看的内容")
        }
        .padding(.top, 20)
    }

    // 设置详情视图（中间栏）
    @ViewBuilder
    private func settingsDetailView(for panel: SettingsPanel) -> some View {
        // 直接根据传入的panel参数显示对应的设置面板，而不依赖于viewModel的selectedPanel
        Group {
            switch panel {
            case .notification:
                NotificationAdvancedSettingsPanel()
                    .environmentObject(settingsViewModel)
            case .theme:
                ThemeSettingsPanel()
                    .environmentObject(settingsViewModel)
            case .data:
                DataSettingsPanel(
                    defaultWarrantyPeriod: Binding(
                        get: { settingsViewModel.defaultWarrantyPeriod },
                        set: { period in
                            Task {
                                settingsViewModel.send(.updateDefaultWarrantyPeriod(period))
                            }
                        }
                    ),
                    enableOCRByDefault: Binding(
                        get: { settingsViewModel.enableOCRByDefault },
                        set: { enabled in
                            Task {
                                settingsViewModel.send(.updateEnableOCRByDefault(enabled))
                            }
                        }
                    )
                )
            case .about:
                AboutSettingsPanel(
                    showPrivacySheet: Binding(
                        get: { settingsViewModel.showPrivacySheet },
                        set: { show in
                            Task {
                                settingsViewModel.send(.togglePrivacySheet)
                            }
                        }
                    ),
                    showAgreementSheet: Binding(
                        get: { settingsViewModel.showAgreementSheet },
                        set: { show in
                            Task {
                                settingsViewModel.send(.toggleAgreementSheet)
                            }
                        }
                    )
                )
            }
        }
        .id(panel.rawValue) // 确保面板切换时视图刷新
        .onAppear {
            // 同步选中的面板到ViewModel，用于右侧栏显示
            Task {
                settingsViewModel.send(.selectPanel(panel))
            }
        }
    }

    // 设置详情面板视图（右侧栏）
    @ViewBuilder
    private func settingsDetailPanelView(for panel: SettingsPanel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // 面板标题
            HStack {
                Image(systemName: panel.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(panel.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            // 面板描述和快速操作
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch panel {
                    case .notification:
                        settingsNotificationSummary()
                    case .theme:
                        settingsThemeSummary()
                    case .data:
                        settingsDataSummary()
                    case .about:
                        settingsAboutSummary()
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - 设置面板摘要视图

    @ViewBuilder
    private func settingsNotificationSummary() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("通知设置概览")
                .font(.headline)
                .foregroundColor(.primary)

            Text("管理应用通知偏好，包括保修提醒、维修通知等。")
                .font(.body)
                .foregroundColor(.secondary)

            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(.orange)
                Text("通知状态: \(settingsViewModel.enableNotifications ? "已启用" : "已禁用")")
                    .font(.subheadline)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private func settingsThemeSummary() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("外观设置概览")
                .font(.headline)
                .foregroundColor(.primary)

            Text("自定义应用外观，包括主题模式、强调色等。")
                .font(.body)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundColor(.purple)
                    Text("主题: \(themeDisplayName)")
                        .font(.subheadline)
                    Spacer()
                }

                HStack {
                    Image(systemName: "paintbrush.pointed")
                        .foregroundColor(.accentColor)
                    Text("强调色: \(accentColorDisplayName)")
                        .font(.subheadline)
                    Spacer()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private func settingsDataSummary() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据设置概览")
                .font(.headline)
                .foregroundColor(.primary)

            Text("管理默认设置和数据，包括保修期、OCR等。")
                .font(.body)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("默认保修期: \(settingsViewModel.defaultWarrantyPeriod)个月")
                        .font(.subheadline)
                    Spacer()
                }

                HStack {
                    Image(systemName: "doc.text.viewfinder")
                        .foregroundColor(.green)
                    Text("OCR识别: \(settingsViewModel.enableOCRByDefault ? "默认启用" : "默认禁用")")
                        .font(.subheadline)
                    Spacer()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private func settingsAboutSummary() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关于应用")
                .font(.headline)
                .foregroundColor(.primary)

            Text("查看应用信息、版本号、隐私政策等。")
                .font(.body)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("ManualBox")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.green)
                    Text("隐私保护")
                        .font(.subheadline)
                    Spacer()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - 辅助计算属性

    private var themeDisplayName: String {
        switch appTheme {
        case "light": return "浅色"
        case "dark": return "深色"
        default: return "跟随系统"
        }
    }

    private var accentColorDisplayName: String {
        switch accentColorKey {
        case "blue": return "蓝色"
        case "green": return "绿色"
        case "orange": return "橙色"
        case "pink": return "粉色"
        case "purple": return "紫色"
        case "red": return "红色"
        default: return "系统默认"
        }
    }

    private func setupNotificationObservers() {
        // 产品导航通知
        notificationObserver.observe(.showProduct) { object in
            if let _ = object as? UUID,
               case let currentValue = selectedTab,
               !(currentValue == nil || (currentValue != nil && 
                    (currentValue! == .main(0) || 
                     (currentValue! == .main(1) && categories.isEmpty) || 
                     (currentValue! == .main(2) && tags.isEmpty)))) {
                // 如果不是在产品列表视图，则转到产品列表
                selectedTab = .main(0)
            }
        }
        
        // 分类导航通知
        notificationObserver.observe(.showCategory) { object in
            if let categoryId = object as? UUID,
               let _ = categories.first(where: { $0.id == categoryId }) {
                selectedTab = .category(categoryId)
            }
        }
        
        // 标签导航通知
        notificationObserver.observe(.showTag) { object in
            if let tagId = object as? UUID,
               let _ = tags.first(where: { $0.id == tagId }) {
                selectedTab = .tag(tagId)
            }
        }
    }

    private func setupProductSelectionObserver() {
        // 监听产品选择管理器的变化
        productSelectionManager.$currentProduct
            .receive(on: DispatchQueue.main)
            .sink { newProduct in
                selectedProduct = newProduct
                // 更新详情面板状态
                if let product = newProduct {
                    detailPanelStateManager.showProductDetail(product)
                } else {
                    detailPanelStateManager.reset()
                }
            }
            .store(in: &cancellables)
    }

    private func handleDetailPanelStateChange(_ state: DetailPanelState) {
        switch state {
        case .addCategory, .editCategory, .categoryDetail, .categoryList:
            // 当进入分类相关状态时，切换到分类管理页面
            selectedTab = .main(1)
        case .addTag, .editTag, .tagDetail, .tagList:
            // 当进入标签相关状态时，切换到标签管理页面
            selectedTab = .main(2)
        case .addProduct, .editProduct:
            // 当进入产品相关状态时，切换到产品列表页面
            selectedTab = .main(0)
        case .productDetail:
            // 产品详情不需要改变中间栏
            break
        case .empty:
            // 空状态不需要改变中间栏
            break
        }
    }

    // 用于存储Combine订阅
    @State private var cancellables = Set<AnyCancellable>()
}

#if os(macOS)
struct AddProductSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        AddProductView(isPresented: $isPresented)
            .frame(minWidth: 600, minHeight: 600) // 高度提升为 600，更适合表单
            .environment(\.managedObjectContext, viewContext)
            .formStyle(.grouped)
    }
}

// macOS 侧边栏视图
struct SidebarView: View {
    @Binding var selection: SelectionValue?
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var detailPanelStateManager: DetailPanelStateManager
    
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) private var categoriesRaw: FetchedResults<Category>

    // 自定义排序的分类列表，确保"其他"在最后
    private var categories: [Category] {
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
    ) private var tags: FetchedResults<Tag>
    
    var body: some View {
        List(selection: $selection) {
            Label("所有商品", systemImage: "shippingbox")
                .tag(SelectionValue.main(0))
                .accessibilityLabel("所有商品")
                .accessibilityHint("查看所有商品列表")
            
            Section(header: Text("分类")) {
                ForEach(categories) { category in
                    if let id = category.id {
                        Label(category.categoryName, systemImage: category.categoryIcon)
                            .badge(category.productCount)
                            .tag(SelectionValue.category(id))
                            .accessibilityLabel("\(category.categoryName)分类")
                            .accessibilityHint("查看\(category.categoryName)分类下的商品，共\(category.productCount)个")
                            .contextMenu {
                                Button(action: {
                                    detailPanelStateManager.showEditCategory(category)
                                }) {
                                    Label("编辑分类", systemImage: "pencil")
                                }

                                Divider()

                                Button(role: .destructive, action: {
                                    deleteCategory(category)
                                }) {
                                    Label("删除分类", systemImage: "trash")
                                }
                            }
                    }
                }

                // 添加分类按钮
                Button(action: { detailPanelStateManager.showAddCategory() }) {
                    Label("添加分类", systemImage: "plus")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加新分类")
                .accessibilityHint("点击添加新的商品分类")
            }
            
            Section(header: Text("标签")) {
                ForEach(tags) { tag in
                    if let id = tag.id {
                        Label {
                            Text(tag.tagName)
                                .badge(tag.productCount)
                        } icon: {
                            Image(systemName: "tag.fill")
                                .foregroundColor(tag.uiColor)
                        }
                        .tag(SelectionValue.tag(id))
                        .accessibilityLabel("\(tag.tagName)标签")
                        .accessibilityHint("查看\(tag.tagName)标签下的商品，共\(tag.productCount)个")
                        .contextMenu {
                            Button(action: {
                                detailPanelStateManager.showEditTag(tag)
                            }) {
                                Label("编辑标签", systemImage: "pencil")
                            }

                            Divider()

                            Button(role: .destructive, action: {
                                deleteTag(tag)
                            }) {
                                Label("删除标签", systemImage: "trash")
                            }
                        }
                    }
                }

                // 添加标签按钮
                Button(action: { detailPanelStateManager.showAddTag() }) {
                    Label("添加标签", systemImage: "plus")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加新标签")
                .accessibilityHint("点击添加新的商品标签")
            }
            
            Section(header: Text("维修管理")) {
                Label("维修记录", systemImage: "wrench.and.screwdriver")
                    .tag(SelectionValue.main(3))
                    .accessibilityLabel("维修记录")
                    .accessibilityHint("查看和管理设备维修记录")
            }

            // 设置项目
            Section(header: Text("设置")) {
                ForEach(SettingsPanel.allCases, id: \.self) { panel in
                    Label(panel.title, systemImage: panel.icon)
                        .tag(SelectionValue.settings(panel))
                        .accessibilityLabel(panel.title)
                        .accessibilityHint("打开\(panel.title)设置")
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 320) // maxWidth 统一为 320
        .accessibilityLabel("主导航")
        .accessibilityHint("选择要浏览的内容分类")
    }

    // MARK: - 删除操作
    private func deleteCategory(_ category: Category) {
        withAnimation {
            viewContext.delete(category)
            do {
                try viewContext.save()
            } catch {
                print("删除分类失败: \(error.localizedDescription)")
            }
        }
    }

    private func deleteTag(_ tag: Tag) {
        withAnimation {
            viewContext.delete(tag)
            do {
                try viewContext.save()
            } catch {
                print("删除标签失败: \(error.localizedDescription)")
            }
        }
    }
}
#endif

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AppNotificationManager())
    }
}
