//
//  ProductGridView.swift
//  ManualBox
//
//  Created by Assistant on 2025/1/27.
//

import SwiftUI
import CoreData

struct ProductGridView: View {
    let products: [Product]
    @ObservedObject var viewModel: ProductListViewModel
    
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
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(products, id: \.objectID) { product in
                    ProductGridItem(product: product, onTap: {
                        #if os(iOS)
                        if !viewModel.isSelectMode {
                            viewModel.send(.setSelectedProduct(product))
                        }
                        #else
                        selectedProduct.wrappedValue = product
                        #endif
                    })
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var gridColumns: [GridItem] {
        #if os(iOS)
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
        #else
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
        #endif
    }
}



// MARK: - Product Extensions for Grid

private extension Product {
    var imageURL: URL? {
        // 这里应该根据实际的图片存储方式来实现
        // 如果是存储在本地，可能需要转换为本地URL
        // 如果是存储在云端，返回云端URL
        return nil
    }
}