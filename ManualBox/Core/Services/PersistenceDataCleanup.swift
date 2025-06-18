//
//  PersistenceDataCleanup.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import CoreData

// MARK: - 数据清理
extension PersistenceController {
    
    /// 清理重复的分类和标签数据
    func removeDuplicateData() {
        let context = container.viewContext

        context.performAndWait {
            // 清理重复分类
            removeDuplicateCategories(in: context)

            // 清理重复标签
            removeDuplicateTags(in: context)

            // 保存清理结果
            if context.hasChanges {
                do {
                    try context.save()
                    print("[Persistence] 重复数据清理完成")
                } catch {
                    print("[Persistence] 清理重复数据时出错: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 清理重复分类（改进版本）
    private func removeDuplicateCategories(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Category.name, ascending: true)
        ]

        do {
            let categories = try context.fetch(request)
            var nameToCategory: [String: Category] = [:]
            var duplicatesToDelete: [Category] = []

            for category in categories {
                let name = (category.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                if name.isEmpty {
                    // 删除空名称的分类
                    duplicatesToDelete.append(category)
                    print("[Persistence] 发现空名称分类，将删除")
                    continue
                }

                if let existingCategory = nameToCategory[name] {
                    // 发现重复，决定保留哪一个
                    let categoryToKeep = chooseCategoryToKeep(existing: existingCategory, duplicate: category)
                    let categoryToDelete = (categoryToKeep == existingCategory) ? category : existingCategory

                    // 转移产品关联到保留的分类
                    transferProductsToCategory(from: categoryToDelete, to: categoryToKeep, in: context)

                    duplicatesToDelete.append(categoryToDelete)
                    nameToCategory[name] = categoryToKeep

                    print("[Persistence] 发现重复分类: \(name)，保留较早创建的版本")
                } else {
                    nameToCategory[name] = category
                }
            }

            // 删除重复项
            for duplicate in duplicatesToDelete {
                context.delete(duplicate)
            }

            if !duplicatesToDelete.isEmpty {
                print("[Persistence] 已删除 \(duplicatesToDelete.count) 个重复分类")
            }
        } catch {
            print("[Persistence] 清理重复分类时出错: \(error.localizedDescription)")
        }
    }

    /// 清理重复标签（改进版本）
    private func removeDuplicateTags(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Tag.name, ascending: true)
        ]

        do {
            let tags = try context.fetch(request)
            var nameToTag: [String: Tag] = [:]
            var duplicatesToDelete: [Tag] = []

            for tag in tags {
                let name = (tag.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                if name.isEmpty {
                    // 删除空名称的标签
                    duplicatesToDelete.append(tag)
                    print("[Persistence] 发现空名称标签，将删除")
                    continue
                }

                if let existingTag = nameToTag[name] {
                    // 发现重复，决定保留哪一个
                    let tagToKeep = chooseTagToKeep(existing: existingTag, duplicate: tag)
                    let tagToDelete = (tagToKeep == existingTag) ? tag : existingTag

                    // 转移产品关联到保留的标签
                    transferProductsToTag(from: tagToDelete, to: tagToKeep, in: context)

                    duplicatesToDelete.append(tagToDelete)
                    nameToTag[name] = tagToKeep

                    print("[Persistence] 发现重复标签: \(name)，保留较早创建的版本")
                } else {
                    nameToTag[name] = tag
                }
            }

            // 删除重复项
            for duplicate in duplicatesToDelete {
                context.delete(duplicate)
            }

            if !duplicatesToDelete.isEmpty {
                print("[Persistence] 已删除 \(duplicatesToDelete.count) 个重复标签")
            }
        } catch {
            print("[Persistence] 清理重复标签时出错: \(error.localizedDescription)")
        }
    }

    /// 公开的清理重复数据方法，可以在设置中调用
    @MainActor
    func cleanupDuplicateData() async {
        removeDuplicateData()
    }

    // MARK: - 辅助方法

    /// 选择要保留的分类（优先保留有更多产品关联的）
    private func chooseCategoryToKeep(existing: Category, duplicate: Category) -> Category {
        let existingProductCount = (existing.products as? Set<Product>)?.count ?? 0
        let duplicateProductCount = (duplicate.products as? Set<Product>)?.count ?? 0

        // 优先保留有更多产品的分类
        if existingProductCount != duplicateProductCount {
            return existingProductCount > duplicateProductCount ? existing : duplicate
        }

        // 如果产品数量相同，保留第一个（existing）
        return existing
    }

    /// 选择要保留的标签（优先保留有更多产品关联的）
    private func chooseTagToKeep(existing: Tag, duplicate: Tag) -> Tag {
        let existingProductCount = (existing.products as? Set<Product>)?.count ?? 0
        let duplicateProductCount = (duplicate.products as? Set<Product>)?.count ?? 0

        // 优先保留有更多产品的标签
        if existingProductCount != duplicateProductCount {
            return existingProductCount > duplicateProductCount ? existing : duplicate
        }

        // 如果产品数量相同，保留第一个（existing）
        return existing
    }

    /// 将产品从一个分类转移到另一个分类
    private func transferProductsToCategory(from source: Category, to target: Category, in context: NSManagedObjectContext) {
        guard let sourceProducts = source.products as? Set<Product> else { return }

        for product in sourceProducts {
            product.category = target
            print("[Persistence] 转移产品 '\(product.name ?? "未知")' 从分类 '\(source.name ?? "")' 到 '\(target.name ?? "")'")
        }
    }

    /// 将产品从一个标签转移到另一个标签
    private func transferProductsToTag(from source: Tag, to target: Tag, in context: NSManagedObjectContext) {
        guard let sourceProducts = source.products as? Set<Product> else { return }

        for product in sourceProducts {
            // 移除旧标签关联
            product.removeFromTags(source)
            // 添加新标签关联（如果还没有的话）
            if let targetProducts = target.products as? Set<Product>, !targetProducts.contains(product) {
                product.addToTags(target)
                print("[Persistence] 转移产品 '\(product.name ?? "未知")' 从标签 '\(source.name ?? "")' 到 '\(target.name ?? "")'")
            }
        }
    }
} 