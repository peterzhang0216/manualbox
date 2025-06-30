//
//  QuickOperationsKeyboardHandler.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI
import Combine

// MARK: - 快速操作键盘处理器
struct QuickOperationsKeyboardHandler: ViewModifier {
    @StateObject private var quickOpsService = QuickOperationsService.shared
    
    func body(content: Content) -> some View {
        content
            .onReceive(keyboardShortcutPublisher) { shortcut in
                handleKeyboardShortcut(shortcut)
            }
            #if os(macOS)
            .onAppear {
                setupMacOSKeyboardShortcuts()
            }
            #endif
    }
    
    // MARK: - 键盘快捷键发布者
    
    private var keyboardShortcutPublisher: AnyPublisher<String, Never> {
        NotificationCenter.default
            .publisher(for: .keyboardShortcutPressed)
            .compactMap { $0.object as? String }
            .eraseToAnyPublisher()
    }
    
    // MARK: - 快捷键处理
    
    private func handleKeyboardShortcut(_ shortcut: String) {
        Task {
            await executeShortcut(shortcut)
        }
    }
    
    @MainActor
    private func executeShortcut(_ shortcut: String) async {
        // 特殊处理快速操作面板快捷键
        if shortcut == "⌘K" {
            quickOpsService.toggleQuickActionPanel()
            return
        }
        
        // 查找匹配的操作
        if let action = quickOpsService.allActions.first(where: { $0.keyboardShortcut == shortcut }) {
            await quickOpsService.executeAction(action)
        }
    }
    
    #if os(macOS)
    // MARK: - macOS 键盘快捷键设置
    
    private func setupMacOSKeyboardShortcuts() {
        // 注册全局快捷键
        registerGlobalShortcuts()
    }
    
    private func registerGlobalShortcuts() {
        // 这里可以注册系统级的快捷键
        // 由于SwiftUI的限制，我们主要通过应用内的快捷键处理
    }
    #endif
}

// MARK: - 键盘快捷键视图修饰器
extension View {
    func quickOperationsKeyboardHandler() -> some View {
        modifier(QuickOperationsKeyboardHandler())
    }
}

// MARK: - 增强的键盘快捷键支持
struct EnhancedKeyboardShortcuts: ViewModifier {
    @StateObject private var quickOpsService = QuickOperationsService.shared
    
    func body(content: Content) -> some View {
        content
            // 快速操作面板快捷键
            .onKeyPress("k", modifiers: .command) {
                quickOpsService.toggleQuickActionPanel()
                return .handled
            }

            // 产品操作快捷键
            .onKeyPress("n", modifiers: .command) {
                NotificationCenter.default.post(name: .createNewProduct, object: nil)
                return .handled
            }
            .onKeyPress("n", modifiers: [.command, .shift]) {
                NotificationCenter.default.post(name: .showQuickAddProduct, object: nil)
                return .handled
            }
            .onKeyPress("n", modifiers: [.command, .option]) {
                NotificationCenter.default.post(name: .showScanProduct, object: nil)
                return .handled
            }

            // 搜索快捷键
            .onKeyPress("f", modifiers: .command) {
                NotificationCenter.default.post(name: .focusSearchBar, object: nil)
                return .handled
            }
            .onKeyPress("f", modifiers: [.command, .shift]) {
                NotificationCenter.default.post(name: .showManualSearch, object: nil)
                return .handled
            }

            // 批量操作快捷键
            .onKeyPress("e", modifiers: .command) {
                NotificationCenter.default.post(name: .showBatchEdit, object: nil)
                return .handled
            }
            .onKeyPress(.delete, modifiers: .command) {
                NotificationCenter.default.post(name: .showBatchDelete, object: nil)
                return .handled
            }
            .onKeyPress("e", modifiers: [.command, .shift]) {
                NotificationCenter.default.post(name: .showBatchExport, object: nil)
                return .handled
            }

            // 导航快捷键
            .onKeyPress("1", modifiers: .command) {
                NotificationCenter.default.post(name: .navigateToDashboard, object: nil)
                return .handled
            }
            .onKeyPress("2", modifiers: .command) {
                NotificationCenter.default.post(name: .navigateToProducts, object: nil)
                return .handled
            }
            .onKeyPress("3", modifiers: .command) {
                NotificationCenter.default.post(name: .navigateToCategories, object: nil)
                return .handled
            }
            .onKeyPress(",", modifiers: .command) {
                NotificationCenter.default.post(name: .navigateToSettings, object: nil)
                return .handled
            }

            // 数据操作快捷键
            .onKeyPress("r", modifiers: .command) {
                NotificationCenter.default.post(name: .performSync, object: nil)
                return .handled
            }
            .onKeyPress("b", modifiers: .command) {
                NotificationCenter.default.post(name: .performBackup, object: nil)
                return .handled
            }
            .onKeyPress("i", modifiers: .command) {
                NotificationCenter.default.post(name: .showImportData, object: nil)
                return .handled
            }

            // 分析快捷键
            .onKeyPress("a", modifiers: [.command, .option]) {
                NotificationCenter.default.post(name: .showUsageAnalysis, object: nil)
                return .handled
            }
            .onKeyPress("c", modifiers: [.command, .option]) {
                NotificationCenter.default.post(name: .showCostAnalysis, object: nil)
                return .handled
            }
    }
}

