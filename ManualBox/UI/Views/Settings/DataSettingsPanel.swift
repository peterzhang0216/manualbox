import SwiftUI
import CoreData

// MARK: - 数据与默认设置面板
struct DataSettingsPanel: View {
    @Binding var defaultWarrantyPeriod: Int
    @Binding var enableOCRByDefault: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @State private var diagnosticResult: DataDiagnostics.DiagnosticResult?
    @State private var isDiagnosing = false
    @State private var showResetAlert = false
    @State private var isResetting = false
    @State private var resetMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerView
                defaultSettingsCard
                diagnosticsCard
                dataManagementCard
                dangerousOperationsCard
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 700, alignment: .leading)
        }
        .onAppear {
            Task {
                await runDiagnostics()
            }
        }
        .alert("重置所有数据", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                Task {
                    await resetAllData()
                }
            }
        } message: {
            Text("⚠️ 此操作将删除所有数据，包括产品、分类、标签、订单、说明书等，然后重新创建默认分类和标签。此操作不可撤销，确定要继续吗？")
        }
        .alert("重置完成", isPresented: .constant(!resetMessage.isEmpty)) {
            Button("确定") {
                resetMessage = ""
            }
        } message: {
            Text(resetMessage)
        }
    }

    // MARK: - 子视图
    private var headerView: some View {
        HStack {
            Image(systemName: "tray.full.fill")
                .font(.title2)
                .foregroundColor(.blue)
            Text(NSLocalizedString("Data & Defaults", comment: ""))
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.top, 24)
    }

    private var defaultSettingsCard: some View {
        SettingsCard(
            title: "默认设置",
            icon: "gearshape.fill",
            iconColor: .blue,
            description: "配置新产品的默认参数"
        ) {
            SettingsGroup {
                WarrantyDefaultView(period: $defaultWarrantyPeriod)

                Divider()
                    .padding(.vertical, 8)

                OCRDefaultView(enabled: $enableOCRByDefault)
            }
        }
    }

    private var diagnosticsCard: some View {
        SettingsCard(
            title: "数据诊断",
            icon: "stethoscope",
            iconColor: .green,
            description: "检查数据完整性和应用状态"
        ) {
            SettingsGroup {
                diagnosticsContent
            }
        }
    }

    @ViewBuilder
    private var diagnosticsContent: some View {
        Button {
            Task {
                await runDiagnostics()
            }
        } label: {
            SettingRow(
                icon: "stethoscope",
                iconColor: .green,
                title: "运行诊断",
                subtitle: isDiagnosing ? "正在检查..." : (diagnosticResult?.summary ?? "检查数据完整性"),
                showChevron: !isDiagnosing,
                isInteractive: !isDiagnosing
            )
        }
        .buttonStyle(.plain)
        .disabled(isDiagnosing)

        if isDiagnosing {
            diagnosticsProgressView
        }

        if let result = diagnosticResult {
            diagnosticsResultView(result)
        }
    }

    private var diagnosticsProgressView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("正在分析数据...")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 8)
    }

    private func diagnosticsResultView(_ result: DataDiagnostics.DiagnosticResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 8)

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("诊断完成")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(result.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                if result.hasIssues {
                    Text(result.detailedReport)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var dataManagementCard: some View {
        SettingsCard(
            title: "数据管理",
            icon: "externaldrive.fill",
            iconColor: .orange,
            description: "导入、导出和备份应用数据"
        ) {
            SettingsGroup {
                dataManagementContent
            }
        }
    }

    @ViewBuilder
    private var dataManagementContent: some View {
        NavigationLink(destination: DataExportView()) {
            SettingRow(
                icon: "arrow.up.doc.fill",
                iconColor: .green,
                title: NSLocalizedString("Export Data", comment: ""),
                subtitle: NSLocalizedString("Export products, categories, and tags", comment: ""),
                showChevron: true
            )
        }
        .buttonStyle(.plain)

        Divider()
            .padding(.vertical, 8)

        NavigationLink(destination: DataImportView()) {
            SettingRow(
                icon: "arrow.down.doc.fill",
                iconColor: .blue,
                title: NSLocalizedString("Import Data", comment: ""),
                subtitle: NSLocalizedString("Import products, categories, and tags", comment: ""),
                showChevron: true
            )
        }
        .buttonStyle(.plain)

        Divider()
            .padding(.vertical, 8)

        NavigationLink(destination: DataBackupView()) {
            SettingRow(
                icon: "externaldrive.fill",
                iconColor: .purple,
                title: NSLocalizedString("Data Backup & Restore", comment: ""),
                subtitle: NSLocalizedString("Local or iCloud backup/restore", comment: ""),
                showChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private var dangerousOperationsCard: some View {
        SettingsCard(
            title: "危险操作",
            icon: "exclamationmark.triangle.fill",
            iconColor: .red,
            description: "不可逆的数据操作，请谨慎使用"
        ) {
            SettingsGroup {
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    SettingRow(
                        icon: "trash.fill",
                        iconColor: .red,
                        title: NSLocalizedString("Reset App Data", comment: ""),
                        subtitle: NSLocalizedString("Clear all local data, cannot be recovered", comment: ""),
                        warning: true,
                        showChevron: true,
                        isInteractive: !isResetting
                    )
                }
                .buttonStyle(.plain)
                .disabled(isResetting)

                if isResetting {
                    Divider()
                        .padding(.vertical, 8)

                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在重置数据...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                if !resetMessage.isEmpty {
                    Divider()
                        .padding(.vertical, 8)

                    HStack {
                        Image(systemName: resetMessage.contains("成功") ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(resetMessage.contains("成功") ? .green : .red)
                        Text(resetMessage)
                            .font(.caption)
                            .foregroundColor(resetMessage.contains("成功") ? .green : .red)
                        Spacer()
                    }
                }
            }
        }
    }



    // MARK: - 重置所有数据
    @MainActor
    private func resetAllData() async {
        isResetting = true

        do {
            let persistenceController = PersistenceController.shared
            let result = await persistenceController.completelyResetDatabase()

            if result.success {
                resetMessage = "✅ 数据库已完全重置！默认分类和标签已恢复。\n\n请重启应用以完成重置。"
                // 重新运行诊断
                await runDiagnostics()
            } else {
                resetMessage = "❌ 重置失败：\(result.message)"
            }
        } catch {
            resetMessage = "❌ 重置失败：\(error.localizedDescription)"
        }

        isResetting = false
    }



    // MARK: - 数据诊断
    @MainActor
    private func runDiagnostics() async {
        isDiagnosing = true

        do {
            let persistenceController = PersistenceController.shared
            diagnosticResult = await persistenceController.quickDiagnose()
        } catch {
            print("诊断失败：\(error.localizedDescription)")
        }

        isDiagnosing = false
    }
}

#Preview {
    @Previewable @State var warrantyPeriod = 12
    @Previewable @State var enableOCR = true
    
    return DataSettingsPanel(
        defaultWarrantyPeriod: $warrantyPeriod,
        enableOCRByDefault: $enableOCR
    )
}