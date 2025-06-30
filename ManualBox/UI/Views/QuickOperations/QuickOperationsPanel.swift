//
//  QuickOperationsPanel.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI

// MARK: - 快速操作面板
struct QuickOperationsPanel: View {
    @StateObject private var quickOpsService = QuickOperationsService.shared
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar
                
                // 内容区域
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // 收藏操作
                        if !quickOpsService.favoriteActions.isEmpty {
                            favoriteActionsSection
                        }
                        
                        // 最近使用
                        if !quickOpsService.recentActions.isEmpty && quickOpsService.searchText.isEmpty {
                            recentActionsSection
                        }
                        
                        // 所有操作（按分类）
                        allActionsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("快速操作")
            #if os(iOS)
            .platformNavigationBarTitleDisplayMode(.inline)
            #else
            .platformNavigationBarTitleDisplayMode(0)
            #endif
            .platformToolbar(trailing: {
                Button("关闭") {
                    quickOpsService.hideQuickActionPanel()
                }
            })
        }
        .onAppear {
            isSearchFocused = true
        }
    }
    
    // MARK: - 搜索栏
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索操作...", text: $quickOpsService.searchText)
                .focused($isSearchFocused)
                .textFieldStyle(.plain)
                .onSubmit {
                    if let firstAction = quickOpsService.filteredActions.first {
                        Task {
                            await quickOpsService.executeAction(firstAction)
                        }
                    }
                }
            
            if !quickOpsService.searchText.isEmpty {
                Button(action: {
                    quickOpsService.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ModernColors.System.gray6)
        .cornerRadius(10)
        .padding()
    }
    
    // MARK: - 收藏操作区域
    
    private var favoriteActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("收藏操作")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(quickOpsService.favoriteActions) { action in
                    QuickActionCard(action: action, isFavorite: true) {
                        Task {
                            await quickOpsService.executeAction(action)
                        }
                    } onToggleFavorite: {
                        quickOpsService.toggleFavorite(action)
                    }
                }
            }
        }
    }
    
    // MARK: - 最近使用区域
    
    private var recentActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text("最近使用")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(quickOpsService.recentActions.prefix(6)) { action in
                    QuickActionCard(
                        action: action,
                        isFavorite: quickOpsService.isFavorite(action)
                    ) {
                        Task {
                            await quickOpsService.executeAction(action)
                        }
                    } onToggleFavorite: {
                        quickOpsService.toggleFavorite(action)
                    }
                }
            }
        }
    }
    
    // MARK: - 所有操作区域
    
    private var allActionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            let groupedActions = Dictionary(grouping: quickOpsService.filteredActions) { $0.category }
            
            ForEach(QuickActionCategory.allCases, id: \.self) { category in
                if let actions = groupedActions[category], !actions.isEmpty {
                    categorySection(category: category, actions: actions)
                }
            }
        }
    }
    
    private func categorySection(category: QuickActionCategory, actions: [QuickAction]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                Text(category.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(actions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(actions) { action in
                    QuickActionCard(
                        action: action,
                        isFavorite: quickOpsService.isFavorite(action)
                    ) {
                        Task {
                            await quickOpsService.executeAction(action)
                        }
                    } onToggleFavorite: {
                        quickOpsService.toggleFavorite(action)
                    }
                }
            }
        }
    }
}

// MARK: - 快速操作卡片
struct QuickActionCard: View {
    let action: QuickAction
    let isFavorite: Bool
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: action.icon)
                        .font(.title2)
                        .foregroundColor(action.category.color)
                    
                    Spacer()
                    
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(action.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if let shortcut = action.keyboardShortcut {
                    HStack {
                        Spacer()
                        Text(shortcut)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            #if os(macOS)
                            .background(Color(nsColor: .windowBackgroundColor))
                            #else
                            .background(Color(.systemGray5))
                            #endif
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
            .background(ModernColors.Background.primary)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {
            // 长按操作可以在这里添加
        }
    }
}

// MARK: - 快速操作面板修饰器
struct QuickOperationsPanelModifier: ViewModifier {
    @StateObject private var quickOpsService = QuickOperationsService.shared
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $quickOpsService.isQuickActionPanelVisible) {
                QuickOperationsPanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showQuickOperationsPanel)) { _ in
                quickOpsService.showQuickActionPanel()
            }
    }
}

extension View {
    func quickOperationsPanel() -> some View {
        modifier(QuickOperationsPanelModifier())
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let showQuickOperationsPanel = Notification.Name("ShowQuickOperationsPanel")
}

// MARK: - 预览
struct QuickOperationsPanel_Previews: PreviewProvider {
    static var previews: some View {
        QuickOperationsPanel()
    }
}
