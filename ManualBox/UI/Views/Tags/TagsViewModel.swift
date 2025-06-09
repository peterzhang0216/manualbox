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
    var selectedColor: TagColor = .blue
    
    // 操作状态
    var isSaving = false
    var saveError: String?
}

// MARK: - Tags Actions
enum TagsAction: ActionProtocol {
    case toggleAddSheet
    case updateSearchText(String)
    case updateNewTagName(String)
    case updateSelectedColor(TagColor)
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
    var selectedColor: TagColor { state.selectedColor }
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
                    $0.selectedColor = .blue
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
            
        case .clearForm:
            updateState {
                $0.newTagName = ""
                $0.selectedColor = .blue
                $0.saveError = nil
            }
            
        case .setError(let error):
            updateState { $0.saveError = error }
            
        case .setSaving(let saving):
            updateState { $0.isSaving = saving }
        }
    }
    
    // MARK: - Private Methods
    private func saveTag() async {
        guard !state.newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            updateState { $0.saveError = "标签名称不能为空" }
            return
        }
        
        updateState { $0.isSaving = true }
        
        let tag = Tag(context: viewContext)
        tag.id = UUID()
        tag.name = state.newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        tag.color = state.selectedColor.rawValue
        
        do {
            try viewContext.save()
            
            // 保存成功，关闭表单并清空状态
            updateState {
                $0.showingAddSheet = false
                $0.newTagName = ""
                $0.selectedColor = .blue
                $0.saveError = nil
                $0.isSaving = false
            }
        } catch {
            updateState {
                $0.saveError = "保存标签失败: \(error.localizedDescription)"
                $0.isSaving = false
            }
        }
    }
    
    private func deleteTag(_ tag: Tag) async {
        do {
            viewContext.delete(tag)
            try viewContext.save()
        } catch {
            updateState { $0.errorMessage = "删除标签失败: \(error.localizedDescription)" }
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
        send(.updateSearchText(""))
    }
    
    func getTagsGroupedByColor(from tags: [Tag]) -> [(TagColor, [Tag])] {
        let filteredTags = filteredTags(from: tags)
        let grouped = Dictionary(grouping: filteredTags) { tag in
            TagColor(rawValue: tag.color ?? TagColor.blue.rawValue) ?? .blue
        }
        
        return TagColor.allCases.compactMap { color in
            if let tagsForColor = grouped[color], !tagsForColor.isEmpty {
                return (color, tagsForColor.sorted { ($0.name ?? "") < ($1.name ?? "") })
            }
            return nil
        }
    }
}