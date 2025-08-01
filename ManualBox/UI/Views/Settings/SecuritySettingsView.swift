//
//  SecuritySettingsView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  安全设置视图 - 管理数据加密和传输安全设置
//

import SwiftUI
import LocalAuthentication

struct SecuritySettingsView: View {
    @StateObject private var encryptionService = DataEncryptionService.shared
    @StateObject private var keyManager = KeyManager.shared
    @StateObject private var transmissionSecurity = DataTransmissionSecurityManager.shared
    @StateObject private var biometricManager = BiometricAuthenticationManager.shared
    
    @State private var showingEncryptionAlert = false
    @State private var showingKeyRegenerationAlert = false
    @State private var showingEncryptionStatistics = false
    @State private var showingTransmissionStatistics = false
    @State private var isProcessing = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    var body: some View {
        List {
            // 数据加密部分
            dataEncryptionSection
            
            // 生物识别认证部分
            biometricAuthenticationSection
            
            // 传输安全部分
            transmissionSecuritySection
            
            // 密钥管理部分
            keyManagementSection
            
            // 统计信息部分
            statisticsSection
        }
        .navigationTitle("安全设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .alert(alertTitle, isPresented: $showingEncryptionAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingEncryptionStatistics) {
            EncryptionStatisticsSheet()
        }
        .sheet(isPresented: $showingTransmissionStatistics) {
            TransmissionStatisticsSheet()
        }
        .onAppear {
            biometricManager.checkBiometricAvailability()
        }
    }
    
    // MARK: - 数据加密部分
    
