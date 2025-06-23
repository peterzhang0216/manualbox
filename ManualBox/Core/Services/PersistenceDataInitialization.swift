//
//  PersistenceDataInitialization.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import CoreData

// MARK: - 数据初始化
extension PersistenceController {
    
    // 初始化默认数据（兼容旧版本，会清理重复数据）
    // 注意：此方法主要用于数据修复和兼容性，不会检查初始化标记
    func initializeDefaultData() {
        print("[Persistence] 开始初始化默认数据...")

        // 清理重复数据
        removeDuplicateData()

        // 创建默认数据
        let context = container.viewContext

        // 分别检查分类和标签是否为空
        let categoriesRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
        let categoriesCount = (try? context.count(for: categoriesRequest)) ?? 0

        let tagsRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        let tagsCount = (try? context.count(for: tagsRequest)) ?? 0

        var needsSave = false

        // 只有当分类表为空时才创建默认分类
        if categoriesCount == 0 {
            print("[Persistence] 创建默认分类...")
            Category.createDefaultCategories(in: context)
            needsSave = true
        } else {
            print("[Persistence] 分类已存在，跳过创建默认分类")
        }

        // 只有当标签表为空时才创建默认标签
        if tagsCount == 0 {
            print("[Persistence] 创建默认标签...")
            Tag.createDefaultTags(in: context)
            needsSave = true
        } else {
            print("[Persistence] 标签已存在，跳过创建默认标签")
        }

        // 保存更改
        if needsSave {
            do {
                try context.save()
                print("[Persistence] 默认数据初始化完成")
            } catch {
                print("[Persistence] 保存默认数据时出错: \(error.localizedDescription)")
            }
        }

        /* 以下代码仅用于开发和测试
        let context = container.viewContext

        // 分别检查分类和标签是否为空
        let categoriesRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
        let categoriesCount = (try? context.count(for: categoriesRequest)) ?? 0

        let tagsRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        let tagsCount = (try? context.count(for: tagsRequest)) ?? 0

        var needsSave = false

        // 只有当分类表为空时才创建默认分类
        if categoriesCount == 0 {
            print("[Persistence] 创建默认分类...")
            Category.createDefaultCategories(in: context)
            needsSave = true
        } else {
            print("[Persistence] 分类已存在，跳过创建默认分类")
        }

        // 只有当标签表为空时才创建默认标签
        if tagsCount == 0 {
            print("[Persistence] 创建默认标签...")
            Tag.createDefaultTags(in: context)
            needsSave = true
        } else {
            print("[Persistence] 标签已存在，跳过创建默认标签")
        }

        // 只有在需要时才保存
        if needsSave {
            Task { @MainActor in
                await saveContext()
            }
        }
        */
    }

    // 只在需要时初始化默认数据（不清理重复数据，更温和的方式）
    // 发布版本：已禁用默认数据创建
    func initializeDefaultDataIfNeeded() {
        print("[Persistence] 发布版本：默认数据创建已禁用")

        // 标记为已完成首次初始化（避免重复调用）
        UserDefaults.standard.set(true, forKey: "ManualBox_HasInitializedDefaultData")
        print("[Persistence] 首次初始化完成，已设置标记")

        /* 以下代码仅用于开发和测试
        let context = container.viewContext

        // 检查是否已经进行过首次初始化
        let hasInitialized = UserDefaults.standard.bool(forKey: "ManualBox_HasInitializedDefaultData")

        if hasInitialized {
            print("[Persistence] 已完成首次初始化，跳过默认数据创建")
            return
        }

        // 分别检查分类和标签是否为空
        let categoriesRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
        let categoriesCount = (try? context.count(for: categoriesRequest)) ?? 0

        let tagsRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        let tagsCount = (try? context.count(for: tagsRequest)) ?? 0

        var needsSave = false

        // 只有当分类表为空时才创建默认分类
        if categoriesCount == 0 {
            print("[Persistence] 首次启动，创建默认分类...")
            Category.createDefaultCategories(in: context)
            needsSave = true
        } else {
            print("[Persistence] 分类已存在 (\(categoriesCount) 个)，跳过创建")
        }

        // 只有当标签表为空时才创建默认标签
        if tagsCount == 0 {
            print("[Persistence] 首次启动，创建默认标签...")
            Tag.createDefaultTags(in: context)
            needsSave = true
        } else {
            print("[Persistence] 标签已存在 (\(tagsCount) 个)，跳过创建")
        }

        // 只有在需要时才保存
        if needsSave {
            do {
                try context.save()
                print("[Persistence] 默认数据保存成功")
            } catch {
                print("[Persistence] 保存默认数据时出错: \(error.localizedDescription)")
            }
        }

        // 标记已完成首次初始化
        UserDefaults.standard.set(true, forKey: "ManualBox_HasInitializedDefaultData")
        print("[Persistence] 首次初始化完成，已设置标记")
        */
    }

    // 重置初始化标记（用于重置应用数据时）
    func resetInitializationFlag() {
        UserDefaults.standard.removeObject(forKey: "ManualBox_HasInitializedDefaultData")
        print("[Persistence] 已重置初始化标记")
    }

    // 检查是否已完成首次初始化
    func hasCompletedInitialSetup() -> Bool {
        return UserDefaults.standard.bool(forKey: "ManualBox_HasInitializedDefaultData")
    }
} 