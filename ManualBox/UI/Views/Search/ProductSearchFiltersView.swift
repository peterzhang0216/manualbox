import SwiftUI
import CoreData

// MARK: - 产品搜索过滤器视图
struct ProductSearchFiltersView: View {
    @Binding var filters: ProductSearchFilters
    let onApply: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default
    ) private var categories: FetchedResults<Category>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        animation: .default
    ) private var tags: FetchedResults<Tag>
    
    @State private var localFilters: ProductSearchFilters
    @State private var showingDatePicker = false
    @State private var datePickerType: DatePickerType = .start
    
    enum DatePickerType {
        case start, end
    }
    
    init(filters: Binding<ProductSearchFilters>, onApply: @escaping () -> Void) {
        self._filters = filters
        self.onApply = onApply
        self._localFilters = State(initialValue: filters.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 分类过滤
                categorySection
                
                // 标签过滤
                tagSection
                
                // 价格范围
                priceSection
                
                // 日期范围
                dateSection
                
                // 保修状态
                warrantySection
                
                // 其他选项
                otherOptionsSection
                
                // 重置按钮
                resetSection
            }
            .navigationTitle("搜索过滤器")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用") {
                        applyFilters()
                    }
                }
            })
            #else
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .automatic) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                SwiftUI.ToolbarItem(placement: .automatic) {
                    Button("应用") {
                        applyFilters()
                    }
                }
            })
            #endif
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(
                selectedDate: datePickerType == .start ? 
                    Binding(
                        get: { localFilters.startDate ?? Date() },
                        set: { localFilters.startDate = $0 }
                    ) :
                    Binding(
                        get: { localFilters.endDate ?? Date() },
                        set: { localFilters.endDate = $0 }
                    ),
                title: datePickerType == .start ? "开始日期" : "结束日期"
            )
        }
    }
    
    // MARK: - 分类过滤
    private var categorySection: some View {
        Section {
            if categories.isEmpty {
                Text("暂无分类")
                    .foregroundColor(.secondary)
            } else {
                Picker("选择分类", selection: Binding(
                    get: { localFilters.categoryId },
                    set: { localFilters.categoryId = $0 }
                )) {
                    Text("所有分类").tag(nil as UUID?)
                    
                    ForEach(categories, id: \.id) { category in
                        HStack {
                            Image(systemName: category.categoryIcon)
                                .foregroundColor(Color(category.categoryColor))
                            Text(category.categoryName)
                        }
                        .tag(category.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text("分类")
        } footer: {
            if localFilters.categoryId != nil {
                Text("已选择分类过滤")
            }
        }
    }
    
    // MARK: - 标签过滤
    private var tagSection: some View {
        Section {
            if tags.isEmpty {
                Text("暂无标签")
                    .foregroundColor(.secondary)
            } else {
                ForEach(tags, id: \.id) { tag in
                    HStack {
                        Button(action: {
                            toggleTag(tag)
                        }) {
                            HStack {
                                Image(systemName: isTagSelected(tag) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isTagSelected(tag) ? .accentColor : .secondary)
                                
                                Text(tag.tagName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            HStack {
                Text("标签")
                
                Spacer()
                
                if !localFilters.tagIds.isEmpty {
                    Text("已选择 \(localFilters.tagIds.count) 个")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } footer: {
            if !localFilters.tagIds.isEmpty {
                Button("清除标签选择") {
                    localFilters.tagIds.removeAll()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - 价格范围
    private var priceSection: some View {
        Section {
            HStack {
                Text("最低价格")
                Spacer()
                TextField("0", value: Binding(
                    get: { localFilters.minPrice ?? 0 },
                    set: { localFilters.minPrice = $0 > 0 ? $0 : nil }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            }
            
            HStack {
                Text("最高价格")
                Spacer()
                TextField("无限制", value: Binding(
                    get: { localFilters.maxPrice ?? 0 },
                    set: { localFilters.maxPrice = $0 > 0 ? $0 : nil }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            }
        } header: {
            Text("价格范围")
        } footer: {
            if localFilters.minPrice != nil || localFilters.maxPrice != nil {
                let minText = localFilters.minPrice.map { "¥" + String(format: "%.2f", NSDecimalNumber(decimal: $0).doubleValue) } ?? "0"
                let maxText = localFilters.maxPrice.map { "¥" + String(format: "%.2f", NSDecimalNumber(decimal: $0).doubleValue) } ?? "无限制"
                Text("价格范围: \(minText) - \(maxText)")
            }
        }
    }
    
    // MARK: - 日期范围
    private var dateSection: some View {
        Section {
            HStack {
                Text("开始日期")
                Spacer()
                if let startDate = localFilters.startDate {
                    Text(formatDate(startDate))
                        .foregroundColor(.secondary)
                } else {
                    Text("未设置")
                        .foregroundColor(.secondary)
                }
                Button("选择") {
                    datePickerType = .start
                    showingDatePicker = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            HStack {
                Text("结束日期")
                Spacer()
                if let endDate = localFilters.endDate {
                    Text(formatDate(endDate))
                        .foregroundColor(.secondary)
                } else {
                    Text("未设置")
                        .foregroundColor(.secondary)
                }
                Button("选择") {
                    datePickerType = .end
                    showingDatePicker = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } header: {
            Text("创建日期范围")
        } footer: {
            if localFilters.startDate != nil || localFilters.endDate != nil {
                Button("清除日期范围") {
                    localFilters.startDate = nil
                    localFilters.endDate = nil
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - 保修状态
    private var warrantySection: some View {
        Section {
            Picker("保修状态", selection: Binding(
                get: { localFilters.warrantyStatus },
                set: { localFilters.warrantyStatus = $0 }
            )) {
                Text("所有状态").tag(nil as ProductSearchFilters.WarrantyStatus?)
                
                ForEach(ProductSearchFilters.WarrantyStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status as ProductSearchFilters.WarrantyStatus?)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("保修状态")
        }
    }
    
    // MARK: - 其他选项
    private var otherOptionsSection: some View {
        Section {
            HStack {
                Text("有说明书")
                Spacer()
                Picker("", selection: Binding(
                    get: { localFilters.hasManuals },
                    set: { localFilters.hasManuals = $0 }
                )) {
                    Text("全部").tag(nil as Bool?)
                    Text("有").tag(true as Bool?)
                    Text("无").tag(false as Bool?)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            
            HStack {
                Text("有图片")
                Spacer()
                Picker("", selection: Binding(
                    get: { localFilters.hasImages },
                    set: { localFilters.hasImages = $0 }
                )) {
                    Text("全部").tag(nil as Bool?)
                    Text("有").tag(true as Bool?)
                    Text("无").tag(false as Bool?)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        } header: {
            Text("其他选项")
        }
    }
    
    // MARK: - 重置按钮
    private var resetSection: some View {
        Section {
            Button("重置所有过滤器") {
                localFilters = ProductSearchFilters()
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    // MARK: - 辅助方法
    
    private func isTagSelected(_ tag: Tag) -> Bool {
        guard let tagId = tag.id else { return false }
        return localFilters.tagIds.contains(tagId)
    }
    
    private func toggleTag(_ tag: Tag) {
        guard let tagId = tag.id else { return }
        
        if localFilters.tagIds.contains(tagId) {
            localFilters.tagIds.removeAll { $0 == tagId }
        } else {
            localFilters.tagIds.append(tagId)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func applyFilters() {
        filters = localFilters
        onApply()
        dismiss()
    }
}

// MARK: - 日期选择器界面
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    title,
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                #if os(iOS)
                .datePickerStyle(.wheel)
                #endif
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar(content: {
                #if os(iOS)
                SwiftUI.ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        dismiss()
                    }
                }
                #elseif os(macOS)
                SwiftUI.ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                SwiftUI.ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        dismiss()
                    }
                }
                #endif
            })
        }
    }
}

#Preview {
    ProductSearchFiltersView(filters: .constant(ProductSearchFilters())) {
        // Preview action
    }
}
