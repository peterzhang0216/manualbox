import SwiftUI
import CoreData


struct SearchFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var searchFilters: SearchFilters
    
    // 分类选择
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) private var categories: FetchedResults<Category>
    
    // 标签选择
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var tags: FetchedResults<Tag>
    
    // 本地状态变量
    @State private var localSearchFilters: SearchFilters
    
    init(searchFilters: Binding<SearchFilters>) {
        self._searchFilters = searchFilters
        self._localSearchFilters = State(initialValue: searchFilters.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("搜索范围")) {
                    Toggle("商品名称", isOn: $localSearchFilters.searchInName)
                    Toggle("品牌", isOn: $localSearchFilters.searchInBrand)
                    Toggle("型号", isOn: $localSearchFilters.searchInModel)
                    Toggle("备注", isOn: $localSearchFilters.searchInNotes)
                }
                
                Section(header: Text("分类筛选")) {
                    Toggle("启用分类筛选", isOn: $localSearchFilters.filterByCategory)
                    
                    if localSearchFilters.filterByCategory {
                        Picker("选择分类", selection: $localSearchFilters.selectedCategoryID) {
                            Text("所有分类").tag("")
                            ForEach(categories) { category in
                                Text(category.categoryName).tag(category.id?.uuidString ?? "")
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section(header: Text("标签筛选")) {
                    Toggle("启用标签筛选", isOn: $localSearchFilters.filterByTag)
                    
                    if localSearchFilters.filterByTag {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags) { tag in
                                    TagChip(
                                        tag: tag,
                                        isSelected: localSearchFilters.selectedTagIDs.contains(tag.id?.uuidString ?? "")
                                    )
                                    .onTapGesture {
                                        toggleTagSelection(tag)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Section(header: Text("保修状态")) {
                    Toggle("启用保修状态筛选", isOn: $localSearchFilters.filterByWarranty)
                    
                    if localSearchFilters.filterByWarranty {
                        Picker("保修状态", selection: $localSearchFilters.warrantyStatus) {
                            Text("所有状态").tag(-1)
                            Text("在保修期内").tag(0)
                            Text("即将过期").tag(1)
                            Text("已过期").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Section(header: Text("购买日期")) {
                    Toggle("启用日期筛选", isOn: $localSearchFilters.filterByDate)
                    
                    if localSearchFilters.filterByDate {
                        DatePicker(
                            "开始日期",
                            selection: $localSearchFilters.startDate,
                            displayedComponents: .date
                        )
                        
                        DatePicker(
                            "结束日期",
                            selection: $localSearchFilters.endDate,
                            displayedComponents: .date
                        )
                    }
                }
                
                Section {
                    Button(action: applyFilters) {
                        Text("应用筛选")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(role: .destructive, action: resetFilters) {
                        Text("重置所有筛选")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("筛选")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func toggleTagSelection(_ tag: Tag) {
        guard let tagID = tag.id?.uuidString else { return }
        
        if localSearchFilters.selectedTagIDs.contains(tagID) {
            localSearchFilters.selectedTagIDs.removeAll { $0 == tagID }
        } else {
            localSearchFilters.selectedTagIDs.append(tagID)
        }
    }
    
    private func applyFilters() {
        searchFilters = localSearchFilters
        dismiss()
    }
    
    private func resetFilters() {
        localSearchFilters = SearchFilters()
        searchFilters = localSearchFilters
        dismiss()
    }
}

// 标签选择芯片
struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tag.uiColor)
                .frame(width: 8, height: 8)
            
            Text(tag.tagName)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? tag.uiColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? tag.uiColor : Color.clear, lineWidth: 1)
                )
        )
    }
}

#Preview {
    SearchFilterView(searchFilters: .constant(SearchFilters()))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
