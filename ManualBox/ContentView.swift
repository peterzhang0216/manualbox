//
//  ContentView.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
#if os(iOS)
    @Environment(\.editMode) private var editMode
#else
    @State private var isEditing = false
#endif
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchFilters = SearchFilters()
    @State private var showingFilterSheet = false
    
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
        var result = Array(products)
        
        // 首先应用搜索文本过滤
        if !searchText.isEmpty {
            result = result.filter { product in
                var shouldInclude = false
                let searchLower = searchText.lowercased()
                
                // 根据搜索范围设置进行过滤
                if searchFilters.searchInName, let name = product.name?.lowercased(), name.contains(searchLower) {
                    shouldInclude = true
                }
                
                if searchFilters.searchInBrand, let brand = product.brand?.lowercased(), brand.contains(searchLower) {
                    shouldInclude = true
                }
                
                if searchFilters.searchInModel, let model = product.model?.lowercased(), model.contains(searchLower) {
                    shouldInclude = true
                }
                
                if searchFilters.searchInNotes, let notes = product.notes?.lowercased(), notes.contains(searchLower) {
                    shouldInclude = true
                }
                
                return shouldInclude
            }
        }
        
        // 应用分类筛选
        if searchFilters.filterByCategory, !searchFilters.selectedCategoryID.isEmpty {
            result = result.filter { product in
                guard let categoryID = product.category?.id?.uuidString else { return false }
                return categoryID == searchFilters.selectedCategoryID
            }
        }
        
        // 应用标签筛选
        if searchFilters.filterByTag, !searchFilters.selectedTagIDs.isEmpty {
            result = result.filter { product in
                guard let tags = product.tags as? Set<Tag> else { return false }
                return tags.contains { tag in
                    guard let tagID = tag.id?.uuidString else { return false }
                    return searchFilters.selectedTagIDs.contains(tagID)
                }
            }
        }
        
        // 应用保修状态筛选
        if searchFilters.filterByWarranty, searchFilters.warrantyStatus != -1 {
            result = result.filter { product in
                guard let order = product.order, let warrantyEndDate = order.warrantyEndDate else {
                    return false
                }
                
                let now = Date()
                let calendar = Calendar.current
                let days = calendar.numberOfDaysBetween(now, and: warrantyEndDate)
                
                switch searchFilters.warrantyStatus {
                case 0: // 在保修期内
                    return days > 0
                case 1: // 即将过期 (30天内)
                    return days > 0 && days <= 30
                case 2: // 已过期
                    return days <= 0
                default:
                    return true
                }
            }
        }
        
        // 应用日期筛选
        if searchFilters.filterByDate {
            result = result.filter { product in
                guard let order = product.order, let orderDate = order.orderDate else {
                    return false
                }
                
                // 为了包含结束日期当天，需要将结束日期设置为当天的结束时间
                let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: searchFilters.endDate) ?? searchFilters.endDate
                
                return orderDate >= searchFilters.startDate && orderDate <= endOfDay
            }
        }
        
        return result
    }
    
    @State private var showingAddProduct = false
    
#if os(macOS)
    @State private var toggleEditModeSubscriber: NSObjectProtocol? = nil
#endif
    
    var body: some View {
#if os(macOS)
        NavigationSplitView {
            VStack(spacing: 0) {
                // 搜索栏
                searchBarView
                // 产品列表
                List {
                    ForEach(filteredProducts, id: \.self) { product in
                        NavigationLink(destination: ProductDetailView(product: product)) {
                            ProductRowView(product: product)
                        }
                    }
                    .onDelete(perform: isEditing ? deleteProducts : nil)
                }
                .listStyle(SidebarListStyle())
            }
        } detail: {
            VStack(spacing: 32) {
                Image(systemName: "shippingbox.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.accentColor)
                Text("请选择一个产品")
                    .font(.title2)
                    .bold()
                Text("在左侧选择或新建一个产品以查看详情")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.7))
            .navigationTitle("产品详情")
        }
        .onAppear {
            // 在视图出现时注册通知
            toggleEditModeSubscriber = NotificationCenter.default.addObserver(
                forName: Notification.Name("ToggleEditMode"),
                object: nil,
                queue: .main) { _ in
                    isEditing.toggle()
                }
        }
        .onDisappear {
            // 在视图消失时移除通知观察者
            if let subscriber = toggleEditModeSubscriber {
                NotificationCenter.default.removeObserver(subscriber)
            }
        }
#else
        NavigationSplitView {
            VStack(spacing: 0) {
                // 搜索栏
                searchBarView
                
                // 产品列表
                List {
                    ForEach(filteredProducts, id: \.self) { product in
                        NavigationLink(destination: ProductDetailView(product: product)) {
                            ProductRowView(product: product)
                        }
                    }
                    .onDelete(perform: deleteProducts)
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("ManualBox")
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    EditButton()
                        .buttonStyle(.borderedProminent)
                    Button {
                        showingAddProduct = true
                    } label: {
                        Label("添加产品", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .sheet(isPresented: $showingAddProduct) {
                NavigationStack {
                    AddProductView(isPresented: $showingAddProduct)
                        .environment(\.managedObjectContext, viewContext)
                }
                .presentationDetents([.large])
            }
            .overlay(Group {
                if filteredProducts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: searchText.isEmpty ? "shippingbox" : "magnifyingglass")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.accentColor)
                        Text(searchText.isEmpty ? "没有产品" : "未找到匹配结果")
                            .font(.title2)
                            .bold()
                        Text(searchText.isEmpty ?
                             "点击右上角 + 按钮添加产品" :
                                "请尝试其他搜索关键词")
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground))
                }
            })
        } detail: {
            VStack(spacing: 32) {
                Image(systemName: "shippingbox.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.accentColor)
                Text("请选择一个产品")
                    .font(.title2)
                    .bold()
                Text("在左侧选择或新建一个产品以查看详情")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.windowBackgroundColor).opacity(0.7))
            .navigationTitle("产品详情")
        }
