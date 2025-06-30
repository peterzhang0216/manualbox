//
//  MainTabViewContent.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import SwiftUI
import CoreData

// MARK: - Main Tab View Content

extension MainTabView {
    
    // MARK: - 内容视图
    
    @ViewBuilder
    var contentView: some View {
        ZStack {
            if let selection = selectedTab {
                contentForSelection(selection)
            } else {
                defaultProductListView
            }
        }
    }
    
    @ViewBuilder
    func contentForSelection(_ selection: SelectionValue) -> some View {
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
    func mainContentView(for index: Int) -> some View {
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
    func categoryContentView(for id: UUID) -> some View {
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
    func tagContentView(for id: UUID) -> some View {
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
    var productListView: some View {
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
    var defaultProductListView: some View {
        EnhancedProductListView(
            filteredProducts: filteredProducts,
            searchText: searchText,
            deleteProducts: deleteProducts
        )
        .environment(\.selectedProduct, $selectedProduct)
        .productSelectionManager(productSelectionManager)
    }
    
    @ViewBuilder
    var categoryPlaceholderView: some View {
        // 根据详情面板状态决定显示内容
        switch detailPanelStateManager.currentState {
        case .addCategory:
            // 在第二栏显示添加分类表单
            InlineCategoryFormView(mode: .add)
                .environmentObject(detailPanelStateManager)
        case .editCategory(let category):
            // 在第二栏显示编辑分类表单
            InlineCategoryFormView(mode: .edit(category))
                .environmentObject(detailPanelStateManager)
        default:
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
    var tagPlaceholderView: some View {
        // 根据详情面板状态决定显示内容
        switch detailPanelStateManager.currentState {
        case .addTag:
            // 在第二栏显示添加标签表单
            InlineTagFormView(mode: .add)
                .environmentObject(detailPanelStateManager)
        case .editTag(let tag):
            // 在第二栏显示编辑标签表单
            InlineTagFormView(mode: .edit(tag))
                .environmentObject(detailPanelStateManager)
        default:
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
}