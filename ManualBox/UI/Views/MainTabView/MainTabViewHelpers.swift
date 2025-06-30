//
//  MainTabViewHelpers.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/5/10.
//

import SwiftUI
import CoreData
import Combine

// MARK: - Main Tab View Helpers

extension MainTabView {
    
    // MARK: - 计算属性
    
    var computedColorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var computedAccentColor: Color {
        switch accentColorKey {
        case "accentColor": return .accentColor
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        case "red": return .red
        case "teal": return .teal
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "mint": return .mint
        case "cyan": return .cyan
        case "brown": return .brown
        default: return .accentColor
        }
    }
    
    var settingsDetailBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor).opacity(0.5)
        #else
        return Color(UIColor.systemBackground).opacity(0.5)
        #endif
    }
    
    var themeDisplayName: String {
        switch appTheme {
        case "light": return "浅色"
        case "dark": return "深色"
        default: return "跟随系统"
        }
    }
    
    var accentColorDisplayName: String {
        switch accentColorKey {
        case "blue": return "蓝色"
        case "green": return "绿色"
        case "orange": return "橙色"
        case "pink": return "粉色"
        case "purple": return "紫色"
        case "red": return "红色"
        default: return "系统默认"
        }
    }
    
    // MARK: - 辅助方法
    
    func deleteProducts(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredProducts[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                // 处理错误
                print("删除产品失败: \(error)")
            }
        }
    }
    
    func setupNotificationObservers() {
        // 产品导航通知
        notificationObserver.observe(.showProduct) { object in
            if let _ = object as? UUID,
               case let currentValue = selectedTab,
               !(currentValue == nil || (currentValue != nil && 
                    (currentValue! == .main(0) || 
                     (currentValue! == .main(1) && categories.isEmpty) || 
                     (currentValue! == .main(2) && tags.isEmpty)))) {
                // 如果不是在产品列表视图，则转到产品列表
                selectedTab = .main(0)
            }
        }
        
        // 分类导航通知
        notificationObserver.observe(.showCategory) { object in
            if let categoryId = object as? UUID,
               let _ = categories.first(where: { $0.id == categoryId }) {
                selectedTab = .category(categoryId)
            }
        }
        
        // 标签导航通知
        notificationObserver.observe(.showTag) { object in
            if let tagId = object as? UUID,
               let _ = tags.first(where: { $0.id == tagId }) {
                selectedTab = .tag(tagId)
            }
        }
    }
    
    func setupProductSelectionObserver() {
        // 监听产品选择管理器的变化
        productSelectionManager.$currentProduct
            .receive(on: DispatchQueue.main)
            .sink { newProduct in
                selectedProduct = newProduct
                // 更新详情面板状态
                if let product = newProduct {
                    detailPanelStateManager.showProductDetail(product)
                } else {
                    detailPanelStateManager.reset()
                }
            }
            .store(in: &cancellables)
    }
    
    func handleDetailPanelStateChange(_ state: DetailPanelState) {
        switch state {
        case .addCategory, .editCategory, .categoryDetail, .categoryList:
            // 当进入分类相关状态时，切换到分类管理页面
            selectedTab = .main(1)
        case .addTag, .editTag, .tagDetail, .tagList:
            // 当进入标签相关状态时，切换到标签管理页面
            selectedTab = .main(2)
        case .dataExport, .dataImport, .dataBackup:
            // 当进入数据管理相关状态时，切换到数据设置页面
            selectedTab = .settings(.dataManagement)
        case .addProduct(let defaultCategory, let defaultTag):
            // 当添加产品时，根据上下文决定是否需要切换页面
            if let defaultCategory = defaultCategory {
                // 如果有默认分类，且当前不在该分类页面，则切换到该分类页面
                if case .category(let currentCategoryId) = selectedTab,
                   currentCategoryId == defaultCategory.id {
                    // 已经在正确的分类页面，不需要切换
                    break
                } else if let categoryId = defaultCategory.id {
                    // 切换到对应的分类页面
                    selectedTab = .category(categoryId)
                }
            } else if let defaultTag = defaultTag {
                // 如果有默认标签，且当前不在该标签页面，则切换到该标签页面
                if case .tag(let currentTagId) = selectedTab,
                   currentTagId == defaultTag.id {
                    // 已经在正确的标签页面，不需要切换
                    break
                } else if let tagId = defaultTag.id {
                    // 切换到对应的标签页面
                    selectedTab = .tag(tagId)
                }
            } else {
                // 没有默认分类或标签，切换到产品列表页面
                selectedTab = .main(0)
            }
        case .editProduct(_):
            // 编辑产品时保持当前页面不变
            break
        case .productDetail:
            // 产品详情不需要改变中间栏
            break
        case .empty:
            // 空状态不需要改变中间栏
            break
        }
    }
}