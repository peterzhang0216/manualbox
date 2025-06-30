import Foundation
import CoreData

// MARK: - 统一数据诊断服务
/// 整合DuplicateDetectionService和DataDiagnostics的功能
@MainActor
class UnifiedDataDiagnosticsService: ObservableObject {
    static let shared = UnifiedDataDiagnosticsService()
    
    @Published var isRunning = false
    @Published var currentOperation = ""
    @Published var progress: Float = 0.0
    
    private let context: NSManagedObjectContext
    private let config: DiagnosticConfiguration
    
    private init() {
        self.context = PersistenceController.shared.container.viewContext
        self.config = .default
    }
    
    // MARK: - 主要诊断方法
    
    /// 执行完整的数据诊断
    func performCompleteDiagnosis() async -> ComprehensiveDiagnosticResult {
        isRunning = true
        progress = 0.0
        
        defer {
            Task { @MainActor in
                self.isRunning = false
                self.progress = 0.0
                self.currentOperation = ""
            }
        }
        
        var result = ComprehensiveDiagnosticResult()
        
        // 1. 基础统计 (20%)
        await updateProgress(0.1, "收集基础统计信息...")
        result.basicStats = await collectBasicStatistics()
        await updateProgress(0.2, "基础统计完成")
        
        // 2. 重复检测 (40%)
        await updateProgress(0.3, "检测重复数据...")
        result.duplicateDetection = await performDuplicateDetection()
        await updateProgress(0.4, "重复检测完成")
        
        // 3. 孤立数据检测 (60%)
        await updateProgress(0.5, "检测孤立数据...")
        result.orphanedData = await detectOrphanedData()
        await updateProgress(0.6, "孤立数据检测完成")
        
        // 4. 数据完整性检查 (80%)
        await updateProgress(0.7, "检查数据完整性...")
        result.integrityCheck = await performIntegrityCheck()
        await updateProgress(0.8, "完整性检查完成")
        
        // 5. 性能分析 (100%)
        await updateProgress(0.9, "分析性能指标...")
        result.performanceMetrics = await analyzePerformanceMetrics()
        await updateProgress(1.0, "诊断完成")
        
        return result
    }
    