extension View {
    func enhancedKeyboardShortcuts() -> some View {
        modifier(EnhancedKeyboardShortcuts())
    }
}

// MARK: - 快速添加产品浮动按钮
struct QuickAddFloatingButton: View {
    @State private var showingQuickAdd = false
    @State private var showingOptions = false
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                if showingOptions {
                    quickAddOptions
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingOptions.toggle()
                    }
                }) {
                    Image(systemName: showingOptions ? "xmark" : "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                        .rotationEffect(.degrees(showingOptions ? 45 : 0))
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingOptions)
            }
            .padding()
        }
    }
    
    private var quickAddOptions: some View {
        VStack(spacing: 12) {
            quickAddButton(
                title: "扫描添加",
                icon: "camera.viewfinder",
                color: .green
            ) {
                NotificationCenter.default.post(name: .showScanProduct, object: nil)
                showingOptions = false
            }
            
            quickAddButton(
                title: "快速添加",
                icon: "plus.circle.fill",
                color: .orange
            ) {
                NotificationCenter.default.post(name: .showQuickAddProduct, object: nil)
                showingOptions = false
            }
            
            quickAddButton(
                title: "完整添加",
                icon: "plus.square.fill",
                color: .purple
            ) {
                NotificationCenter.default.post(name: .createNewProduct, object: nil)
                showingOptions = false
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    private func quickAddButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(20)
            .shadow(radius: 2)
        }
    }
}

// MARK: - 快速操作工具栏
struct QuickOperationsToolbar: View {
    @StateObject private var quickOpsService = QuickOperationsService.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // 快速操作按钮
            Button(action: {
                quickOpsService.showQuickActionPanel()
            }) {
                Label("快速操作", systemImage: "command")
            }
            .keyboardShortcut("k", modifiers: .command)
            
            Divider()
                .frame(height: 20)
            
            // 常用操作
            Button(action: {
                NotificationCenter.default.post(name: .createNewProduct, object: nil)
            }) {
                Label("添加", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Button(action: {
                NotificationCenter.default.post(name: .focusSearchBar, object: nil)
            }) {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)
            
            Button(action: {
                NotificationCenter.default.post(name: .performSync, object: nil)
            }) {
                Label("同步", systemImage: "arrow.triangle.2.circlepath")
            }
            .keyboardShortcut("r", modifiers: .command)
        }
        .padding(.horizontal)
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let keyboardShortcutPressed = Notification.Name("KeyboardShortcutPressed")
}
