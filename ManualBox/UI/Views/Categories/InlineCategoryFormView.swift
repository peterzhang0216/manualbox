//
//  InlineCategoryFormView.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/6/23.
//

import SwiftUI
import CoreData

// MARK: - 表单模式枚举
enum FormMode<T> {
    case add
    case edit(T)
    
    var isEditing: Bool {
        switch self {
        case .add:
            return false
        case .edit:
            return true
        }
    }
}

// MARK: - 内联分类表单视图
struct InlineCategoryFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var stateManager: DetailPanelStateManager
    
    let mode: FormMode<Category>
    
    @State private var categoryName = ""
    @State private var selectedIcon = "folder"
    @State private var isSaving = false
    @State private var saveError: String?
    
    private let systemIcons = [
        "folder", "folder.fill", "archivebox", "archivebox.fill",
        "tray", "tray.fill", "externaldrive", "externaldrive.fill",
        "internaldrive", "internaldrive.fill", "opticaldiscdrive",
        "tv", "tv.fill", "desktopcomputer", "laptopcomputer",
        "iphone", "ipad", "applewatch", "airpods",
        "headphones", "speaker", "hifispeaker", "homepod",
        "gamecontroller", "gamecontroller.fill", "keyboard",
        "computermouse", "computermouse.fill", "trackpad",
        "printer", "printer.fill", "scanner", "scanner.fill",
        "camera", "camera.fill", "video", "video.fill"
    ]
    
    // 响应式图标网格列数
    private var adaptiveIconColumns: Int {
        // 根据可用宽度调整列数，确保在较小窗口中也能正常显示
        return 6 // 在 macOS 上使用固定的 6 列，适合大多数情况
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题栏
            HStack {
                Image(systemName: stateManager.currentState.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(stateManager.currentState.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                
                Button("取消") {
                    stateManager.reset()
                }
                .buttonStyle(.bordered)
                
                Button("保存") {
                    saveCategory()
                }
                .buttonStyle(.borderedProminent)
                .disabled(categoryName.isEmpty || isSaving)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
            
            // 表单内容
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // 分类名称
                    VStack(alignment: .leading, spacing: 8) {
                        Text("分类名称")
                            .font(.headline)
                        TextField("请输入分类名称", text: $categoryName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // 图标选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择图标")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: adaptiveIconColumns), spacing: 12) {
                            ForEach(systemIcons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedIcon == icon ? Color.accentColor : Color.secondary.opacity(0.2))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // 错误信息
                    if let error = saveError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            
            Spacer()
        }
        .disabled(isSaving)
        .overlay {
            if isSaving {
                ProgressView("保存中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    private func setupInitialValues() {
        switch mode {
        case .add:
            categoryName = ""
            selectedIcon = "folder"
        case .edit(let category):
            categoryName = category.categoryName
            selectedIcon = category.categoryIcon
        }
    }
    
    private func saveCategory() {
        guard !categoryName.isEmpty else {
            saveError = "分类名称不能为空"
            return
        }
        
        isSaving = true
        saveError = nil
        
        Task {
            do {
                switch mode {
                case .add:
                    let _ = Category.createCategoryIfNotExists(
                        in: viewContext,
                        name: categoryName,
                        icon: selectedIcon
                    )
                case .edit(let category):
                    category.name = categoryName
                    category.icon = selectedIcon
                }
                
                try viewContext.save()
                
                await MainActor.run {
                    stateManager.reset()
                }
            } catch {
                await MainActor.run {
                    saveError = "保存失败: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}
