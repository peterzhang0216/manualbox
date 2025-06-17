//
//  TagsViewModel.swift
//  ManualBox
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import SwiftUI
import CoreData

// MARK: - Tags State
struct TagsState: StateProtocol {
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    // UI状态
    var showingAddSheet = false
    var searchText = ""
    
    // 新标签表单状态
    var newTagName = ""
    var selectedColor: String = "blue"
    
    // 操作状态
    var isSaving = false
    var saveError: String?
}

// MARK: - Tags Actions
enum TagsAction: ActionProtocol {
    case toggleAddSheet
    case updateSearchText(String)
    case updateNewTagName(String)
    case updateSelectedColor(String)
    case saveTag
    case deleteTag(Tag)
    case clearForm
    case setError(String?)
    case setSaving(Bool)
}

@MainActor
class TagsViewModel: BaseViewModel<TagsState, TagsAction> {
    private let viewContext: NSManagedObjectContext
    
    // 便利属性
    var showingAddSheet: Bool { state.showingAddSheet }
    var searchText: String { state.searchText }
    var newTagName: String { state.newTagName }
    var selectedColor: String { state.selectedColor }
    var isSaving: Bool { state.isSaving }
    var saveError: String? { state.saveError }
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        super.init(initialState: TagsState())
    }
    
    // MARK: - Action Handler
    override func handle(_ action: TagsAction) async {
        switch action {
        case .toggleAddSheet:
            updateState { 
                $0.showingAddSheet.toggle()
                if !$0.showingAddSheet {
                    // 关闭时清空表单
                    $0.newTagName = ""
                    $0.selectedColor = "blue"
                    $0.saveError = nil
                }
            }
            
        case .updateSearchText(let text):
            updateState { $0.searchText = text }
            
        case .updateNewTagName(let name):
            updateState { 
                $0.newTagName = name
                $0.saveError = nil // 清除之前的错误
            }
            
        case .updateSelectedColor(let color):
            updateState { $0.selectedColor = color }
            
        case .saveTag:
            await saveTag()
            
        case .deleteTag(let tag):
            await deleteTag(tag)
            
            
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
            
        case .clearForm:
            updateState {
                $0.newTagName = ""
                $0.selectedColor = "blue"
                $0.saveError = nil
            }
            
        }
    }
    
    // MARK: - Private Methods
    private func saveTag() async {
        // 使用统一的验证方法
        guard self.validateNonEmpty(self.state.newTagName, fieldName: "标签名称") else {
            self.updateState { $0.saveError = self.state.errorMessage }
            return
        }
        // 使用统一的加载状态管理
        await self.performTask { [self] in
            let _ = Tag.createTagIfNotExists(
                in: self.viewContext,
                name: self.state.newTagName,
                color: self.state.selectedColor
            )
            try self.viewContext.save()
            // 保存成功，关闭表单并清空状态
            self.updateState {
                $0.showingAddSheet = false
                $0.newTagName = ""
                $0.selectedColor = "blue"
                $0.saveError = nil
                $0.isSaving = false
            }
        }
    }
    
    private func deleteTag(_ tag: Tag) async {
        await performTask { [self] in
            self.viewContext.delete(tag)
            try self.viewContext.save()
        }
    }
    
    // MARK: - Public Methods
    func filteredTags(from tags: [Tag]) -> [Tag] {
        if state.searchText.isEmpty {
            return tags
        } else {
            return tags.filter { tag in
                tag.name?.localizedCaseInsensitiveContains(state.searchText) ?? false
            }
        }
    }
    
    func clearSearch() {
        self.send(.updateSearchText(""))
    }
    
    func getTagsGroupedByColor(from tags: [Tag]) -> [(String, [Tag])] {
        let filteredTags = filteredTags(from: tags)
        let grouped = Dictionary(grouping: filteredTags) { tag in
            tag.color ?? "blue"
        }
        
        let colorOrder = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "gray"]
        return colorOrder.compactMap { color in
            if let tagsForColor = grouped[color], !tagsForColor.isEmpty {
                return (color, tagsForColor.sorted { ($0.name ?? "") < ($1.name ?? "") })
            }
            return nil
        }
    }
}