    /// 快速诊断（仅检测关键问题）
    func performQuickDiagnosis() async -> QuickDiagnosticResult {
        isRunning = true
        currentOperation = "快速诊断中..."
        
        defer {
            Task { @MainActor in
                self.isRunning = false
                self.currentOperation = ""
            }
        }
        
        return await withCheckedContinuation { continuation in
            context.perform {
                let duplicateCategories = self.findDuplicateItems(entityName: "Category", keyPath: "name")
                let duplicateTags = self.findDuplicateItems(entityName: "Tag", keyPath: "name")
                let orphanedProducts = self.countOrphanedItems(entityName: "Product", relationshipPath: "category")
                let orphanedOrders = self.countOrphanedItems(entityName: "Order", relationshipPath: "product")
                let orphanedManuals = self.countOrphanedItems(entityName: "Manual", relationshipPath: "product")
                
                let hasIssues = !duplicateCategories.isEmpty ||
                               !duplicateTags.isEmpty ||
                               orphanedProducts > 0 ||
                               orphanedOrders > 0 ||
                               orphanedManuals > 0
                
                let result = QuickDiagnosticResult(
                    duplicateCategories: duplicateCategories,
                    duplicateTags: duplicateTags,
                    orphanedProducts: orphanedProducts,
                    orphanedOrders: orphanedOrders,
                    orphanedManuals: orphanedManuals,
                    hasIssues: hasIssues
                )
                
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - 自动修复功能
    
    /// 自动修复检测到的问题
    func autoFixIssues(_ diagnosticResult: ComprehensiveDiagnosticResult) async -> FixResult {
        isRunning = true
        var fixResult = FixResult()
        
        defer {
            Task { @MainActor in
                self.isRunning = false
                self.currentOperation = ""
                self.progress = 0.0
            }
        }
        
        // 1. 修复重复数据 (50%)
        await updateProgress(0.1, "修复重复数据...")
        let duplicateFixResult = await fixDuplicateData(diagnosticResult.duplicateDetection)
        fixResult.duplicatesFixed = duplicateFixResult.totalFixed
        fixResult.errors.append(contentsOf: duplicateFixResult.errors)
        await updateProgress(0.5, "重复数据修复完成")
        
        // 2. 清理孤立数据 (100%)
        await updateProgress(0.6, "清理孤立数据...")
        let orphanedFixResult = await cleanupOrphanedData(diagnosticResult.orphanedData)
        fixResult.orphanedDataCleaned = orphanedFixResult.totalCleaned
        fixResult.errors.append(contentsOf: orphanedFixResult.errors)
        await updateProgress(1.0, "数据修复完成")
        
        return fixResult
    }
    
    // MARK: - 具体检测实现
    
    private func collectBasicStatistics() async -> BasicStatistics {
        return await withCheckedContinuation { continuation in
            context.perform {
                let stats = BasicStatistics(
                    totalCategories: self.getEntityCount("Category"),
                    totalTags: self.getEntityCount("Tag"),
                    totalProducts: self.getEntityCount("Product"),
                    totalOrders: self.getEntityCount("Order"),
                    totalManuals: self.getEntityCount("Manual"),
                    totalRepairRecords: self.getEntityCount("RepairRecord"),
                    hasInitializationFlag: UserDefaults.standard.bool(forKey: "ManualBox_HasInitializedDefaultData")
                )
                continuation.resume(returning: stats)
            }
        }
    }
    
    private func performDuplicateDetection() async -> DuplicateDetectionSummary {
        return await withCheckedContinuation { continuation in
            context.perform {
                let duplicateCategories = self.findDuplicateItems(entityName: "Category", keyPath: "name")
                let duplicateTags = self.findDuplicateItems(entityName: "Tag", keyPath: "name")
                let duplicateProducts = self.findDuplicateProducts()
                
                let summary = DuplicateDetectionSummary(
                    duplicateCategories: duplicateCategories,
                    duplicateTags: duplicateTags,
                    duplicateProducts: duplicateProducts,
                    totalDuplicateGroups: duplicateCategories.count + duplicateTags.count + duplicateProducts.count
                )
                
                continuation.resume(returning: summary)
            }
        }
    }
    
    private func detectOrphanedData() async -> OrphanedDataSummary {
        return await withCheckedContinuation { continuation in
            context.perform {
                let summary = OrphanedDataSummary(
                    orphanedProducts: self.countOrphanedItems(entityName: "Product", relationshipPath: "category"),
                    orphanedOrders: self.countOrphanedItems(entityName: "Order", relationshipPath: "product"),
                    orphanedManuals: self.countOrphanedItems(entityName: "Manual", relationshipPath: "product"),
                    emptyCategories: self.findEmptyCategories(),
                    emptyTags: self.findEmptyTags()
                )
                
                continuation.resume(returning: summary)
            }
        }
    }
    
    private func performIntegrityCheck() async -> IntegrityCheckResult {
        return await withCheckedContinuation { continuation in
            context.perform {
                var issues: [String] = []
                
                // 检查数据一致性
                let productsWithoutCategory = self.countOrphanedItems(entityName: "Product", relationshipPath: "category")
                if productsWithoutCategory > 0 {
                    issues.append("\(productsWithoutCategory) 个产品没有分类")
                }
                
                let ordersWithoutProduct = self.countOrphanedItems(entityName: "Order", relationshipPath: "product")
                if ordersWithoutProduct > 0 {
                    issues.append("\(ordersWithoutProduct) 个订单没有关联产品")
                }
                
                let manualsWithoutProduct = self.countOrphanedItems(entityName: "Manual", relationshipPath: "product")
                if manualsWithoutProduct > 0 {
                    issues.append("\(manualsWithoutProduct) 个说明书没有关联产品")
                }
                
                let result = IntegrityCheckResult(
                    isValid: issues.isEmpty,
                    issues: issues,
                    checkedEntities: ["Product", "Order", "Manual", "Category", "Tag"]
                )
                
                continuation.resume(returning: result)
            }
        }
    }
    
    private func analyzePerformanceMetrics() async -> DiagnosticPerformanceMetrics {
        return await withCheckedContinuation { continuation in
            context.perform {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                // 执行一些性能测试查询
                _ = self.getEntityCount("Product")
                _ = self.getEntityCount("Manual")
                
                let queryTime = CFAbsoluteTimeGetCurrent() - startTime
                
                let metrics = DiagnosticPerformanceMetrics(
                    averageQueryTime: queryTime,
                    databaseSize: self.estimateDatabaseSize(),
                    indexEfficiency: self.calculateIndexEfficiency(),
                    memoryUsage: self.getCurrentMemoryUsage()
                )
                
                continuation.resume(returning: metrics)
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func updateProgress(_ progress: Float, _ operation: String) async {
        await MainActor.run {
            self.progress = progress
            self.currentOperation = operation
        }
    }
    
    private func getEntityCount(_ entityName: String) -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        do {
            return try context.count(for: request)
        } catch {
            print("[UnifiedDiagnostics] 获取 \(entityName) 数量失败: \(error)")
            return 0
        }
    }
    
    private func findDuplicateItems(entityName: String, keyPath: String) -> [String] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        
        do {
            let items = try context.fetch(request)
            var nameCount: [String: Int] = [:]
            
            for item in items {
                if let name = item.value(forKey: keyPath) as? String {
                    let normalizedName = config.caseSensitive ? name : name.lowercased()
                    let trimmedName = config.trimWhitespace ? normalizedName.trimmingCharacters(in: .whitespacesAndNewlines) : normalizedName
                    
                    if config.ignoreEmpty && trimmedName.isEmpty { continue }
                    
                    nameCount[trimmedName, default: 0] += 1
                }
            }
            
            return nameCount.compactMap { (name, count) in
                count >= config.minimumDuplicateCount ? name : nil
            }
        } catch {
            print("[UnifiedDiagnostics] 查找重复 \(entityName) 失败: \(error)")
            return []
        }
    }
    
    private func findDuplicateProducts() -> [String] {
        // 在同一分类下查找重复的产品名称
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        
        do {
            let products = try context.fetch(request)
            var categoryProductNames: [String: [String]] = [:]
            
            for product in products {
                let categoryKey = product.category?.name ?? "无分类"
                let productName = product.name ?? "未命名"
                
                categoryProductNames[categoryKey, default: []].append(productName)
            }
            
            var duplicates: [String] = []
            for (category, names) in categoryProductNames {
                let nameCount = Dictionary(grouping: names, by: { $0 }).mapValues { $0.count }
                let categoryDuplicates = nameCount.compactMap { (name, count) in
                    count >= config.minimumDuplicateCount ? "\(category) - \(name)" : nil
                }
                duplicates.append(contentsOf: categoryDuplicates)
            }
            
            return duplicates
        } catch {
            print("[UnifiedDiagnostics] 查找重复产品失败: \(error)")
            return []
        }
    }
    
    private func countOrphanedItems(entityName: String, relationshipPath: String) -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "%K == nil", relationshipPath)
        
        do {
            return try context.count(for: request)
        } catch {
            print("[UnifiedDiagnostics] 统计孤立 \(entityName) 失败: \(error)")
            return 0
        }
    }
    
    private func findEmptyCategories() -> [String] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "products.@count == 0")
        
        do {
            let emptyCategories = try context.fetch(request)
            return emptyCategories.compactMap { $0.name }
        } catch {
            print("[UnifiedDiagnostics] 查找空分类失败: \(error)")
            return []
        }
    }
    
