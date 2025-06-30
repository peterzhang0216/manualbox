//
//  ProductDetailViewHelpers.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI
import CoreData

// MARK: - 产品扩展已移至Product+Extensions.swift
// MARK: - 标签扩展已移至Tag+Extensions.swift

// 保留非重复的扩展
extension Product {
    

}

// MARK: - Category扩展已移至Category+Extensions.swift

// MARK: - 颜色扩展
extension Color {
    
    /// 从十六进制字符串创建颜色
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - PersistenceController 预览扩展
extension PersistenceController {
    
    /// 创建预览用的产品
    func previewProduct() -> Product {
        let context = container.viewContext
        let product = Product(context: context)
        product.id = UUID()
        product.name = "产品名称"
        product.brand = "品牌"
        product.model = "型号"
        
        // 创建预览用的订单
        let order = Order(context: context)
        order.id = UUID()
        order.orderNumber = "ORDER-12345"
        order.platform = "淘宝"
        order.orderDate = Date()
        order.warrantyEndDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        product.order = order
        
        // 创建预览用的分类
        let category = Category(context: context)
        category.id = UUID()
        category.name = "电子产品"
        category.icon = "laptopcomputer"
        product.category = category
        
        return product
    }
}

// MARK: - 平台图片类型别名和图片扩展已移至PlatformImage.swift