    private var dataEncryptionSection: some View {
        Section {
            // 加密状态
            HStack {
                Image(systemName: encryptionService.isEncryptionEnabled ? "lock.fill" : "lock.open")
                    .foregroundColor(encryptionService.isEncryptionEnabled ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("数据加密")
                        .font(.body)
                    
                    Text(encryptionService.encryptionStatus.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { encryptionService.isEncryptionEnabled },
                    set: { newValue in
                        toggleEncryption(newValue)
                    }
                ))
                .disabled(isProcessing)
            }
            
            // 加密类型说明
            if encryptionService.isEncryptionEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("加密保护的数据类型:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(DataEncryptionService.SensitiveDataType.allCases, id: \.rawValue) { dataType in
                        HStack {
                            Image(systemName: dataType.requiresBiometric ? "faceid" : "key.fill")
                                .foregroundColor(dataType.requiresBiometric ? .blue : .green)
                                .frame(width: 20)
                            
                            Text(dataTypeDisplayName(dataType))
                                .font(.caption)
                            
                            Spacer()
                            
                            if dataType.requiresBiometric {
                                Text("需要生物识别")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            // 错误信息
            if let error = encryptionService.lastEncryptionError {
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
    
    // MARK: - 生物识别认证部分
    
    private var biometricAuthenticationSection: some View {
        Section(header: Text("生物识别认证")) {
            HStack {
                Image(systemName: biometricIconName)
                    .foregroundColor(biometricManager.isBiometricAvailable ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(biometricManager.biometricTypeDescription)
                        .font(.body)
                    
                    Text(biometricManager.isBiometricAvailable ? "可用" : "不可用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if biometricManager.isBiometricAvailable {
                    Button("测试") {
                        testBiometricAuthentication()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                }
            }
            
            if biometricManager.isBiometricAvailable {
                Text("生物识别认证用于保护敏感数据的访问，包括个人信息、财务数据和密码。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - 传输安全部分
    
    private var transmissionSecuritySection: some View {
        Section(header: Text("传输安全")) {
            // 安全传输开关
            HStack {
                Image(systemName: "network.badge.shield.half.filled")
                    .foregroundColor(transmissionSecurity.isSecureTransmissionEnabled ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("安全传输")
                        .font(.body)
                    
                    Text("加密网络传输数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { transmissionSecurity.isSecureTransmissionEnabled },
                    set: { newValue in
                        transmissionSecurity.configureSecureTransmission(enableSecureTransmission: newValue)
                    }
                ))
            }
            
            // 证书验证开关
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(transmissionSecurity.certificateValidationEnabled ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("证书验证")
                        .font(.body)
                    
                    Text("验证服务器SSL证书")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { transmissionSecurity.certificateValidationEnabled },
                    set: { newValue in
                        transmissionSecurity.configureSecureTransmission(
                            enableSecureTransmission: transmissionSecurity.isSecureTransmissionEnabled,
                            enableCertificateValidation: newValue
                        )
                    }
                ))
            }
            
            // 传输错误信息
            if let error = transmissionSecurity.lastTransmissionError {
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
    
    // MARK: - 密钥管理部分
    
    private var keyManagementSection: some View {
        Section(header: Text("密钥管理")) {
            // 密钥统计
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("已存储密钥")
                        .font(.body)
                    
                    Text("\(keyManager.availableKeys.count) 个密钥")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if keyManager.keyGenerationInProgress {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // 重新生成密钥按钮
            Button(action: {
                showingKeyRegenerationAlert = true
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重新生成密钥")
                }
            }
            .foregroundColor(.orange)
            .disabled(isProcessing || keyManager.keyGenerationInProgress)
            .alert("重新生成密钥", isPresented: $showingKeyRegenerationAlert) {
                Button("取消", role: .cancel) { }
                Button("确认", role: .destructive) {
                    regenerateKeys()
                }
            } message: {
                Text("这将重新生成所有加密密钥。请确保您已备份重要数据。")
            }
            
            // 验证密钥完整性按钮
            Button(action: {
                verifyKeyIntegrity()
            }) {
                HStack {
                    Image(systemName: "checkmark.shield")
                    Text("验证密钥完整性")
                }
            }
            .foregroundColor(.blue)
            .disabled(isProcessing)
            
            // 密钥错误信息
            if let error = keyManager.lastKeyError {
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
    
    // MARK: - 统计信息部分
    
    private var statisticsSection: some View {
        Section(header: Text("统计信息")) {
            // 加密统计
            Button(action: {
                showingEncryptionStatistics = true
            }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                    
                    Text("加密统计")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            // 传输统计
            Button(action: {
                showingTransmissionStatistics = true
            }) {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.green)
                    
                    Text("传输统计")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private var biometricIconName: String {
        switch biometricManager.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "person.crop.circle.badge.xmark"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    private func dataTypeDisplayName(_ dataType: DataEncryptionService.SensitiveDataType) -> String {
        switch dataType {
        case .personalInfo:
            return "个人信息"
        case .financialData:
            return "财务数据"
        case .passwords:
            return "密码"
        case .notes:
            return "笔记"
        case .documents:
            return "文档"
        }
    }
    
    private func toggleEncryption(_ enabled: Bool) {
        isProcessing = true
        
        Task {
            do {
                if enabled {
                    try await encryptionService.enableEncryption()
                    alertTitle = "加密已启用"
                    alertMessage = "数据加密已成功启用。您的敏感数据现在受到保护。"
                } else {
                    try await encryptionService.disableEncryption()
                    alertTitle = "加密已禁用"
                    alertMessage = "数据加密已禁用。请注意您的数据将不再受到加密保护。"
                }
                
                showingEncryptionAlert = true
                
            } catch {
                alertTitle = "操作失败"
                alertMessage = error.localizedDescription
                showingEncryptionAlert = true
            }
            
            isProcessing = false
        }
    }
    
    private func testBiometricAuthentication() {
        isProcessing = true
        
        Task {
            let success = await biometricManager.authenticateUser(reason: "测试生物识别认证功能")
            
            alertTitle = success ? "认证成功" : "认证失败"
            alertMessage = success ? "生物识别认证测试成功。" : "生物识别认证测试失败，请检查设备设置。"
            showingEncryptionAlert = true
            
            isProcessing = false
        }
    }
    
    private func regenerateKeys() {
        isProcessing = true
        
        Task {
            do {
                try await keyManager.regenerateAllKeys()
                
                alertTitle = "密钥重新生成成功"
                alertMessage = "所有加密密钥已重新生成。"
                showingEncryptionAlert = true
                
            } catch {
                alertTitle = "密钥重新生成失败"
                alertMessage = error.localizedDescription
                showingEncryptionAlert = true
            }
            
            isProcessing = false
        }
    }
    
    private func verifyKeyIntegrity() {
        isProcessing = true
        
        Task {
            let isValid = await keyManager.verifyKeyIntegrity()
            
            alertTitle = isValid ? "密钥完整性验证成功" : "密钥完整性验证失败"
            alertMessage = isValid ? "所有密钥完整性验证通过。" : "发现密钥完整性问题，建议重新生成密钥。"
            showingEncryptionAlert = true
            
            isProcessing = false
        }
    }
}

// MARK: - 加密统计弹窗
struct EncryptionStatisticsSheet: View {
    @StateObject private var encryptionService = DataEncryptionService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                let statistics = encryptionService.getEncryptionStatistics()
                
                Section(header: Text("加密状态")) {
                    StatisticRow(title: "加密状态", value: statistics.status.description, color: statistics.status.color)
                    StatisticRow(title: "是否启用", value: statistics.isEnabled ? "是" : "否", color: statistics.isEnabled ? "green" : "red")
                }
                
                Section(header: Text("支持的数据类型")) {
                    ForEach(statistics.supportedDataTypes, id: \.self) { dataType in
                        Text(dataType)
                            .font(.body)
                    }
                }
                
                if let error = statistics.lastError {
                    Section(header: Text("最近错误")) {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("加密统计")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 传输统计弹窗
struct TransmissionStatisticsSheet: View {
    @StateObject private var transmissionSecurity = DataTransmissionSecurityManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                let statistics = transmissionSecurity.getTransmissionStatistics()
                
                Section(header: Text("传输统计")) {
                    StatisticRow(title: "加密传输", value: "\(statistics.encryptedTransmissions)", color: "blue")
                    StatisticRow(title: "解密传输", value: "\(statistics.decryptedTransmissions)", color: "green")
                    StatisticRow(title: "失败传输", value: "\(statistics.failedTransmissions)", color: "red")
                    StatisticRow(title: "成功率", value: String(format: "%.1f%%", statistics.successRate * 100), color: "blue")
                }
                
                Section(header: Text("数据量")) {
                    StatisticRow(title: "已加密数据", value: ByteCountFormatter.string(fromByteCount: statistics.totalDataEncrypted, countStyle: .file), color: "blue")
                    StatisticRow(title: "已解密数据", value: ByteCountFormatter.string(fromByteCount: statistics.totalDataDecrypted, countStyle: .file), color: "green")
                }
                
                Section(header: Text("证书验证")) {
                    StatisticRow(title: "成功验证", value: "\(statistics.successfulCertificateValidations)", color: "green")
                    StatisticRow(title: "失败验证", value: "\(statistics.failedCertificateValidations)", color: "red")
                    StatisticRow(title: "验证成功率", value: String(format: "%.1f%%", statistics.certificateValidationSuccessRate * 100), color: "blue")
                }
                
                Section(header: Text("操作")) {
                    Button("重置统计") {
                        transmissionSecurity.resetTransmissionStatistics()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("传输统计")
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
}

// MARK: - 统计行组件
struct StatisticRow: View {
    let title: String
    let value: String
    let color: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(colorFromString(color))
        }
    }
    
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .primary
        }
    }
}

#Preview {
    NavigationView {
        SecuritySettingsView()
    }
}