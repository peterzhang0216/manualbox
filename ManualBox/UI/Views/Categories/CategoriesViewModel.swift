//
//  CategoriesViewModel.swift
//  ManualBox
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import SwiftUI
import CoreData

// MARK: - Categories State
struct CategoriesState: StateProtocol {
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    // UI状态
    var showingAddSheet = false
    var searchText = ""
    
    // 新分类表单状态
    var newCategoryName = ""
    var selectedIcon = "folder"
    
    // 操作状态
    var isSaving = false
    var saveError: String?
}

// MARK: - Categories Actions
enum CategoriesAction: ActionProtocol {
    case toggleAddSheet
    case updateSearchText(String)
    case updateNewCategoryName(String)
    case updateSelectedIcon(String)
    case saveCategory
    case deleteCategory(Category)
    case clearForm
    case setError(String?)
    case setSaving(Bool)
}

@MainActor
class CategoriesViewModel: BaseViewModel<CategoriesState, CategoriesAction> {
    private let viewContext: NSManagedObjectContext
    
    // 便利属性
    var showingAddSheet: Bool { state.showingAddSheet }
    var searchText: String { state.searchText }
    var newCategoryName: String { state.newCategoryName }
    var selectedIcon: String { state.selectedIcon }
    var isSaving: Bool { state.isSaving }
    var saveError: String? { state.saveError }
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        super.init(initialState: CategoriesState())
    }
    
    // MARK: - Action Handler
    override func handle(_ action: CategoriesAction) async {
        switch action {
        case .toggleAddSheet:
            updateState { 
                $0.showingAddSheet.toggle()
                if !$0.showingAddSheet {
                    // 关闭时清空表单
                    $0.newCategoryName = ""
                    $0.selectedIcon = "folder"
                    $0.saveError = nil
                }
            }
            
        case .updateSearchText(let text):
            updateState { $0.searchText = text }
            
        case .updateNewCategoryName(let name):
            updateState { 
                $0.newCategoryName = name
                $0.saveError = nil // 清除之前的错误
            }
            
        case .updateSelectedIcon(let icon):
            updateState { $0.selectedIcon = icon }
            
        case .saveCategory:
            await saveCategory()
            
        case .deleteCategory(let category):
            await deleteCategory(category)
            
        case .clearForm:
            updateState {
                $0.newCategoryName = ""
                $0.selectedIcon = "folder"
                $0.saveError = nil
            }
            
        case .setError(let error):
            updateState { 
                $0.saveError = error
                $0.errorMessage = error
            }
            
        case .setSaving(let saving):
            updateState { 
                $0.isSaving = saving
                $0.isLoading = saving
            }
        }
    }
    
    // MARK: - Private Methods
    private func saveCategory() async {
        // 使用统一的验证方法
        guard self.validateNonEmpty(self.state.newCategoryName, fieldName: "分类名称") else {
            self.updateState { $0.saveError = self.state.errorMessage }
            return
        }
        
        // 使用统一的加载状态管理
        await self.performTask { [self] in
            let category = Category(context: self.viewContext)
            category.id = UUID()
            category.name = self.state.newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            category.icon = self.state.selectedIcon
            try self.viewContext.save()
            // 保存成功，关闭表单并清空状态
            self.updateState {
                $0.showingAddSheet = false
                $0.newCategoryName = ""
                $0.selectedIcon = "folder"
                $0.saveError = nil
                $0.isSaving = false
            }
        }
    }
    
    private func deleteCategory(_ category: Category) async {
        await self.performTask { [self] in
            self.viewContext.delete(category)
            try self.viewContext.save()
        }
    }
    
    // MARK: - Public Methods
    func filteredCategories(from categories: [Category]) -> [Category] {
        if self.state.searchText.isEmpty {
            return categories
        } else {
            return categories.filter { category in
                category.name?.localizedCaseInsensitiveContains(self.state.searchText) ?? false
            }
        }
    }
    
    func clearSearch() {
        self.send(.updateSearchText(""))
    }
}

// MARK: - System Icons
let systemIcons = [
    "folder", "folder.fill", "archivebox", "archivebox.fill",
    "tray", "tray.fill", "externaldrive", "externaldrive.fill",
    "internaldrive", "internaldrive.fill", "opticaldiscdrive",
    "tv", "tv.fill", "display", "desktopcomputer",
    "laptopcomputer", "pc", "server.rack", "airport.express",
    "wifi.router", "antenna.radiowaves.left.and.right",
    "iphone", "ipad", "applewatch", "airpods",
    "homepod", "homepod.mini", "appletv", "airpodsmax",
    "gamecontroller", "headphones", "speaker", "hifispeaker",
    "car", "bicycle", "scooter", "skateboard",
    "house", "building", "building.2", "store",
    "bag", "briefcase", "backpack", "suitcase",
    "camera", "video", "photo", "film",
    "book", "magazine", "newspaper", "doc",
    "wrench", "hammer", "screwdriver", "level",
    "paintbrush", "scissors", "ruler", "pencil",
    "heart", "star", "flag", "tag",
    "circle", "square", "triangle", "diamond"
]