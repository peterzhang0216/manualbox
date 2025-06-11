//
//  ProductFilterLogic.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
import CoreData

struct ProductFilterLogic {
    static func filterProducts(
        products: [Product],
        searchText: String,
        searchFilters: SearchFilters
    ) -> [Product] {
        var result = products
        
        // 首先应用搜索文本过滤
        if !searchText.isEmpty {
            result = result.filter { product in
                var shouldInclude = false
                let searchLower = searchText.lowercased()
                
                // 根据搜索范围设置进行过滤
                if searchFilters.searchInName, let name = product.name?.lowercased(), name.contains(searchLower) {
                    shouldInclude = true
                }
                
                if searchFilters.searchInBrand, let brand = product.brand?.lowercased(), brand.contains(searchLower) {
                    shouldInclude = true
                }
                
                if searchFilters.searchInModel, let model = product.model?.lowercased(), model.contains(searchLower) {
                    shouldInclude = true
                }
                
                if searchFilters.searchInNotes, let notes = product.notes?.lowercased(), notes.contains(searchLower) {
                    shouldInclude = true
                }
                
                return shouldInclude
            }
        }
        
        // 应用分类筛选
        if searchFilters.filterByCategory, !searchFilters.selectedCategoryID.isEmpty {
            result = result.filter { product in
                guard let categoryID = product.category?.id?.uuidString else { return false }
                return categoryID == searchFilters.selectedCategoryID
            }
        }
        
        // 应用标签筛选
        if searchFilters.filterByTag, !searchFilters.selectedTagIDs.isEmpty {
            result = result.filter { product in
                guard let tags = product.tags as? Set<Tag> else { return false }
                return tags.contains { tag in
                    guard let tagID = tag.id?.uuidString else { return false }
                    return searchFilters.selectedTagIDs.contains(tagID)
                }
            }
        }
        
        // 应用保修状态筛选
        if searchFilters.filterByWarranty, searchFilters.warrantyStatus != -1 {
            result = result.filter { product in
                guard let order = product.order, let warrantyEndDate = order.warrantyEndDate else {
                    return false
                }
                
                let now = Date()
                let calendar = Calendar.current
                let days = calendar.numberOfDaysBetween(now, and: warrantyEndDate)
                
                switch searchFilters.warrantyStatus {
                case 0: // 在保修期内
                    return days > 0
                case 1: // 即将过期 (30天内)
                    return days > 0 && days <= 30
                case 2: // 已过期
                    return days <= 0
                default:
                    return true
                }
            }
        }
        
        // 应用日期筛选
        if searchFilters.filterByDate {
            result = result.filter { product in
                guard let order = product.order, let orderDate = order.orderDate else {
                    return false
                }
                
                // 为了包含结束日期当天，需要将结束日期设置为当天的结束时间
                let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: searchFilters.endDate) ?? searchFilters.endDate
                
                return orderDate >= searchFilters.startDate && orderDate <= endOfDay
            }
        }
        
        return result
    }
}