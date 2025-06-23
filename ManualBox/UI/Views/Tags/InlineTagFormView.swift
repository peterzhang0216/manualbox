//
//  InlineTagFormView.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/6/23.
//

import SwiftUI
import CoreData

// MARK: - 内联标签表单视图
struct InlineTagFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var stateManager: DetailPanelStateManager

    let mode: FormMode<Tag>

    @State private var tagName = ""
    @State private var selectedColor = TagColor.blue
    @State private var isSaving = false
    @State private var saveError: String?

    // 响应式颜色网格列数
    private var adaptiveColorColumns: Int {
        return 5 // 在 macOS 上使用 5 列，适合颜色选择
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
                    saveTag()
                }
                .buttonStyle(.borderedProminent)
                .disabled(tagName.isEmpty || isSaving)
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            // 表单内容
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // 标签名称
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标签名称")
                            .font(.headline)
                        TextField("请输入标签名称", text: $tagName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 颜色选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择颜色")
                            .font(.headline)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: adaptiveColorColumns), spacing: 12) {
                            ForEach(TagColor.allCases) { color in
                                Button(action: { selectedColor = color }) {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                        )
                                        .shadow(color: color.color.opacity(0.3), radius: 2, x: 0, y: 1)
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
            tagName = ""
            selectedColor = .blue
        case .edit(let tag):
            tagName = tag.tagName
            selectedColor = TagColor(rawValue: tag.color ?? "blue") ?? .blue
        }
    }

    private func saveTag() {
        guard !tagName.isEmpty else {
            saveError = "标签名称不能为空"
            return
        }

        isSaving = true
        saveError = nil

        Task {
            do {
                switch mode {
                case .add:
                    let _ = Tag.createTagIfNotExists(
                        in: viewContext,
                        name: tagName,
                        color: selectedColor.rawValue
                    )
                case .edit(let tag):
                    tag.name = tagName
                    tag.color = selectedColor.rawValue
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
