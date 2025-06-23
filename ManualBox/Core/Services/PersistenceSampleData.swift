//
//  PersistenceSampleData.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import CoreData

// MARK: - 示例数据创建
extension PersistenceController {

    /// 创建示例产品数据（用于测试和演示）
    /// 发布版本中禁用自动创建示例数据
    func createSampleData() {
        // 发布版本不创建示例数据，保持应用干净状态
        print("[Persistence] 示例数据创建已禁用（发布版本）")
        return

        /* 以下代码仅用于开发和测试
        let context = container.viewContext

        context.performAndWait {
            do {
                // 检查是否已有产品数据
                let productRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Product")
                let productCount = try context.count(for: productRequest)

                if productCount > 0 {
                    print("[Persistence] 已存在产品数据，跳过示例数据创建")
                    return
                }

                // 获取所有分类和标签
                let categoriesRequest: NSFetchRequest<Category> = Category.fetchRequest()
                let categories = try context.fetch(categoriesRequest)

                let tagsRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
                let tags = try context.fetch(tagsRequest)

                // 为每个分类创建示例产品
                createSampleProductsForCategories(categories, tags: tags, in: context)

                // 保存更改
                if context.hasChanges {
                    try context.save()
                    print("[Persistence] 示例数据创建完成")
                }

            } catch {
                print("[Persistence] 创建示例数据时出错: \(error.localizedDescription)")
            }
        }
        */
    }

    /// 删除所有示例数据
    @MainActor
    func deleteSampleData() async -> (success: Bool, message: String, deletedCount: Int) {
        let context = container.viewContext

        return await withCheckedContinuation { continuation in
            context.perform {
                do {
                    // 识别示例数据
                    let sampleProducts = self.identifySampleProducts(in: context)
                    let deletedCount = sampleProducts.count

                    if sampleProducts.isEmpty {
                        continuation.resume(returning: (true, "未发现示例数据", 0))
                        return
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

                    // 保存更改
                    try context.save()

                    let message = "成功删除 \(deletedCount) 个示例产品及其关联数据"
                    print("[Persistence] \(message)")
                    continuation.resume(returning: (true, message, deletedCount))

                } catch {
                    let errorMessage = "删除示例数据时出错: \(error.localizedDescription)"
                    print("[Persistence] \(errorMessage)")
                    continuation.resume(returning: (false, errorMessage, 0))
                }
            }
        }
    }

    /// 检查是否存在示例数据
    @MainActor
    func hasSampleData() async -> Bool {
        let context = container.viewContext

        return await withCheckedContinuation { continuation in
            context.perform {
                let sampleProducts = self.identifySampleProducts(in: context)
                continuation.resume(returning: !sampleProducts.isEmpty)
            }
        }
    }

    /// 获取示例数据统计信息
    @MainActor
    func getSampleDataInfo() async -> (productCount: Int, categoryCount: Int, hasOrders: Bool) {
        let context = container.viewContext

        return await withCheckedContinuation { continuation in
            context.perform {
                let sampleProducts = self.identifySampleProducts(in: context)
                let categories = Set(sampleProducts.compactMap { $0.category })
                let hasOrders = sampleProducts.contains { $0.order != nil }

                continuation.resume(returning: (
                    productCount: sampleProducts.count,
                    categoryCount: categories.count,
                    hasOrders: hasOrders
                ))
            }
        }
    }

    /// 识别示例产品
    private func identifySampleProducts(in context: NSManagedObjectContext) -> [Product] {
        let request: NSFetchRequest<Product> = Product.fetchRequest()

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

            return sampleProducts

        } catch {
            print("[Persistence] 识别示例产品时出错: \(error.localizedDescription)")
            return []
        }
    }

