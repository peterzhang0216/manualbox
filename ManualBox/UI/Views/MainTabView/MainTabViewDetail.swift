//
//  MainTabViewDetail.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import SwiftUI
import CoreData

// MARK: - Main Tab View Detail

extension MainTabView {
    
    // MARK: - 详情视图
    
    @ViewBuilder
    var detailView: some View {
        UnifiedDetailPanel()
            .environmentObject(detailPanelStateManager)
    }
    
    @ViewBuilder
    func detailForSelection(_ selection: SelectionValue) -> some View {
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
    func mainDetailView(for index: Int) -> some View {
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
    func categoryDetailView(for id: UUID) -> some View {
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
    func tagDetailView(for id: UUID) -> some View {
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
    var productDetailOrPlaceholder: some View {
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
    var defaultDetailPlaceholder: some View {
        ContentUnavailableView {
            Label("暂无选中内容", systemImage: "square.3.layers.3d")
        } description: {
            Text("请从左侧选择要查看的内容")
        }
        .padding(.top, 20)
    }
}