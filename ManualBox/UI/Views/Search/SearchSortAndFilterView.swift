//
//  SearchSortAndFilterView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  搜索排序和过滤视图 - 提供详细的排序和过滤选项
//

import SwiftUI

struct SearchSortAndFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sortOptions: SearchSortOptions
    @Binding var filters: AdvancedSearchFilters
    @State private var tempSortOptions: SearchSortOptions
    @State private var tempFilters: AdvancedSearchFilters
    
    init(sortOptions: Binding<SearchSortOptions>, filters: Binding<AdvancedSearchFilters>) {
        self._sortOptions = sortOptions
        self._filters = filters
        self._tempSortOptions = State(initialValue: sortOptions.wrappedValue)
        self._tempFilters = State(initialValue: filters.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 排序选项
                sortingSection
                
                // 结果过滤
                resultFilteringSection
                
                // 高级选项
                advancedOptionsSection
                
                // 预设选项
                presetSection
            }
            .navigationTitle("排序和过滤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用") {
                        applyChanges()
                    }
                }
            }
        }
    }
    
    // MARK: - 排序选项
    
    private var sortingSection: some View {
        Section("排序选项") {
            // 主要排序
            VStack(alignment: .leading, spacing: 12) {
                Text("排序方式")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(SearchSortOptions.SortType.allCases, id: \.self) { sortType in
                        SortOptionButton(
                            sortType: sortType,
                            isSelected: tempSortOptions.primarySort == sortType
                        ) {
                            tempSortOptions.primarySort = sortType
                        }
                    }
                }
            }
            
            // 排序方向
            HStack {
                Text("排序方向")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Picker("排序方向", selection: $tempSortOptions.ascending) {
                    HStack {
                        Image(systemName: "arrow.down")
                        Text("降序")
                    }
                    .tag(false)
                    
                    HStack {
                        Image(systemName: "arrow.up")
                        Text("升序")
                    }
                    .tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
    }
    
    // MARK: - 结果过滤
    
    private var resultFilteringSection: some View {
        Section("结果过滤") {
            // 相关性阈值
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("相关性阈值")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(tempFilters.relevanceThreshold * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $tempFilters.relevanceThreshold, in: 0.0...1.0, step: 0.05) {
                    Text("相关性阈值")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                }
            }
            
            // 最大结果数
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("最大结果数")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(tempFilters.maxResults)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(tempFilters.maxResults) },
                        set: { tempFilters.maxResults = Int($0) }
                    ),
                    in: 10...200,
                    step: 10
                ) {
                    Text("最大结果数")
                } minimumValueLabel: {
                    Text("10")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("200")
                        .font(.caption)
                }
            }
            
            // 结果类型过滤
            VStack(alignment: .leading, spacing: 12) {
                Text("显示结果类型")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ResultTypeToggle(
                        title: "产品",
                        icon: "cube.box",
                        color: .blue,
                        isEnabled: tempFilters.searchScopes.contains(.productName)
                    ) { isEnabled in
                        if isEnabled {
                            tempFilters.searchScopes.insert(.productName)
                        } else {
                            tempFilters.searchScopes.remove(.productName)
                        }
                    }
                    
                    ResultTypeToggle(
                        title: "说明书",
                        icon: "doc.text",
                        color: .green,
                        isEnabled: tempFilters.searchScopes.contains(.manualContent)
                    ) { isEnabled in
                        if isEnabled {
                            tempFilters.searchScopes.insert(.manualContent)
                        } else {
                            tempFilters.searchScopes.remove(.manualContent)
                        }
                    }
                    
                    ResultTypeToggle(
                        title: "分类",
                        icon: "folder",
                        color: .orange,
                        isEnabled: tempFilters.searchScopes.contains(.categoryName)
                    ) { isEnabled in
                        if isEnabled {
                            tempFilters.searchScopes.insert(.categoryName)
                        } else {
                            tempFilters.searchScopes.remove(.categoryName)
                        }
                    }
                    
                    ResultTypeToggle(
                        title: "标签",
                        icon: "tag",
                        color: .purple,
                        isEnabled: tempFilters.searchScopes.contains(.tagName)
                    ) { isEnabled in
                        if isEnabled {
                            tempFilters.searchScopes.insert(.tagName)
                        } else {
                            tempFilters.searchScopes.remove(.tagName)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 高级选项
    
    private var advancedOptionsSection: some View {
        Section("高级选项") {
            Toggle("模糊搜索", isOn: $tempFilters.enableFuzzySearch)
            Toggle("同义词搜索", isOn: $tempFilters.enableSynonymSearch)
            Toggle("正则表达式", isOn: $tempFilters.enableRegexSearch)
            Toggle("区分大小写", isOn: $tempFilters.caseSensitive)
            
            // 搜索深度
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("搜索深度")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(searchDepthDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Picker("搜索深度", selection: $tempFilters.maxResults) {
                    Text("快速 (50个结果)").tag(50)
                    Text("标准 (100个结果)").tag(100)
                    Text("深度 (200个结果)").tag(200)
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    // MARK: - 预设选项
    
    private var presetSection: some View {
        Section("快速预设") {
            VStack(spacing: 8) {
                PresetButton(
                    title: "最相关",
                    description: "按相关性排序，显示最匹配的结果",
                    icon: "star.fill",
                    color: .yellow
                ) {
                    applyRelevancePreset()
                }
                
                PresetButton(
                    title: "最新",
                    description: "按创建时间排序，显示最新的内容",
                    icon: "clock.fill",
                    color: .blue
                ) {
                    applyNewestPreset()
                }
                
                PresetButton(
                    title: "全面搜索",
                    description: "搜索所有类型，显示更多结果",
                    icon: "magnifyingglass.circle.fill",
                    color: .green
                ) {
                    applyComprehensivePreset()
                }
                
                PresetButton(
                    title: "精确匹配",
                    description: "高相关性阈值，精确匹配结果",
                    icon: "target",
                    color: .red
                ) {
                    applyPrecisePreset()
                }
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var searchDepthDescription: String {
        switch tempFilters.maxResults {
        case 50: return "快速搜索"
        case 100: return "标准搜索"
        case 200: return "深度搜索"
        default: return "自定义"
        }
    }
    
    // MARK: - 预设方法
    
    private func applyRelevancePreset() {
        tempSortOptions.primarySort = .relevance
        tempSortOptions.ascending = false
        tempFilters.relevanceThreshold = 0.3
        tempFilters.maxResults = 50
    }
    
    private func applyNewestPreset() {
        tempSortOptions.primarySort = .date
        tempSortOptions.ascending = false
        tempFilters.relevanceThreshold = 0.1
        tempFilters.maxResults = 100
    }
    
    private func applyComprehensivePreset() {
        tempSortOptions.primarySort = .relevance
        tempSortOptions.ascending = false
        tempFilters.searchScopes = Set(AdvancedSearchScope.allCases)
        tempFilters.relevanceThreshold = 0.1
        tempFilters.maxResults = 200
    }
    
    private func applyPrecisePreset() {
        tempSortOptions.primarySort = .relevance
        tempSortOptions.ascending = false
        tempFilters.relevanceThreshold = 0.7
        tempFilters.maxResults = 30
        tempFilters.enableFuzzySearch = false
        tempFilters.caseSensitive = true
    }
    
    private func applyChanges() {
        sortOptions = tempSortOptions
        filters = tempFilters
        dismiss()
    }
}

// MARK: - 排序选项按钮
struct SortOptionButton: View {
    let sortType: SearchSortOptions.SortType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: sortType.icon)
                    .font(.caption)
                
                Text(sortType.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor : Color(.systemGray5)
            )
            .foregroundColor(
                isSelected ? .white : .primary
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 结果类型切换
struct ResultTypeToggle: View {
    let title: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: {
            onToggle(!isEnabled)
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(isEnabled ? .white : color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(isEnabled ? .semibold : .regular)
                    .foregroundColor(isEnabled ? .white : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isEnabled ? color : Color(.systemGray5)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 预设按钮
struct PresetButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SearchSortAndFilterView(
        sortOptions: .constant(SearchSortOptions()),
        filters: .constant(AdvancedSearchFilters())
    )
}