import SwiftUI

// MARK: - 版本比较视图
struct VersionComparisonView: View {
    let manual: Manual
    let selectedVersion: ManualVersion
    @StateObject private var versionService = ManualVersionService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var comparisonVersion: ManualVersion?
    @State private var comparison: VersionComparison?
    
    private var versions: [ManualVersion] {
        versionService.getVersions(for: manual.id ?? UUID())
            .filter { $0.id != selectedVersion.id }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 工具栏
                toolbarSection
                
                Divider()
                
                // 版本比较内容
                comparisonContent
            }
            .navigationTitle("版本比较")
            #if os(macOS)
            .platformNavigationBarTitleDisplayMode(0)
            .platformToolbar(trailing: {
                Button("导出") {
                    exportComparison()
                }
            })
            #else
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    Button("导出") {
                        exportComparison()
                    }
                }
            }
            #endif
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ModernColors.Background.primary)
        }
        .onAppear {
            if let firstVersion = versions.first {
                comparisonVersion = firstVersion
                performComparison()
            }
        }
    }
    
    // MARK: - 工具栏
    private var toolbarSection: some View {
        HStack(spacing: 16) {
            // 版本选择器
            versionSelector
            
            Spacer()
            
            // 完成按钮
            Button("完成") {
                dismiss()
            }
        }
        .padding()
        .background(ModernColors.System.gray6)
    }
    
    // MARK: - 版本选择器
    private var versionSelector: some View {
        VStack(spacing: 16) {
            Text("选择要比较的版本")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                // 当前选择的版本
                VersionCard(
                    version: selectedVersion,
                    title: "基准版本",
                    isSelected: true
                )
                
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                // 比较版本选择
                Menu {
                    ForEach(versions, id: \.id) { version in
                        Button(action: {
                            comparisonVersion = version
                            performComparison()
                        }) {
                            HStack {
                                Text(version.versionString)
                                Spacer()
                                Text(formatDate(version.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } label: {
                    if let comparisonVersion = comparisonVersion {
                        VersionCard(
                            version: comparisonVersion,
                            title: "比较版本",
                            isSelected: false
                        )
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.dashed")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("选择版本")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 120, height: 80)
                        .background(ModernColors.System.gray6)
                        .cornerRadius(8)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(ModernColors.System.gray6)
    }
    
    // MARK: - 比较结果
    private var comparisonContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 相似度指标
                similaritySection
                
                // 变更详情
                if comparison?.hasChanges == true {
                    changesSection
                } else {
                    noChangesSection
                }
                
                // 详细信息对比
                detailedComparisonSection
            }
            .padding()
        }
    }
    
    // MARK: - 相似度部分
    private var similaritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("相似度分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("相似度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(comparison?.similarityPercentage ?? "")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(similarityColor(comparison?.similarity ?? 0))
                }
                
                Spacer()
                
                // 相似度进度条
                ProgressView(value: comparison?.similarity ?? 0)
                    .progressViewStyle(LinearProgressViewStyle(tint: similarityColor(comparison?.similarity ?? 0)))
                    .frame(width: 100)
            }
            .padding()
            .background(ModernColors.Background.primary)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - 变更部分
    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("检测到的变更")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                if let changes = comparison?.changes {
                    ForEach(Array(changes.enumerated()), id: \.offset) { index, change in
                        ChangeRow(change: change)
                    }
                }
            }
        }
    }
    
    // MARK: - 无变更部分
    private var noChangesSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("未检测到变更")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("这两个版本在检测的方面没有差异")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 详细对比部分
    private var detailedComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("详细对比")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ComparisonDetailRow(
                    label: "文件名",
                    value1: comparison?.version1.fileName ?? "",
                    value2: comparison?.version2.fileName ?? ""
                )
                
                ComparisonDetailRow(
                    label: "文件大小",
                    value1: comparison?.version1.formattedSize ?? "",
                    value2: comparison?.version2.formattedSize ?? ""
                )
                
                ComparisonDetailRow(
                    label: "创建时间",
                    value1: formatDate(comparison?.version1.createdAt ?? Date()),
                    value2: formatDate(comparison?.version2.createdAt ?? Date())
                )
                
                ComparisonDetailRow(
                    label: "变更类型",
                    value1: comparison?.version1.changeType.displayName ?? "",
                    value2: comparison?.version2.changeType.displayName ?? ""
                )
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func performComparison() {
        guard let comparisonVersion = comparisonVersion else { return }
        comparison = versionService.compareVersions(selectedVersion, comparisonVersion)
    }
    
    private func similarityColor(_ similarity: Double) -> Color {
        if similarity >= 0.8 {
            return .green
        } else if similarity >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func exportComparison() {
        // Implementation of exportComparison method
    }
}

// MARK: - 版本卡片
struct VersionCard: View {
    let version: ManualVersion
    let title: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text(version.versionString)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(version.changeType.displayName)
                    .font(.caption)
                    .foregroundColor(version.changeType.color)
            }
        }
        .frame(width: 120, height: 80)
        .background(isSelected ? Color.accentColor.opacity(0.1) : ModernColors.Background.primary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : ModernColors.System.gray4, lineWidth: 1)
        )
    }
}

// MARK: - 变更行
struct ChangeRow: View {
    let change: VersionChange
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.right.circle")
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(change.type.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack {
                    Text(change.oldValue)
                        .font(.caption)
                        .foregroundColor(.red)
                        .strikethrough()
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(change.newValue)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

// MARK: - 对比详情行
struct ComparisonDetailRow: View {
    let label: String
    let value1: String
    let value2: String
    
    private var hasChange: Bool {
        value1 != value2
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack {
                Text(value1)
                    .font(.body)
                    .foregroundColor(hasChange ? .red : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: hasChange ? "arrow.right" : "equal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value2)
                    .font(.body)
                    .foregroundColor(hasChange ? .green : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .background(hasChange ? Color.orange.opacity(0.1) : ModernColors.System.gray6)
        .cornerRadius(8)
    }
}

#Preview {
    VersionComparisonView(
        manual: Manual.preview,
        selectedVersion: ManualVersion(
            id: UUID(),
            manualId: UUID(),
            versionNumber: 1,
            fileData: Data(),
            fileName: "test.pdf",
            fileType: "pdf",
            content: nil,
            versionNote: nil,
            changeType: .initial,
            createdAt: Date(),
            fileSize: 1024
        )
    )
}
