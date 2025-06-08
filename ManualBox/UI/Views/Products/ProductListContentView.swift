//
//  ProductListContentView.swift
//  ManualBox
//
//  Created by Assistant on 2025/1/27.
//

import SwiftUI
import CoreData

struct ProductListContentView: View {
    let products: [Product]
    @ObservedObject var viewModel: ProductListViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    #if os(macOS)
    @Environment(\.selectedProduct) private var environmentSelectedProduct
    
    private var selectedProduct: Binding<Product?> {
        if environmentSelectedProduct.wrappedValue != nil {
            return environmentSelectedProduct
        } else {
            return Binding(
                get: { viewModel._selectedProduct },
                set: { 
                    viewModel.send(.setSelectedProduct($0))
                    environmentSelectedProduct.wrappedValue = $0
                }
            )
        }
    }
    #else
    private var selectedProduct: Binding<Product?> {
        return Binding(
            get: { viewModel._selectedProduct },
            set: { viewModel.send(.setSelectedProduct($0)) }
        )
    }
    #endif
    
    var body: some View {
        Group {
            if viewModel.viewStyle == .list {
                productListView
            } else {
                ProductGridView(products: products, viewModel: viewModel)
            }
        }
    }
    
    private var productListView: some View {
        Group {
            if viewModel.isSelectMode {
                List(selection: Binding(
                    get: { viewModel.selectedProducts },
                    set: { newSelection in
                        // 处理选择变化
                        let currentSelection = viewModel.selectedProducts
                        let added = newSelection.subtracting(currentSelection)
                        let removed = currentSelection.subtracting(newSelection)
                        
                        for product in added {
                            viewModel.send(.selectProduct(product))
                        }
                        for product in removed {
                            viewModel.send(.deselectProduct(product))
                        }
                    }
                )) {
                    ForEach(products, id: \.objectID) { product in
                        ProductListItem(product: product)
                            .tag(product)
                    }
                    .onDelete { indexSet in
                        viewModel.deleteItems(at: indexSet, from: products)
                    }
                }
                .listStyle(.inset)
            } else {
                List(selection: selectedProduct) {
                     ForEach(products, id: \.objectID) { product in
                        #if os(iOS)
                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            ProductListItem(product: product)
                        }
                        #else
                        ProductListItem(product: product)
                            .tag(product)
                        #endif
                    }
                    .onDelete { indexSet in
                        viewModel.deleteItems(at: indexSet, from: products)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct ProductEmptyStateView: View {
    let searchText: String
    let hasFilters: Bool
    
    var body: some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            ContentUnavailableView {
                Label("暂无商品", systemImage: "shippingbox")
            } description: {
                if !searchText.isEmpty || hasFilters {
                    Text("没有找到符合条件的商品，请调整筛选条件")
                } else {
                    Text("点击右上角的 + 按钮添加新商品")
                }
            } actions: {
                if searchText.isEmpty && !hasFilters {
                    Button {
                        NotificationCenter.default.post(
                            name: Notification.Name("CreateNewProduct"),
                            object: nil
                        )
                    } label: {
                        Text("添加商品")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("暂无商品")
                    .font(.title2)
                    .fontWeight(.medium)
                
                if !searchText.isEmpty || hasFilters {
                    Text("没有找到符合条件的商品，请调整筛选条件")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("点击右上角的 + 按钮添加新商品")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        NotificationCenter.default.post(
                            name: Notification.Name("CreateNewProduct"),
                            object: nil
                        )
                    } label: {
                        Text("添加商品")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
}