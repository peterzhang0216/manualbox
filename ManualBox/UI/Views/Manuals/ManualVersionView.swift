import SwiftUI

// MARK: - 说明书版本管理视图
struct ManualVersionView: View {
    let manual: Manual
    @StateObject private var versionService = ManualVersionService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedVersion: ManualVersion?
    @State private var showingVersionComparison = false
    @State private var showingVersionDetail = false
    @State private var showingDeleteAlert = false
    @State private var versionToDelete: ManualVersion?
    @State private var showingRestoreAlert = false
    @State private var versionToRestore: ManualVersion?
    @State private var showingCleanupAlert = false
    
    private var versions: [ManualVersion] {
        versionService.getVersions(for: manual.id ?? UUID())
    }
    
    private var statistics: VersionStatistics {
        versionService.getVersionStatistics(for: manual.id ?? UUID())
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 统计信息
                statisticsSection
                
                Divider()
                
                // 版本列表
                versionsList
            }
            .navigationTitle("版本历史")
            #if os(iOS)
            .platformNavigationBarTitleDisplayMode(.inline)
            #else
            .platformNavigationBarTitleDisplayMode(0)
            #endif
            .platformToolbar(leading: {
                Button("关闭") {
                    dismiss()
                }
            }, trailing: {
                Menu {
                    Button(action: exportVersionHistory) {
                        Label("导出版本历史", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {
                        showingCleanupAlert = true
                    }) {
                        Label("清理旧版本", systemImage: "trash.circle")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: clearAllVersions) {
                        Label("清除所有版本", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            })
        }
        .sheet(isPresented: $showingVersionDetail) {
            if let version = selectedVersion {
                VersionDetailView(version: version)
            }
        }
        .sheet(isPresented: $showingVersionComparison) {
            if let version = selectedVersion, versions.count > 1 {
                VersionComparisonView(
                    manual: manual,
                    selectedVersion: version
                )
            }
        }
        .alert("删除版本", isPresented: $showingDeleteAlert) {
            Button("删除", role: .destructive) {
                if let version = versionToDelete {
                    deleteVersion(version)
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除这个版本吗？此操作无法撤销。")
        }
        .alert("恢复版本", isPresented: $showingRestoreAlert) {
            Button("恢复") {
                if let version = versionToRestore {
                    restoreToVersion(version)
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要恢复到这个版本吗？这将创建一个新的版本。")
        }
        .alert("清理旧版本", isPresented: $showingCleanupAlert) {
            Button("清理") {
                cleanupOldVersions()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("将保留最新的10个版本，删除其余版本。")
        }
    }
    
    // MARK: - 统计信息部分
    private var statisticsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("版本统计")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                ManualStatisticCard(
                    title: "总版本数",
                    value: "\(statistics.totalVersions)",
                    icon: "doc.on.doc",
                    color: .blue
                )

                ManualStatisticCard(
                    title: "总大小",
                    value: statistics.formattedTotalSize,
                    icon: "externaldrive",
                    color: .green
                )

                ManualStatisticCard(
                    title: "平均大小",
                    value: statistics.formattedAverageSize,
                    icon: "chart.bar",
                    color: .orange
                )
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
    }
    
    // MARK: - 版本列表
    private var versionsList: some View {
        Group {
            if versions.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(versions, id: \.id) { version in
                        VersionRow(
                            version: version,
                            isLatest: version.id == versions.first?.id,
                            onTap: {
                                selectedVersion = version
                                showingVersionDetail = true
                            },
                            onCompare: {
                                selectedVersion = version
                                showingVersionComparison = true
                            },
                            onRestore: {
                                versionToRestore = version
                                showingRestoreAlert = true
                            },
                            onDelete: {
                                versionToDelete = version
                                showingDeleteAlert = true
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("暂无版本历史")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("当说明书被更新时，版本历史将显示在这里")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ModernColors.Background.primary)
    }
    
    // MARK: - 操作方法
    
    private func deleteVersion(_ version: ManualVersion) {
        Task {
            await versionService.deleteVersion(version)
        }
    }
    
    private func restoreToVersion(_ version: ManualVersion) {
        Task {
            await versionService.restoreToVersion(version)
        }
    }
    
    private func cleanupOldVersions() {
        Task {
            await versionService.cleanupOldVersions(for: manual.id ?? UUID(), keepCount: 10)
        }
    }
    
    private func clearAllVersions() {
        Task {
            await versionService.clearAllVersions()
        }
    }
    
    private func exportVersionHistory() {
        guard let data = versionService.exportVersionHistory(for: manual.id ?? UUID()) else {
            return
        }
        
        // 实现导出逻辑
        let fileName = "\(manual.fileName ?? "manual")_versions.json"
        exportData(data, fileName: fileName)
    }
    
    private func exportData(_ data: Data, fileName: String) {
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [data], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
        }
        #else
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = fileName
        savePanel.allowedContentTypes = [.json]
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                } catch {
                    print("导出失败: \(error.localizedDescription)")
                }
            }
        }
        #endif
    }
}

// MARK: - 统计卡片
struct ManualStatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 版本行组件
struct VersionRow: View {
    let version: ManualVersion
    let isLatest: Bool
    let onTap: () -> Void
    let onCompare: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // 版本头部
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: version.changeType.icon)
                            .font(.system(size: 14))
                            .foregroundColor(version.changeType.color)

                        Text(version.versionString)
                            .font(.headline)
                            .fontWeight(.semibold)

                        if isLatest {
                            Text("最新")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    Spacer()

                    Text(formatDate(version.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 版本信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(version.fileName)
                            .font(.body)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(version.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(version.changeType.displayName)
                            .font(.caption)
                            .foregroundColor(version.changeType.color)

                        if let note = version.versionNote, !note.isEmpty {
                            Text("• \(note)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // 操作按钮
                HStack(spacing: 12) {
                    Button(action: onCompare) {
                        Label("比较", systemImage: "arrow.left.arrow.right")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if !isLatest {
                        Button(action: onRestore) {
                            Label("恢复", systemImage: "arrow.counterclockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Spacer()

                    if !isLatest {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .background(ModernColors.Background.primary)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 版本详情视图
struct VersionDetailView: View {
    let version: ManualVersion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 基本信息
                    basicInfoSection

                    // 文件信息
                    fileInfoSection

                    // 变更信息
                    changeInfoSection

                    // 内容预览
                    if let content = version.content, !content.isEmpty {
                        contentPreviewSection(content: content)
                    }
                }
                .padding()
            }
            .navigationTitle("版本详情")
            #if os(iOS)
            .platformNavigationBarTitleDisplayMode(.inline)
            #else
            .platformNavigationBarTitleDisplayMode(0)
            #endif
            .platformToolbar(trailing: {
                Button("完成") {
                    dismiss()
                }
            })
        }
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ManualInfoRow(label: "版本号", value: version.versionString)
                ManualInfoRow(label: "创建时间", value: formatDate(version.createdAt))
                ManualInfoRow(label: "变更类型", value: version.changeType.displayName)

                if let note = version.versionNote, !note.isEmpty {
                    ManualInfoRow(label: "版本说明", value: note)
                }
            }
        }
    }

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文件信息")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ManualInfoRow(label: "文件名", value: version.fileName)
                ManualInfoRow(label: "文件类型", value: version.fileType.uppercased())
                ManualInfoRow(label: "文件大小", value: version.formattedSize)
            }
        }
    }

    private var changeInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("变更信息")
                .font(.headline)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                Image(systemName: version.changeType.icon)
                    .font(.title2)
                    .foregroundColor(version.changeType.color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(version.changeType.displayName)
                        .font(.body)
                        .fontWeight(.medium)

                    Text("此版本的变更类型")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(version.changeType.color.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func contentPreviewSection(content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("内容预览")
                .font(.headline)
                .fontWeight(.semibold)

            Text(content)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .background(ModernColors.Background.primary)
                .cornerRadius(8)
                .lineLimit(10)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - 信息行组件
struct ManualInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview {
    ManualVersionView(manual: Manual.preview)
}
