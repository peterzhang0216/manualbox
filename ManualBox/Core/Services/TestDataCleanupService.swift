//
//  TestDataCleanupService.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/6/22.
//

import CoreData
import Foundation

/// 测试数据清理服务
/// 用于删除应用中的所有测试数据，包括默认分类、标签和示例产品
class TestDataCleanupService {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// 清理所有测试数据
    /// - Returns: 清理结果 (成功, 消息, 删除数量)
    func cleanupAllTestData() async -> (success: Bool, message: String, deletedCount: Int) {
        return await withCheckedContinuation { continuation in
            context.perform {
                do {
                    var totalDeleted = 0
                    
                    // 1. 删除所有示例产品
                    let sampleProductsDeleted = self.deleteSampleProducts()
                    totalDeleted += sampleProductsDeleted
                    print("[TestDataCleanup] 删除示例产品: \(sampleProductsDeleted) 个")
                    
                    // 2. 删除默认标签
                    let defaultTagsDeleted = self.deleteDefaultTags()
                    totalDeleted += defaultTagsDeleted
                    print("[TestDataCleanup] 删除默认标签: \(defaultTagsDeleted) 个")
                    
                    // 3. 删除默认分类
                    let defaultCategoriesDeleted = self.deleteDefaultCategories()
                    totalDeleted += defaultCategoriesDeleted
                    print("[TestDataCleanup] 删除默认分类: \(defaultCategoriesDeleted) 个")
                    
                    // 4. 删除所有空的订单和说明书
                    let orphanedDataDeleted = self.deleteOrphanedData()
                    totalDeleted += orphanedDataDeleted
                    print("[TestDataCleanup] 删除孤立数据: \(orphanedDataDeleted) 个")
                    
                    // 5. 保存更改
                    if self.context.hasChanges {
                        try self.context.save()
                        print("[TestDataCleanup] 数据清理完成，共删除 \(totalDeleted) 项")
                    }
                    
                    let message = totalDeleted > 0 ? 
                        "成功清理 \(totalDeleted) 项测试数据" : 
                        "未发现测试数据，应用已是干净状态"
                    
                    continuation.resume(returning: (true, message, totalDeleted))
                    
                } catch {
                    let errorMessage = "清理测试数据时出错: \(error.localizedDescription)"
                    print("[TestDataCleanup] \(errorMessage)")
                    continuation.resume(returning: (false, errorMessage, 0))
                }
            }
        }
    }
    
