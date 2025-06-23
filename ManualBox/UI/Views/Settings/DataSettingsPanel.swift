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
        .alert("确认重置数据", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) { }
            Button("确认重置", role: .destructive) {
                Task {
                    await resetAllData()
                }
            }
        } message: {
            Text("⚠️ 此操作将永久删除所有数据，包括：\n• 所有商品信息\n• 分类和标签\n• 说明书和图片\n• 维修记录\n\n重置后将恢复默认的分类和标签。\n\n此操作无法撤销，请确认是否继续？")
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
            Text("数据与默认设置")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.top, 24)
    }

    private var defaultSettingsCard: some View {
        SettingsCard(
            title: "默认配置",
            icon: "gearshape.fill",
            iconColor: .blue,
            description: "设置新增商品时的默认参数"
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
            title: "数据健康检查",
            icon: "stethoscope",
            iconColor: .green,
            description: "检测数据完整性，确保应用正常运行"
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
                title: "开始检查",
                subtitle: isDiagnosing ? "正在分析数据..." : (diagnosticResult?.summary ?? "点击检查数据完整性"),
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
            Text("正在检查数据完整性...")
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
                Text("检查完成")
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
            description: "备份、导出和导入您的商品数据"
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
                title: "导出数据",
                subtitle: "将商品、分类、标签等数据导出为文件",
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
                title: "导入数据",
                subtitle: "从文件中导入商品、分类、标签等数据",
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
                title: "备份与恢复",
                subtitle: "创建完整备份或从备份中恢复数据",
                showChevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private var dangerousOperationsCard: some View {
        SettingsCard(
            title: "重置数据",
            icon: "exclamationmark.triangle.fill",
            iconColor: .red,
            description: "⚠️ 危险操作：此操作将永久删除所有数据"
        ) {
            SettingsGroup {
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    SettingRow(
                        icon: "trash.fill",
                        iconColor: .red,
                        title: "重置所有数据",
                        subtitle: "删除所有商品、分类、标签等数据，恢复默认设置",
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
                        Text("正在清除数据，请稍候...")
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
                resetMessage = "✅ 数据重置成功！\n\n所有数据已清除，默认分类和标签已恢复。\n建议重启应用以确保完全生效。"
                // 重新运行诊断
                await runDiagnostics()
            } else {
                resetMessage = "❌ 重置失败：\(result.message)"
            }
        } catch {
            resetMessage = "❌ 重置过程中发生错误：\(error.localizedDescription)"
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
            print("数据检查失败：\(error.localizedDescription)")
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