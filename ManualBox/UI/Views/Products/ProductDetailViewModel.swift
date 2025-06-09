//
//  ProductDetailViewModel.swift
//  ManualBox
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import SwiftUI
import CoreData

// MARK: - ProductDetail State
struct ProductDetailState: StateProtocol {
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    // UI状态
    var showingEditSheet = false
    var selectedManual: Manual?
    var showingManualPreview = false
    
    // 产品数据
    var product: Product
    
    // 操作状态
    var isDeleting = false
    var deleteError: String?
    
    init(product: Product) {
        self.product = product
    }
}

// MARK: - ProductDetail Actions
enum ProductDetailAction: ActionProtocol {
    case toggleEditSheet
    case selectManual(Manual?)
    case toggleManualPreview
    case deleteProduct
    case setDeleting(Bool)
    case setError(String?)
    case refreshProduct
}

@MainActor
class ProductDetailViewModel: BaseViewModel<ProductDetailState, ProductDetailAction> {
    private let viewContext: NSManagedObjectContext
    
    // 便利属性
    var showingEditSheet: Bool { state.showingEditSheet }
    var selectedManual: Manual? { state.selectedManual }
    var showingManualPreview: Bool { state.showingManualPreview }
    var product: Product { state.product }
    var isDeleting: Bool { state.isDeleting }
    var deleteError: String? { state.deleteError }
    
    init(product: Product, viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        super.init(initialState: ProductDetailState(product: product))
    }
    
    // MARK: - Action Handler
    override func handle(_ action: ProductDetailAction) async {
        switch action {
        case .toggleEditSheet:
            updateState { $0.showingEditSheet.toggle() }
            
        case .selectManual(let manual):
            updateState { 
                $0.selectedManual = manual
                $0.showingManualPreview = manual != nil
            }
            
        case .toggleManualPreview:
            updateState { 
                $0.showingManualPreview.toggle()
                if !$0.showingManualPreview {
                    $0.selectedManual = nil
                }
            }
            
        case .deleteProduct:
            await deleteProduct()
            
        case .setDeleting(let deleting):
            updateState { $0.isDeleting = deleting }
            
        case .setError(let error):
            updateState { $0.deleteError = error }
            
        case .refreshProduct:
            // 刷新产品数据（如果需要的话）
            viewContext.refresh(state.product, mergeChanges: true)
        }
    }
    
    // MARK: - Private Methods
    private func deleteProduct() async {
        updateState { $0.isDeleting = true }
        
        do {
            viewContext.delete(state.product)
            try viewContext.save()
            
            updateState { 
                $0.isDeleting = false
                $0.deleteError = nil
            }
        } catch {
            updateState {
                $0.deleteError = "删除产品失败: \(error.localizedDescription)"
                $0.isDeleting = false
            }
        }
    }
    
    // MARK: - Public Methods
    func getWarrantyStatus() -> (status: WarrantyStatus, daysRemaining: Int?) {
        guard let order = product.order,
              let warrantyEndDate = order.warrantyEndDate else {
            return (.noWarranty, nil)
        }
        
        let today = Date()
        
        if today <= warrantyEndDate {
            let daysRemaining = Calendar.current.dateComponents([.day], from: today, to: warrantyEndDate).day ?? 0
            if daysRemaining <= 30 {
                return (.expiringSoon, daysRemaining)
            } else {
                return (.active, daysRemaining)
            }
        } else {
            return (.expired, nil)
        }
    }
    
    func getFormattedWarrantyInfo() -> String {
        let (status, daysRemaining) = getWarrantyStatus()
        
        switch status {
        case .active:
            if let days = daysRemaining {
                return "保修期剩余 \(days) 天"
            } else {
                return "保修期内"
            }
        case .expiringSoon:
            if let days = daysRemaining {
                return "保修期即将到期（剩余 \(days) 天）"
            } else {
                return "保修期即将到期"
            }
        case .expired:
            return "保修期已过期"
        case .noWarranty:
            return "保修信息未知"
        }
    }
    
    func getManualsList() -> [Manual] {
        guard let manuals = product.manuals?.allObjects as? [Manual] else {
            return []
        }
        return manuals.sorted { ($0.fileName ?? "") < ($1.fileName ?? "") }
    }
    
    func getRepairRecordsList() -> [RepairRecord] {
        guard let order = product.order,
              let records = order.repairRecords?.allObjects as? [RepairRecord] else {
            return []
        }
        return records.sorted { (record1: RepairRecord, record2: RepairRecord) -> Bool in
            return record1.recordDate > record2.recordDate
        }
    }
    
    func getTagsList() -> [Tag] {
        guard let tags = product.tags?.allObjects as? [Tag] else {
            return []
        }
        return tags.sorted { (tag1: Tag, tag2: Tag) -> Bool in
            return (tag1.name ?? "") < (tag2.name ?? "")
        }
    }
    
    func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSNumber(value: price)) ?? "¥\(price)"
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}