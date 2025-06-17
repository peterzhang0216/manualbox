//
//  DataManagementView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/17.
//

import SwiftUI
import CoreData

struct DataManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var diagnosticResult: DataDiagnostics.DiagnosticResult?

    private var persistenceController: PersistenceController {
        PersistenceController.shared
    }
    
    var body: some View {
        NavigationView {
            List {
                // 数据统计部分
                Section("数据统计") {
                    if let result = diagnosticResult {
                        DataStatisticsView(result: result)
                    } else {
                        Text("点击诊断按钮获取数据统计")
                            .foregroundColor(.secondary)
                    }
                }

                // 数据诊断部分
                Section("数据诊断") {
                    Button(action: performDiagnosis) {
                        HStack {
                            Image(systemName: "stethoscope")
                            Text("诊断数据状态")
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isLoading)

                    if let result = diagnosticResult {
                        VStack(alignment: .leading) {
                            Text("诊断结果:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(result.summary)
                                .foregroundColor(result.hasIssues ? .orange : .green)
                        }
                    }
                }

                // 数据清理部分
                Section("数据清理") {
                    Button(action: performAutoFix) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                            Text("自动修复问题")
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isLoading)

                    Button(action: performCompleteCleanup) {
                        HStack {
                            Image(systemName: "trash.circle")
                            Text("完整数据清理")
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isLoading)
                }

                // 危险操作部分
                Section {
                    Button(action: confirmResetAllData) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text("重置所有数据")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isLoading)

                    Button(action: forceReinitialize) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle")
                                .foregroundColor(.orange)
                            Text("强制重新初始化")
                                .foregroundColor(.orange)
                        }
                    }
                    .disabled(isLoading)
                } header: {
                    Text("危险操作")
                } footer: {
                    Text("危险操作可能导致数据丢失，请谨慎使用")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("数据管理")
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("确定") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                // 自动执行一次诊断
                if diagnosticResult == nil {
                    performDiagnosis()
                }
            }
        }
    }
    
    // MARK: - Actions

    private func performDiagnosis() {
        isLoading = true
        Task {
            let diagnostics = DataDiagnostics(context: viewContext)
            let result = await diagnostics.diagnose()
            await MainActor.run {
                self.diagnosticResult = result
                self.isLoading = false
            }
        }
    }

    private func performAutoFix() {
        isLoading = true
        Task {
            let cleanupService = DataCleanupService(context: viewContext)
            let result = await cleanupService.performCompleteCleanup()
            await MainActor.run {
                self.isLoading = false
                self.alertTitle = result.success ? "修复成功" : "修复失败"
                self.alertMessage = result.success ? result.summary : result.message
                self.showingAlert = true

                // 修复后重新诊断
                if result.success {
                    performDiagnosis()
                }
            }
        }
    }

    private func performCompleteCleanup() {
        isLoading = true
        Task {
            let cleanupService = DataCleanupService(context: viewContext)
            let result = await cleanupService.performCompleteCleanup()
            await MainActor.run {
                self.isLoading = false
                self.alertTitle = result.success ? "清理完成" : "清理失败"
                self.alertMessage = result.success ? result.summary : result.message
                self.showingAlert = true

                // 清理后重新诊断
                if result.success {
                    performDiagnosis()
                }
            }
        }
    }

    private func confirmResetAllData() {
        alertTitle = "确认重置"
        alertMessage = "此操作将删除所有数据，包括产品、分类、标签等。此操作不可撤销，确定要继续吗？"
        showingAlert = true
    }

    private func forceReinitialize() {
        isLoading = true
        Task {
            let initService = DataInitializationService(context: viewContext)
            let result = await initService.forceReinitialize(includeSampleData: true)
            await MainActor.run {
                self.isLoading = false
                self.alertTitle = result.success ? "重新初始化完成" : "重新初始化失败"
                self.alertMessage = result.summary
                self.showingAlert = true

                // 重新初始化后重新诊断
                if result.success {
                    performDiagnosis()
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct DataStatisticsView: View {
    let result: DataDiagnostics.DiagnosticResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("分类")
                Spacer()
                Text("\(result.totalCategories)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("标签")
                Spacer()
                Text("\(result.totalTags)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("产品")
                Spacer()
                Text("\(result.totalProducts)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("订单")
                Spacer()
                Text("\(result.totalOrders)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("说明书")
                Spacer()
                Text("\(result.totalManuals)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("维修记录")
                Spacer()
                Text("\(result.totalRepairRecords)")
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    DataManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
