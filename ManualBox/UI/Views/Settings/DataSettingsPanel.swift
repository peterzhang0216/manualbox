import SwiftUI
import CoreData

// MARK: - 数据与默认设置面板
struct DataSettingsPanel: View {
    @Binding var defaultWarrantyPeriod: Int
    @Binding var enableOCRByDefault: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showCleanupAlert = false
    @State private var isCleaningUp = false
    @State private var cleanupMessage = ""
    @State private var diagnosticResult: DataDiagnostics.DiagnosticResult?
    @State private var isDiagnosing = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(NSLocalizedString("Data & Defaults", comment: ""))
                    .font(.title2).bold()
                    .padding(.top, 24)
                    .foregroundColor(.accentColor)
                
                Divider().background(Color.accentColor.opacity(0.3))
                
                // 默认值设置卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Default Settings", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    // 保修期默认设置卡片
                    VStack(alignment: .leading, spacing: 12) {
                        WarrantyDefaultView(period: $defaultWarrantyPeriod)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.secondary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // OCR默认设置卡片
                    VStack(alignment: .leading, spacing: 12) {
                        OCRDefaultView(enabled: $enableOCRByDefault)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.secondary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 数据管理卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Data Management", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    Button {
                        Task {
                            await runDiagnostics()
                        }
                    } label: {
                        SettingRow(
                            icon: "stethoscope",
                            iconColor: .blue,
                            title: "数据诊断",
                            subtitle: isDiagnosing ? "正在检查..." : (diagnosticResult?.summary ?? "检查数据完整性")
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDiagnosing)

                    Button {
                        showCleanupAlert = true
                    } label: {
                        SettingRow(
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: .orange,
                            title: "清理重复数据",
                            subtitle: "清理重复的分类和标签数据"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isCleaningUp || (diagnosticResult?.hasIssues == false))

                    NavigationLink(destination: DataExportView()) {
                        SettingRow(
                            icon: "arrow.up.doc.fill",
                            iconColor: .green,
                            title: NSLocalizedString("Export Data", comment: ""),
                            subtitle: NSLocalizedString("Export products, categories, and tags", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: DataImportView()) {
                        SettingRow(
                            icon: "arrow.down.doc.fill",
                            iconColor: .blue,
                            title: NSLocalizedString("Import Data", comment: ""),
                            subtitle: NSLocalizedString("Import products, categories, and tags", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: DataBackupView()) {
                        SettingRow(
                            icon: "externaldrive.fill",
                            iconColor: .purple,
                            title: NSLocalizedString("Data Backup & Restore", comment: ""),
                            subtitle: NSLocalizedString("Local or iCloud backup/restore", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(role: .destructive) {
                        // showResetAlert = true
                    } label: {
                        SettingRow(
                            icon: "trash.fill",
                            iconColor: .red,
                            title: NSLocalizedString("Reset App Data", comment: ""),
                            subtitle: NSLocalizedString("Clear all local data, cannot be recovered", comment: ""),
                            warning: true
                        )
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 600, alignment: .leading)
        }
        .onAppear {
            Task {
                await runDiagnostics()
            }
        }
        .alert("清理重复数据", isPresented: $showCleanupAlert) {
            Button("取消", role: .cancel) { }
            Button("清理", role: .destructive) {
                Task {
                    await cleanupDuplicateData()
                }
            }
        } message: {
            Text("这将删除重复的分类和标签数据。此操作不可撤销，确定要继续吗？")
        }
        .alert("清理完成", isPresented: .constant(!cleanupMessage.isEmpty)) {
            Button("确定") {
                cleanupMessage = ""
            }
        } message: {
            Text(cleanupMessage)
        }
    }

    // MARK: - 清理重复数据
    @MainActor
    private func cleanupDuplicateData() async {
        isCleaningUp = true

        do {
            if let persistenceController = try? PersistenceController.shared {
                await persistenceController.cleanupDuplicateData()
                cleanupMessage = "重复数据清理完成！"
            } else {
                cleanupMessage = "清理失败：无法访问数据库"
            }
        } catch {
            cleanupMessage = "清理失败：\(error.localizedDescription)"
        }

        isCleaningUp = false
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