    /// 为分类创建示例产品
    private func createSampleProductsForCategories(_ categories: [Category], tags: [Tag], in context: NSManagedObjectContext) {
        // 示例产品数据
        let sampleProducts: [String: [(name: String, brand: String, model: String, tagNames: [String])]] = [
            "电子产品": [
                ("iPhone 15 Pro", "Apple", "A3102", ["新购", "重要"]),
                ("MacBook Pro", "Apple", "M3 Max", ["重要", "收藏"]),
                ("iPad Air", "Apple", "M2", ["新购"]),
                ("AirPods Pro", "Apple", "第二代", ["收藏"])
            ],
            "家用电器": [
                ("小米空气净化器", "小米", "Pro H", ["新购"]),
                ("戴森吸尘器", "Dyson", "V15", ["重要", "收藏"]),
                ("美的电饭煲", "美的", "MB-WFS4029", ["需维修"]),
                ("海尔冰箱", "海尔", "BCD-470WDPG", ["重要"])
            ],
            "家具家私": [
                ("宜家沙发", "IKEA", "KIVIK", ["收藏"]),
                ("办公椅", "Herman Miller", "Aeron", ["重要", "收藏"]),
                ("书桌", "宜家", "BEKANT", ["新购"]),
                ("床垫", "席梦思", "黑标", ["重要"])
            ],
            "厨房用品": [
                ("九阳豆浆机", "九阳", "DJ13B-D08D", ["需维修"]),
                ("苏泊尔炒锅", "苏泊尔", "PC32H1", ["收藏"]),
                ("摩飞榨汁机", "摩飞", "MR9600", ["新购"]),
                ("双立人刀具", "双立人", "Twin Signature", ["重要"])
            ],
            "健身器材": [
                ("跑步机", "舒华", "SH-T5517i", ["重要", "收藏"]),
                ("哑铃", "海德", "可调节", ["新购"]),
                ("瑜伽垫", "Lululemon", "The Mat 5mm", ["收藏"]),
                ("健身手环", "小米", "Mi Band 8", ["新购"])
            ],
            "户外装备": [
                ("登山包", "始祖鸟", "Beta AR 65", ["重要", "收藏"]),
                ("帐篷", "MSR", "Hubba Hubba NX", ["收藏"]),
                ("睡袋", "Mountain Hardwear", "Phantom 32", ["新购"]),
                ("登山鞋", "Salomon", "X Ultra 4", ["重要"])
            ],
            "汽车配件": [
                ("行车记录仪", "70迈", "A800S", ["新购", "重要"]),
                ("车载充电器", "Anker", "PowerDrive Speed+", ["收藏"]),
                ("轮胎", "米其林", "Pilot Sport 4", ["需维修"]),
                ("机油", "美孚", "1号全合成", ["新购"])
            ],
            "其他": [
                ("蓝牙音箱", "Bose", "SoundLink Revolve+", ["收藏"]),
                ("移动电源", "Anker", "PowerCore 26800", ["新购"]),
                ("无线鼠标", "罗技", "MX Master 3S", ["重要"]),
                ("机械键盘", "Cherry", "MX Keys", ["收藏"])
            ]
        ]

        // 为每个分类创建产品
        for category in categories {
            guard let categoryName = category.name,
                  let products = sampleProducts[categoryName] else { continue }

            for productData in products {
                // 创建产品
                let product = Product.createProduct(
                    in: context,
                    name: productData.name,
                    brand: productData.brand,
                    model: productData.model,
                    category: category
                )

                // 添加标签
                for tagName in productData.tagNames {
                    if let tag = tags.first(where: { $0.name == tagName }) {
                        product.addTag(tag)
                    }
                }

                // 添加一些随机的创建时间（过去30天内）
                let randomDaysAgo = Int.random(in: 0...30)
                product.createdAt = Calendar.current.date(byAdding: .day, value: -randomDaysAgo, to: Date())
                product.updatedAt = product.createdAt

                // 为部分产品添加订单信息
                if Bool.random() && productData.name.contains("iPhone") || productData.name.contains("MacBook") || productData.name.contains("iPad") {
                    createSampleOrder(for: product, in: context)
                }

                print("[Persistence] 创建示例产品: \(productData.name) - \(categoryName)")
            }
        }
    }

