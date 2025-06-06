//
//  Product+Extensions.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import Foundation
import CoreData
import SwiftUI

extension Product {
    // MARK: - 便利属性
    var productName: String {
        get { name ?? "未命名商品" }
        set { name = newValue }
    }
    
    var productBrand: String {
        get { brand ?? "" }
        set { brand = newValue }
    }
    
    var productModel: String {
        get { model ?? "" }
        set { model = newValue }
    }
    
    var productNotes: String {
        get { notes ?? "" }
        set { notes = newValue }
    }
    
    var productImage: PlatformImage? {
        guard let imageData = imageData else { return nil }
        return PlatformImage(data: imageData)
    }
    
    var productCreatedAt: Date {
        get { createdAt ?? Date() }
        set { createdAt = newValue }
    }
    
    var productUpdatedAt: Date {
        get { updatedAt ?? Date() }
        set { updatedAt = newValue }
    }
    
    var productManuals: [Manual] {
        let manualsSet = manuals as? Set<Manual> ?? []
        return Array(manualsSet)
    }
    
    var productTags: [Tag] {
        let tagsSet = tags as? Set<Tag> ?? []
        return Array(tagsSet)
    }
    
    // MARK: - 工厂方法
    static func createProduct(
        in context: NSManagedObjectContext,
        name: String,
        brand: String? = nil,
        model: String? = nil,
        category: Category? = nil,
        image: PlatformImage? = nil
    ) -> Product {
        let product = Product(context: context)
        product.id = UUID()
        product.name = name
        product.brand = brand
        product.model = model
        product.category = category
        
        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.7) {
            product.imageData = imageData
        }
        
        let now = Date()
        product.createdAt = now
        product.updatedAt = now
        
        return product
    }
    
    // MARK: - 辅助方法
    func updateImage(_ image: PlatformImage?) {
        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.7) {
            self.imageData = imageData
        } else {
            self.imageData = nil
        }
        self.updatedAt = Date()
    }
    
    func addManual(_ manual: Manual) {
        var currentManuals = manuals as? Set<Manual> ?? Set<Manual>()
        currentManuals.insert(manual)
        manuals = currentManuals as NSSet
        updatedAt = Date()
    }
    
    func addTag(_ tag: Tag) {
        var currentTags = tags as? Set<Tag> ?? Set<Tag>()
        currentTags.insert(tag)
        tags = currentTags as NSSet
    }
    
    func removeTag(_ tag: Tag) {
        var currentTags = tags as? Set<Tag> ?? Set<Tag>()
        currentTags.remove(tag)
        tags = currentTags as NSSet
    }
    
    // 检查是否有有效的保修期
    var hasActiveWarranty: Bool {
        guard let order = order, let warrantyEndDate = order.warrantyEndDate else {
            return false
        }
        return warrantyEndDate > Date()
    }
    
    // 获取保修剩余天数
    var warrantyRemainingDays: Int? {
        guard let order = order, let warrantyEndDate = order.warrantyEndDate else {
            return nil
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: warrantyEndDate)
        return components.day
    }
}

// 添加 SwiftUI 预览支持
extension Product {
    @MainActor
    static var preview: Product {
        let context = PersistenceController.preview.container.viewContext
        let product = Product(context: context)
        product.id = UUID()
        product.name = "iPad Pro 12.9"
        product.brand = "Apple"
        product.model = "MXAY2CH/A"
        product.notes = "2021年购买的iPad Pro，主要用于工作和设计"
        
        // 创建分类
        let category = Category(context: context)
        category.id = UUID()
        category.name = "电子产品"
        category.icon = "laptopcomputer"
        product.category = category
        
        return product
    }
}