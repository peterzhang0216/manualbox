//
//  PrivacySettingsView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  隐私设置视图 - 管理隐私保护和用户同意
//

import SwiftUI

struct PrivacySettingsView: View {
    @StateObject private var privacyManager = PrivacyProtectionManager.shared
    @StateObject private var auditLogger = AccessAuditLogger.shared
    
    @State private var showingConsentDetails = false
    @State private var showingDeletionConfirmation = false
    @State private var showingDataExport = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var selectedDeletionRequest: DataDeletionRequest?
    @State private var isProcessing = false
    
    var body: some View {
        List {
            // 隐私保护状态
            privacyProtectionSection
            
            // 用户同意管理
            consentManagementSection
            
            // 数据匿名化
            dataAnonymizationSection
            
            // 数据保留
            dataRetentionSection
            
            // 数据删除请求
            dataDeletionSection
            
            // 隐私统计
            privacyStatisticsSection
        }
        .navigationTitle("隐私设置")
        .navigationBarTitleDisplayMode(.large)
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingConsentDetails) {
            ConsentManagementSheet()
        }
        .sheet(isPresented: $showingDataExport) {
            PrivacyDataExportSheet()
        }
        .alert("确认删除数据", isPresented: $showingDeletionConfirmation, presenting: selectedDeletionRequest) { request in
            Button("取消", role: .cancel) {
                privacyManager.cancelDeletionRequest(request)
                selectedDeletionRequest = nil
            }
            Button("确认删除", role: .destructive) {
                confirmDeletion(request)
            }
        } message: { request in
            Text("确定要删除 \(request.dataType) 数据吗？此操作无法撤销。\n\n原因：\(request.reason)")
        }
    }
    
    // MARK: - 隐私保护状态部分
    
    private var privacyProtectionSection: some View {
        Section(header: Text("隐私保护")) {
            HStack {
                Image(systemName: privacyManager.isPrivacyProtectionEnabled ? "shield.fill" : "shield.slash")
                    .foregroundColor(privacyManager.isPrivacyProtectionEnabled ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("隐私保护")
                        .font(.body)
                    
                    Text(privacyManager.isPrivacyProtectionEnabled ? "已启用" : "已禁用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { privacyManager.isPrivacyProtectionEnabled },
                    set: { newValue in
                        privacyManager.setPrivacyProtectionEnabled(newValue)
                    }
                ))
                .disabled(isProcessing)
            }
            
            if privacyManager.isPrivacyProtectionEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("隐私保护功能:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    PrivacyFeatureRow(
                        icon: "checkmark.shield",
                        title: "用户同意管理",
                        description: "管理数据处理同意",
                        isEnabled: true
                    )
                    
                    PrivacyFeatureRow(
                        icon: "eye.slash",
                        title: "数据匿名化",
                        description: "保护敏感信息",
                        isEnabled: privacyManager.anonymizationEnabled
                    )
                    
                    PrivacyFeatureRow(
                        icon: "clock",
                        title: "数据保留管理",
                        description: "自动删除过期数据",
                        isEnabled: privacyManager.dataRetentionEnabled
                    )
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            if let error = privacyManager.lastPrivacyError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - 用户同意管理部分
    
    private var consentManagementSection: some View {
        Section(header: Text("用户同意管理")) {
            // 同意概览
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("数据处理同意")
                        .font(.body)
                    
                    let stats = privacyManager.getPrivacyStatistics()
                    Text("\(stats.grantedConsents)/\(stats.totalConsents) 项已同意")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("管理") {
                    showingConsentDetails = true
                }
                .buttonStyle(.bordered)
            }
            
            // 同意状态列表
            if privacyManager.isPrivacyProtectionEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("同意状态:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(DataProcessingPurpose.allCases, id: \.rawValue) { purpose in
                        let consent = privacyManager.consentRecords.first { $0.purpose == purpose }
                        let status = consent?.status ?? (purpose.isRequired ? .granted : .pending)
                        
                        HStack {
                            Circle()
                                .fill(status.color)
                                .frame(width: 8, height: 8)
                            
                            Text(purpose.displayName)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text(status.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(status.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(status.color.opacity(0.1))
                                .cornerRadius(4)
                            
                            if purpose.isRequired {
                                Text("必需")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(3)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 数据匿名化部分
    
    private var dataAnonymizationSection: some View {
        Section(header: Text("数据匿名化")) {
            HStack {
                Image(systemName: privacyManager.anonymizationEnabled ? "eye.slash.fill" : "eye.slash")
                    .foregroundColor(privacyManager.anonymizationEnabled ? .green : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("数据匿名化")
                        .font(.body)
                    
                    Text("自动匿名化敏感信息")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { privacyManager.anonymizationEnabled },
                    set: { newValue in
                        // 在实际应用中，这里应该调用privacyManager的方法
                        print("匿名化设置更改: \(newValue)")
                    }
                ))
                .disabled(!privacyManager.isPrivacyProtectionEnabled)
            }
            
            if privacyManager.anonymizationEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("匿名化方法:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(AnonymizationMethod.allCases, id: \.rawValue) { method in
                        HStack {
                            Image(systemName: getMethodIcon(method))
                                .foregroundColor(.blue)
                                .frame(width: 16)
                            
                            Text(method.displayName)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text(getMethodDescription(method))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 数据保留部分
    
    private var dataRetentionSection: some View {
        Section(header: Text("数据保留")) {
            HStack {
                Image(systemName: privacyManager.dataRetentionEnabled ? "clock.fill" : "clock")
                    .foregroundColor(privacyManager.dataRetentionEnabled ? .green : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("自动数据清理")
                        .font(.body)
                    
                    Text("根据保留政策自动删除过期数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { privacyManager.dataRetentionEnabled },
                    set: { newValue in
                        // 在实际应用中，这里应该调用privacyManager的方法
                        print("数据保留设置更改: \(newValue)")
                    }
                ))
                .disabled(!privacyManager.isPrivacyProtectionEnabled)
            }
            
            // 手动执行数据保留检查
            Button(action: {
                performDataRetentionCheck()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                    
                    Text("立即检查过期数据")
                        .foregroundColor(.primary)
                }
            }
            .disabled(isProcessing || !privacyManager.dataRetentionEnabled)
            
            if privacyManager.dataRetentionEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("数据保留期限:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(DataProcessingPurpose.allCases, id: \.rawValue) { purpose in
                        HStack {
                            Text(purpose.displayName)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text(getRetentionDescription(purpose))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 数据删除请求部分
    
    private var dataDeletionSection: some View {
        Section(header: Text("数据删除")) {
            // 创建删除请求按钮
            Button(action: {
                createDeletionRequest()
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    
                    Text("请求删除数据")
                        .foregroundColor(.primary)
                }
            }
            
            // 待处理的删除请求
            if !privacyManager.pendingDeletions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("待处理删除请求:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(privacyManager.pendingDeletions) { request in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.dataType)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Text(request.reason)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if request.confirmationRequired {
                                Button("确认") {
                                    selectedDeletionRequest = request
                                    showingDeletionConfirmation = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            Button("取消") {
                                privacyManager.cancelDeletionRequest(request)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 隐私统计部分
    
    private var privacyStatisticsSection: some View {
        Section(header: Text("隐私统计")) {
            let stats = privacyManager.getPrivacyStatistics()
            
            // 导出隐私数据按钮
            Button(action: {
                showingDataExport = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    
                    Text("导出隐私数据")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            // 统计信息
            VStack(alignment: .leading, spacing: 8) {
                Text("隐私保护统计")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                StatisticRow(title: "同意覆盖率", value: String(format: "%.1f%%", stats.consentCoverage * 100), color: "blue")
                StatisticRow(title: "已授予同意", value: "\(stats.grantedConsents)", color: "green")
                StatisticRow(title: "过期同意", value: "\(stats.expiredConsents)", color: "orange")
                StatisticRow(title: "待删除请求", value: "\(stats.pendingDeletions)", color: stats.pendingDeletions > 0 ? "red" : "gray")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 辅助方法
    
    private func getMethodIcon(_ method: AnonymizationMethod) -> String {
        switch method {
        case .hash: return "number.square"
        case .mask: return "eye.slash"
        case .remove: return "trash"
        case .generalize: return "square.grid.3x1.below.line.grid.1x2"
        }
    }
    
    private func getMethodDescription(_ method: AnonymizationMethod) -> String {
        switch method {
        case .hash: return "转换为哈希值"
        case .mask: return "部分遮盖"
        case .remove: return "完全移除"
        case .generalize: return "泛化处理"
        }
    }
    
    private func getRetentionDescription(_ purpose: DataProcessingPurpose) -> String {
        let days = purpose.dataRetentionDays
        if days < 0 {
            return "永久保留"
        } else if days < 30 {
            return "\(days) 天"
        } else if days < 365 {
            return "\(days / 30) 个月"
        } else {
            return "\(days / 365) 年"
        }
    }
    
    private func performDataRetentionCheck() {
        isProcessing = true
        
        Task {
            await privacyManager.performDataRetentionCheck()
            
            alertTitle = "数据保留检查完成"
            alertMessage = "已检查并清理过期数据。"
            showingAlert = true
            
            isProcessing = false
        }
    }
    
    private func createDeletionRequest() {
        Task {
            do {
                try await privacyManager.requestDataDeletion(
                    dataType: "用户数据",
                    reason: "用户主动请求删除",
                    confirmationRequired: true
                )
                
                alertTitle = "删除请求已创建"
                alertMessage = "您的数据删除请求已创建，请确认后执行删除。"
                showingAlert = true
                
            } catch {
                alertTitle = "创建删除请求失败"
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
    
    private func confirmDeletion(_ request: DataDeletionRequest) {
        isProcessing = true
        
        Task {
            do {
                try await privacyManager.confirmAndExecuteDeletion(request)
                
                alertTitle = "数据删除完成"
                alertMessage = "请求的数据已成功删除。"
                showingAlert = true
                
            } catch {
                alertTitle = "数据删除失败"
                alertMessage = error.localizedDescription
                showingAlert = true
            }
            
            selectedDeletionRequest = nil
            isProcessing = false
        }
    }
}

// MARK: - 隐私功能行组件
struct PrivacyFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isEnabled ? .green : .gray)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
    }
}

// MARK: - 同意管理弹窗
struct ConsentManagementSheet: View {
    @StateObject private var privacyManager = PrivacyProtectionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isUpdating = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(DataProcessingPurpose.allCases, id: \.rawValue) { purpose in
                    let consent = privacyManager.consentRecords.first { $0.purpose == purpose }
                    let currentStatus = consent?.status ?? (purpose.isRequired ? .granted : .pending)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(purpose.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text(currentStatus.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(currentStatus.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(currentStatus.color.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        Text(purpose.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if purpose.isRequired {
                            Text("此功能为应用核心功能，无法撤回同意")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        } else {
                            HStack {
                                Button(currentStatus == .granted ? "撤回同意" : "授予同意") {
                                    toggleConsent(for: purpose, currentStatus: currentStatus)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(isUpdating)
                                
                                if let consent = consent, let grantedDate = consent.grantedDate {
                                    Text("授予时间: \(grantedDate, style: .date)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("同意管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func toggleConsent(for purpose: DataProcessingPurpose, currentStatus: ConsentStatus) {
        isUpdating = true
        
        Task {
            do {
                let newStatus: ConsentStatus = currentStatus == .granted ? .withdrawn : .granted
                try await privacyManager.updateConsentStatus(for: purpose, status: newStatus)
            } catch {
                print("同意状态更新失败: \(error)")
            }
            
            isUpdating = false
        }
    }
}

// MARK: - 隐私数据导出弹窗
struct PrivacyDataExportSheet: View {
    @StateObject private var privacyManager = PrivacyProtectionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                VStack(spacing: 8) {
                    Text("导出隐私数据")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("导出您的隐私设置、同意记录和删除请求等信息")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("导出内容包括:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ExportContentRow(icon: "hand.raised", title: "用户同意记录", description: "所有数据处理同意的历史记录")
                    ExportContentRow(icon: "gear", title: "隐私设置", description: "当前的隐私保护配置")
                    ExportContentRow(icon: "trash", title: "删除请求", description: "待处理的数据删除请求")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                Button(action: {
                    exportPrivacyData()
                }) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        
                        Text(isExporting ? "导出中..." : "开始导出")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
                
                Spacer()
            }
            .padding()
            .navigationTitle("导出隐私数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportPrivacyData() {
        isExporting = true
        
        // 模拟导出过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let exportData = privacyManager.exportPrivacyData()
            print("隐私数据已导出: \(exportData)")
            
            isExporting = false
            dismiss()
        }
    }
}

// MARK: - 导出内容行组件
struct ExportContentRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - 统计行组件已移至InfoRow.swift

#Preview {
    NavigationView {
        PrivacySettingsView()
    }
}