    /// 为产品创建示例订单
    private func createSampleOrder(for product: Product, in context: NSManagedObjectContext) {
        let platforms = ["Apple Store", "京东", "天猫", "苏宁易购", "拼多多"]
        let randomPlatform = platforms.randomElement() ?? "Apple Store"

        let orderNumber = "ORD\(Int.random(in: 100000...999999))"
        let orderDate = Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...90), to: Date()) ?? Date()
        let warrantyPeriod = [12, 24, 36].randomElement() ?? 12

        let _ = Order.createOrder(
            in: context,
            orderNumber: orderNumber,
            platform: randomPlatform,
            orderDate: orderDate,
            warrantyPeriod: warrantyPeriod,
            product: product
        )

        print("[Persistence] 为产品 \(product.name ?? "") 创建订单: \(orderNumber)")
    }

    /// 完全重置数据库（包括删除物理文件）
    func completelyResetDatabase() async -> (success: Bool, message: String) {
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    print("[Persistence] 开始完全重置数据库...")

                    // 1. 先强制删除所有已知的示例产品
                    let context = container.viewContext
                    await context.perform {
                        do {
                            // 强制删除特定的示例产品
                            self.forceDeleteKnownSampleProducts(in: context)

                            // 删除所有实体的数据
                            let entityNames = ["Product", "Category", "Tag", "Order", "Manual", "RepairRecord"]
                            var totalDeleted = 0

                            for entityName in entityNames {
                                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                                let deletedCount = result?.result as? Int ?? 0
                                totalDeleted += deletedCount
                                print("[Persistence] 删除 \(entityName): \(deletedCount) 个")
                            }

                            // 强制重置上下文
                            context.reset()

                            // 保存更改
                            if context.hasChanges {
                                try context.save()
                            }

                        } catch {
                            print("[Persistence] 清理内存数据时出错: \(error.localizedDescription)")
                        }
                    }

                    // 2. 删除物理数据库文件
                    let fileManager = FileManager.default
                    let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    let appDataURL = appSupportURL.appendingPathComponent("ManualBox")

                    // 删除所有相关文件
                    let filesToDelete = [
                        "ManualBox.sqlite",
                        "ManualBox.sqlite-wal",
                        "ManualBox.sqlite-shm"
                    ]

                    var deletedFiles = 0
                    for fileName in filesToDelete {
                        let fileURL = appDataURL.appendingPathComponent(fileName)
                        if fileManager.fileExists(atPath: fileURL.path) {
                            try fileManager.removeItem(at: fileURL)
                            deletedFiles += 1
                            print("[Persistence] 删除文件: \(fileName)")
                        }
                    }

                    // 3. 重置所有UserDefaults标记
                    let keysToReset = [
                        "ManualBox_HasInitializedDefaultData",
                        "ManualBox_LastInitializedVersion"
                    ]

                    for key in keysToReset {
                        UserDefaults.standard.removeObject(forKey: key)
                    }
                    UserDefaults.standard.synchronize()

                    // 4. 使用统一的数据初始化管理器重新创建默认数据
                    let initResult = await DataInitializationManager.shared.forceReinitialize(in: context)
                    print("[Persistence] 数据重新初始化结果: \(initResult.summary)")

                    let message = "数据库完全重置成功，删除了 \(deletedFiles) 个文件，并重新创建了默认分类和标签"
                    print("[Persistence] \(message)")
                    continuation.resume(returning: (true, message))

                } catch {
                    let message = "完全重置数据库时出错: \(error.localizedDescription)"
                    print("[Persistence] 错误: \(message)")
                    continuation.resume(returning: (false, message))
                }
            }
        }
    }

    /// 强制删除已知的示例产品
    private func forceDeleteKnownSampleProducts(in context: NSManagedObjectContext) {
        let knownSampleProducts = [
            ("iPhone", "Apple"),
            ("iPhone 15 Pro", "Apple"),
            ("轮胎", "米其林"),
            ("戴森吹风机", "戴森"),
            ("戴森吸尘器", "Dyson"),
            ("MacBook Pro", "Apple"),
            ("iPad", "Apple"),
            ("AirPods", "Apple")
        ]

        do {
            let request: NSFetchRequest<Product> = Product.fetchRequest()
            let allProducts = try context.fetch(request)

            var deletedCount = 0
            for product in allProducts {
                let productName = product.name ?? ""
                let productBrand = product.brand ?? ""

                // 检查是否匹配已知的示例产品
                let shouldDelete = knownSampleProducts.contains { (name, brand) in
                    productName.contains(name) && productBrand.contains(brand)
                }

                if shouldDelete {
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
                    deletedCount += 1
                    print("[Persistence] 强制删除示例产品: \(productName) - \(productBrand)")
                }
            }

            if deletedCount > 0 {
                try context.save()
                print("[Persistence] 强制删除了 \(deletedCount) 个已知示例产品")
            }

        } catch {
            print("[Persistence] 强制删除示例产品时出错: \(error.localizedDescription)")
        }
    }
} 