#endif
    }

    // MARK: - 搜索栏
    var searchBarView: some View {
        VStack(spacing: 0) {
            HStack {
#if os(iOS)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索产品...", text: $searchText)
                        .submitLabel(.search)
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: {
                        showingFilterSheet = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(searchFilters.hasActiveFilters ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
#else
                // macOS 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索产品...", text: $searchText)
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: {
                        showingFilterSheet = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(searchFilters.hasActiveFilters ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)
#endif
            }
            // 如果有活跃的筛选器，显示筛选器摘要
            if searchFilters.hasActiveFilters {
                HStack {
                    Text("筛选条件:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(searchFilters.filterDescription)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Spacer()
                    Button(action: {
                        searchFilters = SearchFilters()
                    }) {
                        Text("清除")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            SearchFilterView(searchFilters: $searchFilters)
        }
    }

    // 删除产品
    func deleteProducts(offsets: IndexSet) {
        withAnimation {
            do {
                let productsToDelete = offsets.map { filteredProducts[$0] }
                // 显示删除确认对话框
#if os(iOS)
                let alert = UIAlertController(
                    title: "确认删除",
                    message: "确定要删除选中的\(productsToDelete.count)个产品吗？此操作不可恢复。",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "取消", style: .cancel))
                alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
                    deleteConfirmed(products: productsToDelete)
                })
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let viewController = windowScene.windows.first?.rootViewController {
                    viewController.present(alert, animated: true)
                }
#else
                let alert = NSAlert()
                alert.messageText = "确认删除"
                alert.informativeText = "确定要删除选中的\(productsToDelete.count)个产品吗？此操作不可恢复。"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "删除")
                alert.addButton(withTitle: "取消")
                if alert.runModal() == .alertFirstButtonReturn {
                    deleteConfirmed(products: productsToDelete)
                }
#endif
            }
        }
    }

    func deleteConfirmed(products: [Product]) {
        for product in products {
            viewContext.delete(product)
        }
        do {
            try viewContext.save()
        } catch {
            // 显示错误提示
#if os(iOS)
            let alert = UIAlertController(
                title: "删除失败",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                viewController.present(alert, animated: true)
            }
#else
            let alert = NSAlert(error: error)
            alert.alertStyle = .critical
            alert.runModal()
#endif
        }
    }

    // MARK: - 子视图提取
    struct ProductRowView: View {
        let product: Product
        
        var body: some View {
            HStack(spacing: 16) {
                // 产品图片
                Group {
                    if let imageData = product.imageData,
                       let uiImage = PlatformImage(data: imageData) {
                        Image(platformImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "shippingbox")
                            .foregroundColor(.accentColor)
                    }
                }
                .frame(width: 48, height: 48)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // 产品信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name ?? "未命名产品")
                        .font(.headline)
                    
                    HStack {
                        if let brand = product.brand {
                            Text(brand)
                                .foregroundColor(.secondary)
                        }
                        if let model = product.model {
                            Text("・\(model)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.caption)
                    
                    // 保修状态
                    if let order = product.order,
                       let warrantyEnd = order.warrantyEndDate {
                        HStack {
                            let daysRemaining = Calendar.current.numberOfDaysBetween(Date(), and: warrantyEnd)
                            if daysRemaining > 0 {
                                Label("还剩 \(daysRemaining) 天", systemImage: "clock")
                                    .foregroundColor(.green)
                            } else {
                                Label("已过保", systemImage: "exclamationmark.triangle")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.caption)
                    }
                }
                
                Spacer()
                
                // 右侧分类标签
                if let category = product.category {
                    Label(category.name ?? "", systemImage: category.icon ?? "folder")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
#if os(iOS)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
#else
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
#endif
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