    private func findEmptyTags() -> [String] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "products.@count == 0")
        
        do {
            let emptyTags = try context.fetch(request)
            return emptyTags.compactMap { $0.name }
        } catch {
            print("[UnifiedDiagnostics] 查找空标签失败: \(error)")
            return []
        }
    }
    
    private func estimateDatabaseSize() -> Double {
        // 简单估算数据库大小（MB）
        let productCount = getEntityCount("Product")
        let manualCount = getEntityCount("Manual")
        
        // 假设每个产品平均 1KB，每个说明书平均 10KB
        let estimatedSize = Double(productCount) * 0.001 + Double(manualCount) * 0.01
        return estimatedSize
    }
    
    private func calculateIndexEfficiency() -> Double {
        // 简单的索引效率计算
        return 0.85 // 假设值，实际应该基于查询性能测试
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // MB
        } else {
            return 0.0
        }
    }

    // MARK: - 修复功能实现

    private func fixDuplicateData(_ duplicateDetection: DuplicateDetectionSummary) async -> (totalFixed: Int, errors: [String]) {
        return await withCheckedContinuation { continuation in
            context.perform {
                var totalFixed = 0
                var errors: [String] = []

                // 修复重复分类
                let categoryResult = self.fixDuplicateCategories(duplicateDetection.duplicateCategories)
                totalFixed += categoryResult.fixed
                errors.append(contentsOf: categoryResult.errors)

                // 修复重复标签
                let tagResult = self.fixDuplicateTags(duplicateDetection.duplicateTags)
                totalFixed += tagResult.fixed
                errors.append(contentsOf: tagResult.errors)

                // 保存更改
                if self.context.hasChanges {
                    do {
                        try self.context.save()
                    } catch {
                        errors.append("保存修复结果失败: \(error.localizedDescription)")
                    }
                }

                continuation.resume(returning: (totalFixed: totalFixed, errors: errors))
            }
        }
    }

    private func cleanupOrphanedData(_ orphanedData: OrphanedDataSummary) async -> (totalCleaned: Int, errors: [String]) {
        return await withCheckedContinuation { continuation in
            context.perform {
                var totalCleaned = 0
                var errors: [String] = []

                // 清理空分类
                let emptyCategories = self.deleteEmptyCategories(orphanedData.emptyCategories)
                totalCleaned += emptyCategories.cleaned
                errors.append(contentsOf: emptyCategories.errors)

                // 清理空标签
                let emptyTags = self.deleteEmptyTags(orphanedData.emptyTags)
                totalCleaned += emptyTags.cleaned
                errors.append(contentsOf: emptyTags.errors)

                // 保存更改
                if self.context.hasChanges {
                    do {
                        try self.context.save()
                    } catch {
                        errors.append("保存清理结果失败: \(error.localizedDescription)")
                    }
                }

                continuation.resume(returning: (totalCleaned: totalCleaned, errors: errors))
            }
        }
    }

    private func fixDuplicateCategories(_ duplicateNames: [String]) -> (fixed: Int, errors: [String]) {
        var fixed = 0
        var errors: [String] = []

        for duplicateName in duplicateNames {
            do {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                request.predicate = NSPredicate(format: "name ==[cd] %@", duplicateName)

                let categories = try context.fetch(request)
                if categories.count > 1 {
                    let toKeep = categories.first!
                    let toDelete = Array(categories.dropFirst())

                    // 将要删除的分类的产品转移到保留的分类
                    for category in toDelete {
                        if let products = category.products {
                            for product in products {
                                (product as! Product).category = toKeep
                            }
                        }
                        context.delete(category)
                        fixed += 1
                    }
                }
            } catch {
                errors.append("修复重复分类 '\(duplicateName)' 失败: \(error.localizedDescription)")
            }
        }

        return (fixed: fixed, errors: errors)
    }

    private func fixDuplicateTags(_ duplicateNames: [String]) -> (fixed: Int, errors: [String]) {
        var fixed = 0
        var errors: [String] = []

        for duplicateName in duplicateNames {
            do {
                let request: NSFetchRequest<Tag> = Tag.fetchRequest()
                request.predicate = NSPredicate(format: "name ==[cd] %@", duplicateName)

                let tags = try context.fetch(request)
                if tags.count > 1 {
                    let toKeep = tags.first!
                    let toDelete = Array(tags.dropFirst())

                    // 将要删除的标签的产品关系转移到保留的标签
                    for tag in toDelete {
                        if let products = tag.products {
                            for product in products {
                                (product as! Product).addToTags(toKeep)
                                (product as! Product).removeFromTags(tag)
                            }
                        }
                        context.delete(tag)
                        fixed += 1
                    }
                }
            } catch {
                errors.append("修复重复标签 '\(duplicateName)' 失败: \(error.localizedDescription)")
            }
        }

        return (fixed: fixed, errors: errors)
    }

    private func deleteEmptyCategories(_ emptyNames: [String]) -> (cleaned: Int, errors: [String]) {
        var cleaned = 0
        var errors: [String] = []

        for emptyName in emptyNames {
            do {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                request.predicate = NSPredicate(format: "name == %@ AND products.@count == 0", emptyName)

                let categories = try context.fetch(request)
                for category in categories {
                    context.delete(category)
                    cleaned += 1
                }
            } catch {
                errors.append("删除空分类 '\(emptyName)' 失败: \(error.localizedDescription)")
            }
        }

        return (cleaned: cleaned, errors: errors)
    }

    private func deleteEmptyTags(_ emptyNames: [String]) -> (cleaned: Int, errors: [String]) {
        var cleaned = 0
        var errors: [String] = []

        for emptyName in emptyNames {
            do {
                let request: NSFetchRequest<Tag> = Tag.fetchRequest()
                request.predicate = NSPredicate(format: "name == %@ AND products.@count == 0", emptyName)

                let tags = try context.fetch(request)
                for tag in tags {
                    context.delete(tag)
                    cleaned += 1
                }
            } catch {
                errors.append("删除空标签 '\(emptyName)' 失败: \(error.localizedDescription)")
            }
        }

        return (cleaned: cleaned, errors: errors)
    }
}
