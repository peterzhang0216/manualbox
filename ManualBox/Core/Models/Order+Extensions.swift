//
//  Order+Extensions.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import Foundation
import CoreData
import SwiftUI

extension Order {
    // MARK: - 便利属性
    var displayOrderNumber: String {
        get { orderNumber ?? "未知订单号" }
        set { orderNumber = newValue }
    }
    
    var displayPlatform: String {
        get { platform ?? "未知平台" }
        set { platform = newValue }
    }
    
    var displayDate: Date {
        get { orderDate ?? Date() }
        set { orderDate = newValue }
    }
    
    var displayWarrantyEndDate: Date? {
        get { warrantyEndDate }
        set { warrantyEndDate = newValue }
    }
    
    var displayRepairRecords: [RepairRecord] {
        let records = repairRecords as? Set<RepairRecord> ?? []
        return Array(records).sorted { $0.date ?? Date() > $1.date ?? Date() }
    }
    
    // MARK: - 工厂方法
    static func createOrder(
        in context: NSManagedObjectContext,
        orderNumber: String,
        platform: String,
        orderDate: Date,
        warrantyPeriod: Int = 12,
        invoiceImage: PlatformImage? = nil,
        product: Product? = nil
    ) -> Order {
        let order = Order(context: context)
        order.id = UUID()
        order.orderNumber = orderNumber
        order.platform = platform
        order.orderDate = orderDate
        
        // 计算保修到期日
        if warrantyPeriod > 0 {
            order.warrantyEndDate = Calendar.current.date(byAdding: .month, value: warrantyPeriod, to: orderDate)
        }
        
        // 保存发票图像
        if let image = invoiceImage,
           let imageData = image.jpegData(compressionQuality: 0.7) {
            order.invoiceData = imageData
        }
        
        order.product = product
        
        return order
    }
    
    // MARK: - 辅助方法
    
    // 更新发票图像
    func updateInvoiceImage(_ image: PlatformImage?) {
        if let image = image,
           let imageData = image.jpegData(compressionQuality: 0.7) {
            self.invoiceData = imageData
        } else {
            self.invoiceData = nil
        }
    }
    
    // 获取发票图像
    var invoiceImage: PlatformImage? {
        guard let data = invoiceData else { return nil }
        return PlatformImage(data: data)
    }
    
    // 添加维修记录
    func addRepairRecord(date: Date, details: String, cost: Decimal) {
        let context = self.managedObjectContext!
        let record = RepairRecord(context: context)
        record.id = UUID()
        record.date = date
        record.details = details
        record.cost = NSDecimalNumber(decimal: cost)
        record.order = self
        
        try? context.save()
    }
    
    // 获取保修状态
    var warrantyStatus: ProductSearchFilters.WarrantyStatus {
        guard let endDate = warrantyEndDate else {
            return .expired
        }
        
        let now = Date()
        if now > endDate {
            return .expired
        }
        
        // 如果保修期即将到期（30天内）
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: now, to: endDate)
        if let days = components.day, days <= 30 {
            return .expiring
        }
        
        return .active
    }
    
    // 获取格式化的保修剩余时间
    var formattedWarrantyRemaining: String {
        guard let endDate = warrantyEndDate else {
            return "无保修信息"
        }
        
        let now = Date()
        if now > endDate {
            return "已过期"
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: now, to: endDate)
        
        if let days = components.day {
            if days < 30 {
                return "剩余 \(days) 天"
            } else if days < 365 {
                let months = days / 30
                return "剩余约 \(months) 个月"
            } else {
                let years = days / 365
                let remainingMonths = (days % 365) / 30
                if remainingMonths > 0 {
                    return "剩余约 \(years) 年 \(remainingMonths) 个月"
                } else {
                    return "剩余约 \(years) 年"
                }
            }
        }
        
        return "未知"
    }
}

// WarrantyStatus 枚举已移至 SearchFilters.swift

// 预览支持
extension Order {
    @MainActor
    static var preview: Order {
        let context = PersistenceController.preview.container.viewContext
        let order = Order(context: context)
        order.id = UUID()
        order.orderNumber = "202104150001"
        order.platform = "Apple Store"
        order.orderDate = Calendar.current.date(byAdding: .month, value: -10, to: Date())!
        
        // 设置12个月保修期
        order.warrantyEndDate = Calendar.current.date(byAdding: .month, value: 2, to: Date())!
        
        return order
    }
}