    /// 删除示例产品
    private func deleteSampleProducts() -> Int {
        // 示例产品的特征：特定的品牌和型号组合
        let sampleProductIdentifiers = [
            ("iPhone 15 Pro", "Apple", "A3102"),
            ("MacBook Pro", "Apple", "M3 Max"),
            ("iPad Air", "Apple", "M2"),
            ("AirPods Pro", "Apple", "第二代"),
            ("小米空气净化器", "小米", "Pro H"),
            ("戴森吸尘器", "Dyson", "V15"),
            ("美的电饭煲", "美的", "MB-WFS4029"),
            ("海尔冰箱", "海尔", "BCD-470WDPG"),
            ("宜家沙发", "IKEA", "KIVIK"),
            ("办公椅", "Herman Miller", "Aeron"),
            ("书桌", "宜家", "BEKANT"),
            ("床垫", "席梦思", "黑标"),
            ("九阳豆浆机", "九阳", "DJ13B-D08D"),
            ("苏泊尔炒锅", "苏泊尔", "PC32H1"),
            ("摩飞榨汁机", "摩飞", "MR9600"),
            ("双立人刀具", "双立人", "Twin Signature"),
            ("跑步机", "舒华", "SH-T5517i"),
            ("哑铃", "海德", "可调节"),
            ("瑜伽垫", "Lululemon", "The Mat 5mm"),
            ("健身手环", "小米", "Mi Band 8"),
            ("登山包", "始祖鸟", "Beta AR 65"),
            ("帐篷", "MSR", "Hubba Hubba NX"),
            ("睡袋", "Mountain Hardwear", "Phantom 32"),
            ("登山鞋", "Salomon", "X Ultra 4"),
            ("行车记录仪", "70迈", "A800S"),
            ("车载充电器", "Anker", "PowerDrive Speed+"),
            ("轮胎", "米其林", "Pilot Sport 4"),
            ("机油", "美孚", "1号全合成"),
            ("蓝牙音箱", "Bose", "SoundLink Revolve+"),
            ("移动电源", "Anker", "PowerCore 26800"),
            ("无线鼠标", "罗技", "MX Master 3S"),
            ("机械键盘", "Cherry", "MX Keys")
        ]
        
        do {
            let request: NSFetchRequest<Product> = Product.fetchRequest()
            let allProducts = try context.fetch(request)
            
            // 筛选出示例产品
            let sampleProducts = allProducts.filter { product in
                guard let productName = product.name,
                      let productBrand = product.brand,
                      let productModel = product.model else {
                    return false
                }
                
                return sampleProductIdentifiers.contains { (name, brand, model) in
                    productName == name && productBrand == brand && productModel == model
                }
            }
            
            // 删除示例产品及其关联数据
            for product in sampleProducts {
                // 删除关联的订单
                if let order = product.order {
                    context.delete(order)
                }
                
                // 删除关联的说明书
                if let manuals = product.manuals as? Set<Manual> {
                    for manual in manuals {
                        context.delete(manual)
                    }
                }
                
                // 删除产品本身
                context.delete(product)
            }
            
            return sampleProducts.count
            
        } catch {
            print("[TestDataCleanup] 删除示例产品时出错: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// 删除默认标签
    private func deleteDefaultTags() -> Int {
        let defaultTagNames = ["需维修", "重要", "收藏", "新购", "待退货"]
        
        do {
            let request: NSFetchRequest<Tag> = Tag.fetchRequest()
            request.predicate = NSPredicate(format: "name IN %@", defaultTagNames)
            let defaultTags = try context.fetch(request)
            
            for tag in defaultTags {
                context.delete(tag)
            }
            
            return defaultTags.count
            
        } catch {
            print("[TestDataCleanup] 删除默认标签时出错: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// 删除默认分类
    private func deleteDefaultCategories() -> Int {
        let defaultCategoryNames = ["电子产品", "家用电器", "家具家私", "厨房用品", "健身器材", "户外装备", "汽车配件", "其他"]
        
        do {
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            request.predicate = NSPredicate(format: "name IN %@", defaultCategoryNames)
            let defaultCategories = try context.fetch(request)
            
            for category in defaultCategories {
                // 将该分类下的产品的分类设为 nil
                if let products = category.products as? Set<Product> {
                    for product in products {
                        product.category = nil
                    }
                }
                context.delete(category)
            }
            
            return defaultCategories.count
            
        } catch {
            print("[TestDataCleanup] 删除默认分类时出错: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// 删除孤立的数据（没有关联产品的订单、说明书等）
    private func deleteOrphanedData() -> Int {
        var deletedCount = 0
        
        do {
            // 删除没有关联产品的订单
            let orphanedOrdersRequest: NSFetchRequest<Order> = Order.fetchRequest()
            orphanedOrdersRequest.predicate = NSPredicate(format: "product == nil")
            let orphanedOrders = try context.fetch(orphanedOrdersRequest)
            
            for order in orphanedOrders {
                context.delete(order)
                deletedCount += 1
            }
            
            // 删除没有关联产品的说明书
            let orphanedManualsRequest: NSFetchRequest<Manual> = Manual.fetchRequest()
            orphanedManualsRequest.predicate = NSPredicate(format: "product == nil")
            let orphanedManuals = try context.fetch(orphanedManualsRequest)
            
            for manual in orphanedManuals {
                context.delete(manual)
                deletedCount += 1
            }
            
            // 删除没有关联订单的维修记录
            let orphanedRepairRecordsRequest: NSFetchRequest<RepairRecord> = RepairRecord.fetchRequest()
            orphanedRepairRecordsRequest.predicate = NSPredicate(format: "order == nil")
            let orphanedRepairRecords = try context.fetch(orphanedRepairRecordsRequest)
            
            for repairRecord in orphanedRepairRecords {
                context.delete(repairRecord)
                deletedCount += 1
            }
            
        } catch {
            print("[TestDataCleanup] 删除孤立数据时出错: \(error.localizedDescription)")
        }
        
        return deletedCount
    }
}
