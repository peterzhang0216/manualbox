import SwiftUI
import CoreData

// MARK: - 默认设置内容
struct DefaultSettingsContent: View {
    @Binding var defaultWarrantyPeriod: Int
    @Binding var enableOCRByDefault: Bool
    
    var body: some View {
        SettingsCard(
            title: "默认参数配置",
            icon: "gearshape.fill",
            iconColor: .blue,
            description: "设置新增商品时的默认参数"
        ) {
            LegacySettingsGroup {
                WarrantyDefaultView(period: $defaultWarrantyPeriod)

                Divider()
                    .padding(.vertical, 8)

                OCRDefaultView(enabled: $enableOCRByDefault)
            }
        }
    }
}

// MARK: - 数据管理内容
struct DataManagementContent: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var diagnosticResult: DataDiagnostics.DiagnosticResult?
    @State private var isDiagnosing = false

    var body: some View {
        VStack(spacing: 24) {
            // 数据健康检查卡片
            SettingsCard(
                title: "数据健康检查",
                icon: "stethoscope",
                iconColor: .green,
                description: "检测数据完整性，确保应用正常运行"
            ) {
                LegacySettingsGroup {
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
                        Divider()
                            .padding(.vertical, 8)

                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("正在检查数据完整性...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }

                    if let result = diagnosticResult {
                        Divider()
                            .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 8) {
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
                }
            }

            // 数据操作卡片
            SettingsCard(
                title: "数据操作",
                icon: "externaldrive.fill",
                iconColor: .orange,
                description: "备份、导出和导入您的商品数据"
            ) {
                LegacySettingsGroup {
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
            }
        }
        .onAppear {
            Task {
                await runDiagnostics()
            }
        }
    }

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



// MARK: - 危险操作内容
struct DangerousOperationsContent: View {
    @State private var showResetAlert = false
    @State private var isResetting = false
    @State private var resetMessage = ""
    
    var body: some View {
        SettingsCard(
            title: "数据重置操作",
            icon: "exclamationmark.triangle.fill",
            iconColor: .red,
            description: "⚠️ 危险操作：此操作将永久删除所有数据"
        ) {
            LegacySettingsGroup {
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
    }
    
    @MainActor
    private func resetAllData() async {
        isResetting = true

        do {
            let persistenceController = PersistenceController.shared
            let result = await persistenceController.completelyResetDatabase()

            if result.success {
                resetMessage = "✅ 数据重置成功！\n\n所有数据已清除，默认分类和标签已恢复。\n建议重启应用以确保完全生效。"
            } else {
                resetMessage = "❌ 重置失败：\(result.message)"
            }
        } catch {
            resetMessage = "❌ 重置过程中发生错误：\(error.localizedDescription)"
        }

        isResetting = false
    }
}

#Preview {
    VStack(spacing: 20) {
        DefaultSettingsContent(
            defaultWarrantyPeriod: .constant(12),
            enableOCRByDefault: .constant(true)
        )
        DataManagementContent()
        DangerousOperationsContent()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .padding()
}
