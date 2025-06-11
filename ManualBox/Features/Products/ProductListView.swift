//
//  ProductListView.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import SwiftUI
import CoreData

struct ProductListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let filteredProducts: [Product]
    let searchText: String
    let deleteProducts: (IndexSet) -> Void
    
#if os(iOS)
    @Environment(\.editMode) private var editMode
#else
    let isEditing: Bool
#endif
    
    var body: some View {
        List {
            ForEach(filteredProducts, id: \.self) { product in
                NavigationLink(destination: ProductDetailView(product: product)) {
                    ProductRowView(product: product)
                }
            }
#if os(iOS)
            .onDelete(perform: deleteProducts)
#else
            .onDelete(perform: isEditing ? deleteProducts : nil)
#endif
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#else
        .listStyle(SidebarListStyle())
#endif
        .overlay(Group {
            if filteredProducts.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: searchText.isEmpty ? "shippingbox" : "magnifyingglass")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.accentColor)
                    Text(searchText.isEmpty ? "没有产品" : "未找到匹配结果")
                        .font(.title2)
                        .bold()
                    Text(searchText.isEmpty ?
                         "点击右上角 + 按钮添加产品" :
                            "请尝试其他搜索关键词")
                    .font(.body)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
#if os(iOS)
                .background(Color(.secondarySystemBackground))
#else
                .background(Color(.windowBackgroundColor))
#endif
            }
        })
    }
}