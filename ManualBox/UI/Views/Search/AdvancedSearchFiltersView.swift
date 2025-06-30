import SwiftUI
import CoreData

// MARK: - 高级搜索过滤器视图
struct AdvancedSearchFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: AdvancedSearchFilters
    @State private var tempFilters: AdvancedSearchFilters
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default
    ) private var categories: FetchedResults<Category>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        animation: .default
    ) private var tags: FetchedResults<Tag>
    
    init(filters: Binding<AdvancedSearchFilters>) {
        self._filters = filters
        self._tempFilters = State(initialValue: filters.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 搜索范围
                searchScopeSection
                
                // 内容类型
                contentTypeSection
                
                // 分类筛选
                categorySection
                
                // 标签筛选
                tagSection
                
                // 时间范围
                dateRangeSection
                
                // 文件属性
                fileAttributesSection
                
                // 高级选项
                advancedOptionsSection
                
                // 重置按钮
                resetSection
            }
            .navigationTitle("高级筛选")
            #if os(iOS)
            .platformNavigationBarTitleDisplayMode(.inline)
            #else
            .platformNavigationBarTitleDisplayMode(0)
            #endif
            .platformToolbar(leading: {
                Button("取消") {
                    dismiss()
                }
            }, trailing: {
                Button("应用") {
                    applyFilters()
                }
            })
        }
    }
    
    // MARK: - 搜索范围
    private var searchScopeSection: some View {
        Section("搜索范围") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(AdvancedSearchScope.allCases, id: \.self) { scope in
                    HStack {
                        Image(systemName: scope.icon)
                            .foregroundColor(scope.color)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scope.displayName)
                                .font(.system(size: 15, weight: .medium))
                            
                            Text(scope.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { tempFilters.searchScopes.contains(scope) },
                            set: { isOn in
                                if isOn {
                                    tempFilters.searchScopes.insert(scope)
                                } else {
                                    tempFilters.searchScopes.remove(scope)
                                }
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - 内容类型
    private var contentTypeSection: some View {
        Section("内容类型") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ContentType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.icon)
                            .foregroundColor(type.color)
                            .frame(width: 20)
                        
                        Text(type.displayName)
                            .font(.system(size: 15, weight: .medium))
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { tempFilters.contentTypes.contains(type) },
                            set: { isOn in
                                if isOn {
                                    tempFilters.contentTypes.insert(type)
                                } else {
                                    tempFilters.contentTypes.remove(type)
                                }
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - 分类筛选
    private var categorySection: some View {
        Section("产品分类") {
            if categories.isEmpty {
                Text("暂无分类")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(categories, id: \.objectID) { category in
                    HStack {
                        Text(category.name ?? "未知分类")
                            .font(.system(size: 15))
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { 
                                tempFilters.selectedCategories.contains(category.objectID.uriRepresentation().absoluteString)
                            },
                            set: { isOn in
                                let categoryId = category.objectID.uriRepresentation().absoluteString
                                if isOn {
                                    tempFilters.selectedCategories.insert(categoryId)
                                } else {
                                    tempFilters.selectedCategories.remove(categoryId)
                                }
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    // MARK: - 标签筛选
    private var tagSection: some View {
        Section("标签") {
            if tags.isEmpty {
                Text("暂无标签")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(tags, id: \.objectID) { tag in
                        TagFilterChip(
                            tag: tag,
                            isSelected: tempFilters.selectedTags.contains(tag.objectID.uriRepresentation().absoluteString)
                        ) { isSelected in
                            let tagId = tag.objectID.uriRepresentation().absoluteString
                            if isSelected {
                                tempFilters.selectedTags.insert(tagId)
                            } else {
                                tempFilters.selectedTags.remove(tagId)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 时间范围
    private var dateRangeSection: some View {
        Section("时间范围") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("启用时间筛选", isOn: $tempFilters.enableDateFilter)
                
                if tempFilters.enableDateFilter {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("开始日期")
                                .font(.system(size: 14, weight: .medium))
                            
                            Spacer()
                            
                            DatePicker("", selection: $tempFilters.startDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("结束日期")
                                .font(.system(size: 14, weight: .medium))
                            
                            Spacer()
                            
                            DatePicker("", selection: $tempFilters.endDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    .padding(.leading, 16)
                }
            }
        }
    }
    
    // MARK: - 文件属性
    private var fileAttributesSection: some View {
        Section("文件属性") {
            VStack(alignment: .leading, spacing: 12) {
                // 文件大小
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("按文件大小筛选", isOn: $tempFilters.enableFileSizeFilter)
                    
                    if tempFilters.enableFileSizeFilter {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("最小大小")
                                    .font(.caption)
                                
                                Spacer()
                                
                                Text("\(Int(tempFilters.minFileSize)) MB")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $tempFilters.minFileSize, in: 0...100, step: 1)
                            
                            HStack {
                                Text("最大大小")
                                    .font(.caption)
                                
                                Spacer()
                                
                                Text("\(Int(tempFilters.maxFileSize)) MB")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $tempFilters.maxFileSize, in: 0...100, step: 1)
                        }
                        .padding(.leading, 16)
                    }
                }
                
                // OCR状态
                Picker("OCR状态", selection: $tempFilters.ocrStatus) {
                    Text("全部").tag(OCRStatus.all)
                    Text("已处理").tag(OCRStatus.processed)
                    Text("未处理").tag(OCRStatus.unprocessed)
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    // MARK: - 高级选项
    private var advancedOptionsSection: some View {
        Section("高级选项") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("模糊搜索", isOn: $tempFilters.enableFuzzySearch)
                Toggle("同义词搜索", isOn: $tempFilters.enableSynonymSearch)
                Toggle("正则表达式", isOn: $tempFilters.enableRegexSearch)
                Toggle("区分大小写", isOn: $tempFilters.caseSensitive)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("最大结果数")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        Text("\(tempFilters.maxResults)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(tempFilters.maxResults) },
                            set: { tempFilters.maxResults = Int($0) }
                        ),
                        in: 10...200,
                        step: 10
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("相关性阈值")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        Text(String(format: "%.1f", tempFilters.relevanceThreshold))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $tempFilters.relevanceThreshold, in: 0.0...1.0, step: 0.1)
                }
            }
        }
    }
    
    // MARK: - 重置按钮
    private var resetSection: some View {
        Section {
            Button(action: {
                tempFilters = AdvancedSearchFilters()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重置所有筛选条件")
                }
                .foregroundColor(.red)
            }
        }
    }
}

// MARK: - 标签筛选芯片
struct TagFilterChip: View {
    let tag: Tag
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: {
            onToggle(!isSelected)
        }) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                }
                
                Text(tag.name ?? "未知标签")
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            #if os(macOS)
            .background(isSelected ? Color.accentColor : Color(nsColor: .windowBackgroundColor))
            #else
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            #endif
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 高级搜索过滤器模型
struct AdvancedSearchFilters: Codable {
    var searchScopes: Set<AdvancedSearchScope> = Set(AdvancedSearchScope.allCases)
    var contentTypes: Set<ContentType> = Set(ContentType.allCases)
    var selectedCategories: Set<String> = []
    var selectedTags: Set<String> = []
    
    var enableDateFilter: Bool = false
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate: Date = Date()
    
    var enableFileSizeFilter: Bool = false
    var minFileSize: Double = 0
    var maxFileSize: Double = 100
    
    var ocrStatus: OCRStatus = .all
    
    var enableFuzzySearch: Bool = true
    var enableSynonymSearch: Bool = true
    var enableRegexSearch: Bool = false
    var caseSensitive: Bool = false
    
    var maxResults: Int = 50
    var relevanceThreshold: Double = 0.1
}

// MARK: - 搜索范围枚举
enum AdvancedSearchScope: String, CaseIterable, Codable {
    case productName = "product_name"
    case productBrand = "product_brand"
    case productModel = "product_model"
    case manualContent = "manual_content"
    case manualFileName = "manual_filename"
    case categoryName = "category_name"
    case tagName = "tag_name"
    
    var displayName: String {
        switch self {
        case .productName: return "产品名称"
        case .productBrand: return "产品品牌"
        case .productModel: return "产品型号"
        case .manualContent: return "说明书内容"
        case .manualFileName: return "文件名"
        case .categoryName: return "分类名称"
        case .tagName: return "标签名称"
        }
    }
    
    var description: String {
        switch self {
        case .productName: return "在产品名称中搜索"
        case .productBrand: return "在产品品牌中搜索"
        case .productModel: return "在产品型号中搜索"
        case .manualContent: return "在说明书文本内容中搜索"
        case .manualFileName: return "在文件名中搜索"
        case .categoryName: return "在分类名称中搜索"
        case .tagName: return "在标签名称中搜索"
        }
    }
    
    var icon: String {
        switch self {
        case .productName: return "cube.box"
        case .productBrand: return "building.2"
        case .productModel: return "number"
        case .manualContent: return "doc.text"
        case .manualFileName: return "doc"
        case .categoryName: return "folder"
        case .tagName: return "tag"
        }
    }
    
    var color: Color {
        switch self {
        case .productName: return .blue
        case .productBrand: return .green
        case .productModel: return .orange
        case .manualContent: return .purple
        case .manualFileName: return .red
        case .categoryName: return .yellow
        case .tagName: return .pink
        }
    }
}

// MARK: - 内容类型枚举
enum ContentType: String, CaseIterable, Codable {
    case manual = "manual"
    case warranty = "warranty"
    case receipt = "receipt"
    case photo = "photo"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .manual: return "说明书"
        case .warranty: return "保修卡"
        case .receipt: return "购买凭证"
        case .photo: return "产品照片"
        case .other: return "其他文档"
        }
    }
    
    var icon: String {
        switch self {
        case .manual: return "book"
        case .warranty: return "shield.checkered"
        case .receipt: return "receipt"
        case .photo: return "photo"
        case .other: return "doc.plaintext"
        }
    }
    
    var color: Color {
        switch self {
        case .manual: return .blue
        case .warranty: return .green
        case .receipt: return .orange
        case .photo: return .purple
        case .other: return .gray
        }
    }
}

// MARK: - OCR状态枚举
enum OCRStatus: String, CaseIterable, Codable {
    case all = "all"
    case processed = "processed"
    case unprocessed = "unprocessed"
}

// MARK: - 辅助方法
extension AdvancedSearchFiltersView {
    private func applyFilters() {
        filters = tempFilters
        dismiss()
    }
}

#Preview {
    AdvancedSearchFiltersView(filters: .constant(AdvancedSearchFilters()))
}
