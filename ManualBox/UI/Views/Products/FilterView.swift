import SwiftUI
import CoreData
import Foundation

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @Binding var selectedCategories: Set<Category>
    @Binding var selectedTags: Set<Tag>
    @Binding var showWarrantyFilter: Bool
    @Binding var onlyWithManuals: Bool
    
    @FetchRequest(
        entity: Category.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
    ) private var categories: FetchedResults<Category>
    
    @FetchRequest(
        entity: Tag.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
    ) private var tags: FetchedResults<Tag>
    
    var body: some View {
        filterNavigationView
    }
    
    private var filterNavigationView: some View {
        NavigationView {
            filterForm
                .navigationTitle("筛选")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        resetButton
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        doneButton
                    }
                }
                #endif
        }
    }
    
    private var filterForm: some View {
        Form {
            categorySection
            tagSection
            statusSection
        }
    }
    
    private var categorySection: some View {
        Section("分类筛选") {
            ForEach(categories) { category in
                categoryRow(category)
            }
        }
    }
    
    private func categoryRow(_ category: Category) -> some View {
        HStack {
            #if os(macOS)
            Text(category.name ?? "未命名分类")
            #else
            Text("分类项目")
            #endif
            Spacer()
            if selectedCategories.contains(category) {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedCategories.contains(category) {
                selectedCategories.remove(category)
            } else {
                selectedCategories.insert(category)
            }
        }
    }
    
    private var tagSection: some View {
        Section("标签筛选") {
            ForEach(tags) { tag in
                tagRow(tag)
            }
        }
    }
    
    private func tagRow(_ tag: Tag) -> some View {
        HStack {
            #if os(macOS)
            Text(tag.name ?? "未命名标签")
            #else
            Text("标签项目")
            #endif
            Spacer()
            if selectedTags.contains(tag) {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedTags.contains(tag) {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        }
    }
    
    private var statusSection: some View {
        Section("状态筛选") {
            Toggle("仅显示保修中的产品", isOn: $showWarrantyFilter)
            Toggle("仅显示有说明书的产品", isOn: $onlyWithManuals)
        }
    }
    
    private var resetButton: some View {
        Button("重置") {
            selectedCategories.removeAll()
            selectedTags.removeAll()
            showWarrantyFilter = false
            onlyWithManuals = false
        }
    }
    
    private var doneButton: some View {
        Button("完成") {
            dismiss()
        }
    }
}