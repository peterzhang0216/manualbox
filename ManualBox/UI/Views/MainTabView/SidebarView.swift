//
//  SidebarView.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import SwiftUI
import CoreData

#if os(macOS)
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
                
                // 添加分类按钮 - 放在列表下方
                Button(action: { detailPanelStateManager.showAddCategory() }) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.secondary)
                        Text("添加分类")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
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
                
                // 添加标签按钮 - 放在列表下方
                Button(action: { detailPanelStateManager.showAddTag() }) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.secondary)
                        Text("添加标签")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
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