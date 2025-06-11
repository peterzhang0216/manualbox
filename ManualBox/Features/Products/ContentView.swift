//
//  ContentView.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
#if os(iOS)
    @Environment(\.editMode) private var editMode
#else
    @State private var isEditing = false
#endif
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchFilters = SearchFilters()
    @State private var showingFilterSheet = false
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Product.updatedAt, ascending: false),
            NSSortDescriptor(keyPath: \Product.createdAt, ascending: false)
        ],
        animation: .default
    )
    private var products: FetchedResults<Product>
    
    // 计算属性：过滤后的产品列表
    private var filteredProducts: [Product] {
        return ProductFilterLogic.filterProducts(
            products: Array(products),
            searchText: searchText,
            searchFilters: searchFilters
        )
    }
    
    @State private var showingAddProduct = false
    
#if os(macOS)
    @State private var toggleEditModeSubscriber: NSObjectProtocol? = nil
#endif
    
    var body: some View {
#if os(macOS)
        NavigationSplitView {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBarView(
                    searchText: $searchText,
                    searchFilters: $searchFilters,
                    showingFilterSheet: $showingFilterSheet
                )
                // 产品列表
                ProductListView(
                    filteredProducts: filteredProducts,
                    searchText: searchText,
                    deleteProducts: deleteProducts,
                    isEditing: isEditing
                )
            }
        } detail: {
            ProductDetailPlaceholderView()
        }
        .onAppear {
            // 在视图出现时注册通知
            toggleEditModeSubscriber = NotificationCenter.default.addObserver(
                forName: Notification.Name("ToggleEditMode"),
                object: nil,
                queue: .main) { _ in
                    isEditing.toggle()
                }
        }
        .onDisappear {
            // 在视图消失时移除通知观察者
            if let subscriber = toggleEditModeSubscriber {
                NotificationCenter.default.removeObserver(subscriber)
            }
        }
#else
        NavigationSplitView {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBarView(
                    searchText: $searchText,
                    searchFilters: $searchFilters,
                    showingFilterSheet: $showingFilterSheet
                )
                
                // 产品列表
                ProductListView(
                    filteredProducts: filteredProducts,
                    searchText: searchText,
                    deleteProducts: deleteProducts
                )
            }
            .navigationTitle("ManualBox")
            .toolbar(content: {
                #if os(macOS)
                ToolbarItemGroup(placement: .primaryAction) {
                    EditButton()
                        .buttonStyle(.borderedProminent)
                    Button {
                        showingAddProduct = true
                    } label: {
                        Label("添加产品", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }
                #else
                ToolbarItemGroup(placement: .primaryAction) {
                    EditButton()
                    Button {
                        showingAddProduct = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                #endif
            })
            .sheet(isPresented: $showingAddProduct) {
                NavigationStack {
                    AddProductView(isPresented: $showingAddProduct)
                        .environment(\.managedObjectContext, viewContext)
                }
                .presentationDetents([.large])
            }
        } detail: {
            ProductDetailPlaceholderView()
        }
#endif
    }

    // 删除产品
    func deleteProducts(offsets: IndexSet) {
        ProductDeletionLogic.deleteProducts(
            offsets: offsets,
            filteredProducts: filteredProducts,
            viewContext: viewContext
        )
    }


}
