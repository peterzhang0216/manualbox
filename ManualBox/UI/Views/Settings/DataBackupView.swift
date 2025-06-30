import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - 数据备份与恢复视图
struct DataBackupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isBackingUp = false
    @State private var isRestoring = false
    @State private var showBackupAlert = false
    @State private var showRestoreAlert = false
    @State private var showFileImporter = false
    @State private var showShareSheet = false
    @State private var backupMessage = ""
    @State private var restoreMessage = ""
    @State private var backupURL: URL?
    @State private var backupProgress: Double = 0.0
    @State private var restoreProgress: Double = 0.0
    @StateObject private var cloudSyncService = CloudKitSyncService(
        persistentContainer: PersistenceController.shared.container,
        configuration: CloudKitSyncConfiguration.default
    )
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("数据备份与恢复")
                    .font(.title2).bold()
                    .padding(.top, 24)
                    .foregroundColor(.accentColor)

                // 本地备份部分
                VStack(alignment: .leading, spacing: 16) {
                    Text("本地备份")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("创建完整的数据备份文件，包含所有商品、分类、标签等信息")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: {
                        performLocalBackup()
                    }) {
                        HStack {
                            Image(systemName: "externaldrive.fill")
                            Text("创建本地备份")
                            Spacer()
                            if isBackingUp {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    .disabled(isBackingUp)

                    if isBackingUp && backupProgress > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("备份进度: \(Int(backupProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ProgressView(value: backupProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                    }
                }

                Divider()

                // iCloud备份部分
                VStack(alignment: .leading, spacing: 16) {
                    Text("iCloud 同步")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("将数据同步到 iCloud，在所有设备间无缝访问")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: {
                        performiCloudBackup()
                    }) {
                        HStack {
                            Image(systemName: "icloud.fill")
                            Text("同步到 iCloud")
                            Spacer()
                            if cloudSyncService.syncStatus == .syncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                    .disabled(cloudSyncService.syncStatus == .syncing)

                    // 显示同步状态
                    if cloudSyncService.syncStatus == .syncing {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("同步进度: \(Int(cloudSyncService.syncProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ProgressView(value: cloudSyncService.syncProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                    }

                    if let lastSync = cloudSyncService.lastSyncDate {
                        Text("上次同步: \(lastSync, formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // 恢复数据部分
                VStack(alignment: .leading, spacing: 16) {
                    Text("恢复数据")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("从备份文件中恢复数据。⚠️ 此操作将替换当前所有数据")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: {
                        showFileImporter = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("从备份恢复")
                            Spacer()
                            if isRestoring {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                    .disabled(isRestoring)

                    if isRestoring && restoreProgress > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("恢复进度: \(Int(restoreProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ProgressView(value: restoreProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                    }
                }

                Spacer(minLength: 50)
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle("数据备份与恢复")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("备份", isPresented: $showBackupAlert) {
            Button("确定") { }
        } message: {
            Text(backupMessage)
        }
        .alert("恢复", isPresented: $showRestoreAlert) {
            Button("确定") { }
        } message: {
            Text(restoreMessage)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json, UTType("com.manualbox.backup") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    performRestore(from: url)
                }
            case .failure(let error):
                restoreMessage = "文件选择失败: \(error.localizedDescription)"
                showRestoreAlert = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = backupURL {
                BackupShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: - 私有方法

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    private func performLocalBackup() {
        isBackingUp = true
        backupProgress = 0.0

        Task {
            do {
                await updateBackupProgress(0.1)

                let exportService = DataExportService(persistentContainer: PersistenceController.shared.container)
                let url = try await exportService.exportFullDatabase()

                await updateBackupProgress(1.0)

                await MainActor.run {
                    backupURL = url
                    backupMessage = "本地备份创建成功！\n\n备份文件已保存，您可以分享或保存到其他位置。"
                    showBackupAlert = true
                    showShareSheet = true
                    isBackingUp = false
                    backupProgress = 0.0
                }

            } catch {
                await MainActor.run {
                    backupMessage = "备份失败: \(error.localizedDescription)"
                    showBackupAlert = true
                    isBackingUp = false
                    backupProgress = 0.0
                }
            }
        }
    }

    private func performiCloudBackup() {
        Task {
            do {
                try await cloudSyncService.syncToCloud()
                await MainActor.run {
                    backupMessage = "iCloud 同步完成！\n\n您的数据已成功同步到 iCloud，可在其他设备上访问。"
                    showBackupAlert = true
                }
            } catch {
                await MainActor.run {
                    backupMessage = "iCloud 同步失败: \(error.localizedDescription)"
                    showBackupAlert = true
                }
            }
        }
    }

    private func performRestore(from url: URL) {
        isRestoring = true
        restoreProgress = 0.0

        Task {
            do {
                await updateRestoreProgress(0.1)

                let result = try await ImportService.importFullBackup(
                    url: url,
                    context: viewContext,
                    progressCallback: { progress in
                        Task { @MainActor in
                            restoreProgress = 0.1 + progress * 0.9
                        }
                    },
                    warningCallback: nil
                )

                await updateRestoreProgress(1.0)

                await MainActor.run {
                    if result.warnings.isEmpty {
                        restoreMessage = "数据恢复成功！\n\n已成功恢复 \(result.importedCount) 个项目。建议重启应用以确保完全生效。"
                    } else {
                        restoreMessage = "数据恢复完成，但有警告：\n\n恢复了 \(result.importedCount) 个项目\n\n警告：\(result.warnings.joined(separator: "; "))"
                    }
                    showRestoreAlert = true
                    isRestoring = false
                    restoreProgress = 0.0
                }

            } catch {
                await MainActor.run {
                    restoreMessage = "恢复失败: \(error.localizedDescription)"
                    showRestoreAlert = true
                    isRestoring = false
                    restoreProgress = 0.0
                }
            }
        }
    }

    @MainActor
    private func updateBackupProgress(_ progress: Double) {
        backupProgress = progress
    }

    @MainActor
    private func updateRestoreProgress(_ progress: Double) {
        restoreProgress = progress
    }
}

// MARK: - BackupShareSheet
#if os(iOS)
struct BackupShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
struct BackupShareSheet: View {
    let activityItems: [Any]

    var body: some View {
        VStack {
            Text("文件已准备就绪")
            Text("请在 Finder 中查看备份文件")
        }
        .padding()
    }
}
#endif

#Preview {
    NavigationView {
        DataBackupView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}