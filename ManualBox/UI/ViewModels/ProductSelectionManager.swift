//
//  ProductSelectionManager.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/20.
//

import Foundation
import SwiftUI
import CoreData
import Combine

// MARK: - 产品选择状态
struct ProductSelectionState: StateProtocol {
    // StateProtocol 必需属性
    var isLoading: Bool = false
    var errorMessage: String?

    var selectedProduct: Product?
    var previousProduct: Product?
    var selectionHistory: [Product] = []
    var maxHistoryCount: Int = 10

    // 选择验证状态
    var isValidSelection: Bool = true
    var selectionError: String?

    // 筛选相关状态
    var availableProducts: [Product] = []
    var filteredProducts: [Product] = []
}

// MARK: - 产品选择动作
enum ProductSelectionAction: ActionProtocol {
    case selectProduct(Product?)
    case updateAvailableProducts([Product])
    case updateFilteredProducts([Product])
    case clearSelection
    case goToPreviousProduct
    case validateSelection
    case setSelectionError(String?)
}

// MARK: - 产品选择管理器
@MainActor
class ProductSelectionManager: BaseViewModel<ProductSelectionState, ProductSelectionAction> {
    private let viewContext: NSManagedObjectContext
    
    // 发布选择变化的通知
    @Published var currentProduct: Product?
    
    // 便利属性
    var selectedProduct: Product? { state.selectedProduct }
    var hasSelection: Bool { state.selectedProduct != nil }
    var canGoBack: Bool { state.previousProduct != nil }
    var selectionHistory: [Product] { state.selectionHistory }
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        super.init(initialState: ProductSelectionState())
        
        // 监听状态变化并发布通知
        $state
            .map(\.selectedProduct)
            .removeDuplicates { $0?.objectID == $1?.objectID }
            .assign(to: &$currentProduct)
    }
    
    // MARK: - Action Handler
    override func handle(_ action: ProductSelectionAction) async {
        switch action {
        case .selectProduct(let product):
            await selectProduct(product)
            
        case .updateAvailableProducts(let products):
            updateState { 
                $0.availableProducts = products
                // 验证当前选择是否仍然有效
                if let selected = $0.selectedProduct,
                   !products.contains(where: { $0.objectID == selected.objectID }) {
                    $0.isValidSelection = false
                    $0.selectionError = "所选产品不在当前列表中"
                }
            }
            
        case .updateFilteredProducts(let products):
            updateState { 
                $0.filteredProducts = products
                // 如果当前选择不在筛选结果中，考虑自动选择第一个
                if let selected = $0.selectedProduct,
                   !products.contains(where: { $0.objectID == selected.objectID }),
                   let firstProduct = products.first {
                    // 自动选择第一个产品
                    $0.previousProduct = $0.selectedProduct
                    $0.selectedProduct = firstProduct
                    self.addToHistory(firstProduct, in: &$0)
                }
            }
            
        case .clearSelection:
            updateState { 
                $0.previousProduct = $0.selectedProduct
                $0.selectedProduct = nil
                $0.isValidSelection = true
                $0.selectionError = nil
            }
            
        case .goToPreviousProduct:
            updateState { 
                if let previous = $0.previousProduct {
                    let current = $0.selectedProduct
                    $0.selectedProduct = previous
                    $0.previousProduct = current
                    self.addToHistory(previous, in: &$0)
                }
            }
            
        case .validateSelection:
            await validateCurrentSelection()
            
        case .setSelectionError(let error):
            updateState { 
                $0.selectionError = error
                $0.isValidSelection = error == nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func selectProduct(_ product: Product?) async {
        updateState { state in
            // 保存当前选择为上一个
            if state.selectedProduct != product {
                state.previousProduct = state.selectedProduct
            }
            
            // 更新选择
            state.selectedProduct = product
            
            // 添加到历史记录
            if let product = product {
                self.addToHistory(product, in: &state)
            }
            
            // 重置错误状态
            state.isValidSelection = true
            state.selectionError = nil
        }
        
        // 验证新选择
        await validateCurrentSelection()
    }
    
    private func addToHistory(_ product: Product, in state: inout ProductSelectionState) {
        // 移除重复项
        state.selectionHistory.removeAll { $0.objectID == product.objectID }
        
        // 添加到开头
        state.selectionHistory.insert(product, at: 0)
        
        // 限制历史记录数量
        if state.selectionHistory.count > state.maxHistoryCount {
            state.selectionHistory = Array(state.selectionHistory.prefix(state.maxHistoryCount))
        }
    }
    
    private func validateCurrentSelection() async {
        guard let selectedProduct = state.selectedProduct else {
            updateState { 
                $0.isValidSelection = true
                $0.selectionError = nil
            }
            return
        }
        
        // 检查产品是否仍然存在
        do {
            _ = try viewContext.existingObject(with: selectedProduct.objectID)
            updateState {
                $0.isValidSelection = true
                $0.selectionError = nil
            }
        } catch {
            updateState {
                $0.isValidSelection = false
                $0.selectionError = "所选产品已被删除: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 智能选择产品（基于上下文）
    func smartSelectProduct(from products: [Product], context: SelectionContext = .default) {
        guard !products.isEmpty else {
            send(.clearSelection)
            return
        }
        
        let productToSelect: Product?
        
        switch context {
        case .default:
            // 默认选择第一个
            productToSelect = products.first
            
        case .preserveCurrent:
            // 尝试保持当前选择，如果不在列表中则选择第一个
            if let current = selectedProduct,
               products.contains(where: { $0.objectID == current.objectID }) {
                productToSelect = current
            } else {
                productToSelect = products.first
            }
            
        case .mostRecent:
            // 选择最近更新的
            productToSelect = products.max { 
                ($0.updatedAt ?? $0.createdAt ?? Date.distantPast) < 
                ($1.updatedAt ?? $1.createdAt ?? Date.distantPast) 
            }
            
        case .fromHistory:
            // 从历史记录中选择
            productToSelect = selectionHistory.first { historyProduct in
                products.contains { $0.objectID == historyProduct.objectID }
            } ?? products.first
        }
        
        send(.selectProduct(productToSelect))
    }
    
    /// 选择上下文
    enum SelectionContext {
        case `default`          // 默认选择第一个
        case preserveCurrent    // 尝试保持当前选择
        case mostRecent        // 选择最近的
        case fromHistory       // 从历史记录选择
    }
}

// MARK: - SwiftUI Environment Key
struct ProductSelectionManagerKey: EnvironmentKey {
    static let defaultValue: ProductSelectionManager? = nil
}

extension EnvironmentValues {
    var productSelectionManager: ProductSelectionManager? {
        get { self[ProductSelectionManagerKey.self] }
        set { self[ProductSelectionManagerKey.self] = newValue }
    }
}

// MARK: - View Extension
extension View {
    func productSelectionManager(_ manager: ProductSelectionManager) -> some View {
        environment(\.productSelectionManager, manager)
    }
}
