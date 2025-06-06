//
//  RepairRecord+Extensions.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import Foundation
import CoreData
import SwiftUI

extension RepairRecord {
    // MARK: - 便利属性
    var recordDate: Date {
        get { date ?? Date() }
        set { date = newValue }
    }
    
    var recordDetails: String {
        get { details ?? "" }
        set { details = newValue }
    }
    
    var recordCost: Decimal {
        get { cost?.decimalValue ?? 0 }
        set { cost = NSDecimalNumber(decimal: newValue) }
    }
    
    // 格式化的维修花费
    var formattedCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: cost ?? NSDecimalNumber.zero) ?? "¥0.00"
    }
    
    // 格式化的维修日期
    var formattedDate: String {
        guard let date = date else { return "未知日期" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // MARK: - 工厂方法
    static func createRepairRecord(
        in context: NSManagedObjectContext,
        date: Date,
        details: String,
        cost: Decimal,
        order: Order? = nil
    ) -> RepairRecord {
        let record = RepairRecord(context: context)
        record.id = UUID()
        record.date = date
        record.details = details
        record.cost = NSDecimalNumber(decimal: cost)
        record.order = order
        
        return record
    }
}

// 预览支持
extension RepairRecord {
    @MainActor
    static var preview: RepairRecord {
        let context = PersistenceController.preview.container.viewContext
        let record = RepairRecord(context: context)
        record.id = UUID()
        record.date = Date()
        record.details = "屏幕更换维修"
        record.cost = NSDecimalNumber(value: 1200)
        return record
    }
}