//
//  AccessControlSettingsView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  访问控制设置视图 - 管理用户权限和访问控制
//

import SwiftUI

struct AccessControlSettingsView: View {
    @StateObject private var accessControl = AccessControlManager.shared
    @StateObject private var auditLogger = AccessAuditLogger.shared
    
    @State private var showingRoleSelection = false
    @State private var showingPermissionCustomization = false
    @State private var showingAuditLogs = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        List {
            // 访问控制状态
            accessControlStatusSection
            
            // 用户角色管理
            userRoleSection
            
            // 权限管理
            permissionManagementSection
            
            // 审计日志
            auditLogSection
            
            // 统计信息
            statisticsSection
        }
        .navigationTitle("访问控制")
        .navigationBarTitleDisplayMode(.large)
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingRoleSelection) {
            RoleSelectionSheet()
        }
        .sheet(isPresented: $showingPermissionCustomization) {
            PermissionCustomizationSheet()
        }
        .sheet(isPresented: $showingAuditLogs) {
            AuditLogViewerSheet()
        }
    }
    
    // MARK: - 访问控制状态部分
    
    private var accessControlStatusSection: some View {
        Section(header: Text("访问控制状态")) {
            HStack {
                Image(systemName: accessControl.isAccessControlEnabled ? "shield.fill" : "shield.slash")
                    .foregroundColor(accessControl.isAccessControlEnabled ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("访问控制")
                        .font(.body)
                    
                    Text(accessControl.isAccessControlEnabled ? "已启用" : "已禁用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { accessControl.isAccessControlEnabled },
                    set: { newValue in
                        toggleAccessControl(newValue)
                    }
                ))
                .disabled(isProcessing)
            }
            
            if accessControl.isAccessControlEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("当前角色:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(accessControl.currentUserRole.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("权限数量:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(accessControl.currentPermissions.count)/\(Permission.allCases.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            if let error = accessControl.lastAccessError {
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
    
    // MARK: - 用户角色部分
    
    private var userRoleSection: some View {
        Section(header: Text("用户角色")) {
            // 当前角色显示
            HStack {
                Image(systemName: "person.badge.key")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前角色")
                        .font(.body)
                    
                    Text(accessControl.currentUserRole.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("更改") {
                    showingRoleSelection = true
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing || !accessControl.hasPermission(.manageUsers))
            }
            
            // 角色权限预览
            if accessControl.isAccessControlEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("角色权限:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(Array(accessControl.currentPermissions).sorted(by: { $0.displayName < $1.displayName }), id: \.rawValue) { permission in
                            HStack {
                                Image(systemName: permission.icon)
                                    .foregroundColor(permission.category.color)
                                    .frame(width: 16)
                                
                                Text(permission.displayName)
                                    .font(.caption)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(permission.category.color.opacity(0.1))
                            .cornerRadius(6)
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
    
    // MARK: - 权限管理部分
    
    private var permissionManagementSection: some View {
        Section(header: Text("权限管理")) {
            // 自定义权限按钮
            Button(action: {
                showingPermissionCustomization = true
            }) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.blue)
                    
                    Text("自定义权限")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .disabled(!accessControl.hasPermission(.managePermissions))
            
            // 重置权限按钮
            Button(action: {
                resetPermissions()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.orange)
                    
                    Text("重置权限")
                        .foregroundColor(.orange)
                }
            }
            .disabled(isProcessing || !accessControl.hasPermission(.managePermissions))
            
            // 权限分类统计
            if accessControl.isAccessControlEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("权限分类统计:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(PermissionCategory.allCases, id: \.rawValue) { category in
                        let categoryPermissions = Permission.allCases.filter { $0.category == category }
                        let grantedCount = categoryPermissions.filter { accessControl.currentPermissions.contains($0) }.count
                        
                        HStack {
                            Circle()
                                .fill(category.color)
                                .frame(width: 12, height: 12)
                            
                            Text(category.displayName)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text("\(grantedCount)/\(categoryPermissions.count)")
                                .font(.caption)
                                .fontWeight(.medium)
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
    
    // MARK: - 审计日志部分
    
    private var auditLogSection: some View {
        Section(header: Text("审计日志")) {
            // 日志状态
            HStack {
                Image(systemName: auditLogger.isLoggingEnabled ? "doc.text.fill" : "doc.text")
                    .foregroundColor(auditLogger.isLoggingEnabled ? .green : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("审计日志")
                        .font(.body)
                    
                    Text(auditLogger.isLoggingEnabled ? "已启用" : "已禁用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { auditLogger.isLoggingEnabled },
                    set: { newValue in
                        auditLogger.setLoggingEnabled(newValue)
                    }
                ))
                .disabled(!accessControl.hasPermission(.viewAuditLogs))
            }
            
            // 查看日志按钮
            Button(action: {
                showingAuditLogs = true
            }) {
                HStack {
                    Image(systemName: "list.clipboard")
                        .foregroundColor(.blue)
                    
                    Text("查看审计日志")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(auditLogger.auditLogs.count) 条记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .disabled(!accessControl.hasPermission(.viewAuditLogs))
            
            // 日志配置
            if auditLogger.isLoggingEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("最大条目:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(auditLogger.maxLogEntries)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("保留天数:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(auditLogger.logRetentionDays) 天")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    if let lastCleanup = auditLogger.lastCleanupDate {
                        HStack {
                            Text("上次清理:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(lastCleanup, style: .date)
                                .font(.caption)
                                .fontWeight(.medium)
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
    
    // MARK: - 统计信息部分
    
    private var statisticsSection: some View {
        Section(header: Text("统计信息")) {
            let accessStats = accessControl.getAccessControlStatistics()
            let auditStats = auditLogger.getAuditStatistics()
            
            // 访问控制统计
            VStack(alignment: .leading, spacing: 8) {
                Text("访问控制统计")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("权限覆盖率:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", accessStats.permissionCoverage * 100))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("自定义角色:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(accessStats.customRoles)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("待处理请求:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(accessStats.pendingRequests)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(accessStats.pendingRequests > 0 ? .orange : .primary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            
            // 审计日志统计
            VStack(alignment: .leading, spacing: 8) {
                Text("审计日志统计")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("总记录数:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(auditStats.totalEntries)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("24小时内:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(auditStats.entriesLast24h)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("7天内:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(auditStats.entriesLast7d)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 辅助方法
    
    private func toggleAccessControl(_ enabled: Bool) {
        isProcessing = true
        
        if enabled {
            accessControl.enableAccessControl()
            alertTitle = "访问控制已启用"
            alertMessage = "访问控制系统已启用，当前角色为 \(accessControl.currentUserRole.displayName)。"
        } else {
            accessControl.disableAccessControl()
            alertTitle = "访问控制已禁用"
            alertMessage = "访问控制系统已禁用，所有功能均可访问。"
        }
        
        showingAlert = true
        isProcessing = false
    }
    
    private func resetPermissions() {
        isProcessing = true
        
        Task {
            do {
                try await accessControl.resetPermissions()
                
                alertTitle = "权限重置成功"
                alertMessage = "所有权限配置已重置为默认设置。"
                showingAlert = true
                
            } catch {
                alertTitle = "权限重置失败"
                alertMessage = error.localizedDescription
                showingAlert = true
            }
            
            isProcessing = false
        }
    }
}

// MARK: - 角色选择弹窗
struct RoleSelectionSheet: View {
    @StateObject private var accessControl = AccessControlManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRole: UserRole
    @State private var isChanging = false
    
    init() {
        _selectedRole = State(initialValue: AccessControlManager.shared.currentUserRole)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(UserRole.allCases, id: \.rawValue) { role in
                    Button(action: {
                        selectedRole = role
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(role.displayName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text("\(role.defaultPermissions.count) 个权限")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedRole == role {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("选择角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        changeRole()
                    }
                    .disabled(isChanging || selectedRole == accessControl.currentUserRole)
                }
            }
        }
    }
    
    private func changeRole() {
        isChanging = true
        
        Task {
            do {
                try await accessControl.changeUserRole(to: selectedRole)
                dismiss()
            } catch {
                print("角色更改失败: \(error)")
            }
            
            isChanging = false
        }
    }
}

// MARK: - 权限自定义弹窗
struct PermissionCustomizationSheet: View {
    @StateObject private var accessControl = AccessControlManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRole: UserRole
    @State private var customPermissions: Set<Permission>
    @State private var isSaving = false
    
    init() {
        let currentRole = AccessControlManager.shared.currentUserRole
        _selectedRole = State(initialValue: currentRole)
        _customPermissions = State(initialValue: AccessControlManager.shared.getPermissions(for: currentRole))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 角色选择器
                Picker("角色", selection: $selectedRole) {
                    ForEach(UserRole.allCases, id: \.rawValue) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedRole) { newRole in
                    customPermissions = accessControl.getPermissions(for: newRole)
                }
                
                // 权限列表
                List {
                    let permissionsByCategory = Dictionary(grouping: Permission.allCases) { $0.category }
                    
                    ForEach(PermissionCategory.allCases, id: \.rawValue) { category in
                        Section(header: Text(category.displayName)) {
                            ForEach(permissionsByCategory[category] ?? [], id: \.rawValue) { permission in
                                HStack {
                                    Image(systemName: permission.icon)
                                        .foregroundColor(category.color)
                                        .frame(width: 20)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(permission.displayName)
                                            .font(.body)
                                        
                                        if permission.requiresBiometric {
                                            Text("需要生物识别")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(3)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { customPermissions.contains(permission) },
                                        set: { isOn in
                                            if isOn {
                                                customPermissions.insert(permission)
                                            } else {
                                                customPermissions.remove(permission)
                                            }
                                        }
                                    ))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("自定义权限")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveCustomPermissions()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
    
    private func saveCustomPermissions() {
        isSaving = true
        
        Task {
            do {
                try await accessControl.customizeRolePermissions(selectedRole, permissions: customPermissions)
                dismiss()
            } catch {
                print("权限自定义失败: \(error)")
            }
            
            isSaving = false
        }
    }
}

// MARK: - 审计日志查看器弹窗
struct AuditLogViewerSheet: View {
    @StateObject private var auditLogger = AccessAuditLogger.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedEventTypes: Set<AuditEventType> = []
    @State private var selectedSeverities: Set<AuditSeverity> = []
    @State private var showingFilters = false
    @State private var showingExportOptions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 筛选器栏
                HStack {
                    Button("筛选") {
                        showingFilters.toggle()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Text("\(filteredLogs.count) 条记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("导出") {
                        showingExportOptions = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                
                // 日志列表
                List(filteredLogs) { entry in
                    AuditLogEntryRow(entry: entry)
                }
            }
            .navigationTitle("审计日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                AuditLogFiltersSheet(
                    selectedEventTypes: $selectedEventTypes,
                    selectedSeverities: $selectedSeverities
                )
            }
            .actionSheet(isPresented: $showingExportOptions) {
                ActionSheet(
                    title: Text("导出审计日志"),
                    buttons: [
                        .default(Text("导出为 JSON")) {
                            exportLogs(format: .json)
                        },
                        .default(Text("导出为 CSV")) {
                            exportLogs(format: .csv)
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
    
    private var filteredLogs: [AuditLogEntry] {
        return auditLogger.getAuditLogs(
            eventTypes: selectedEventTypes.isEmpty ? nil : selectedEventTypes,
            severities: selectedSeverities.isEmpty ? nil : selectedSeverities,
            limit: 1000
        )
    }
    
    private func exportLogs(format: ExportFormat) {
        if let url = auditLogger.exportAuditLogs(format: format) {
            // 在实际应用中，这里应该显示分享界面
            print("日志已导出到: \(url)")
        }
    }
}

// MARK: - 审计日志条目行
struct AuditLogEntryRow: View {
    let entry: AuditLogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.eventType.icon)
                    .foregroundColor(entry.severity.color)
                    .frame(width: 20)
                
                Text(entry.eventType.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let details = entry.details {
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text("角色: \(entry.userRole)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(entry.severity.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(entry.severity.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(entry.severity.color.opacity(0.1))
                    .cornerRadius(4)
                
                if !entry.success {
                    Text("失败")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 审计日志筛选器弹窗
struct AuditLogFiltersSheet: View {
    @Binding var selectedEventTypes: Set<AuditEventType>
    @Binding var selectedSeverities: Set<AuditSeverity>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("事件类型")) {
                    ForEach(AuditEventType.allCases, id: \.rawValue) { eventType in
                        HStack {
                            Image(systemName: eventType.icon)
                                .foregroundColor(eventType.severity.color)
                                .frame(width: 20)
                            
                            Text(eventType.displayName)
                                .font(.body)
                            
                            Spacer()
                            
                            if selectedEventTypes.contains(eventType) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedEventTypes.contains(eventType) {
                                selectedEventTypes.remove(eventType)
                            } else {
                                selectedEventTypes.insert(eventType)
                            }
                        }
                    }
                }
                
                Section(header: Text("严重程度")) {
                    ForEach(AuditSeverity.allCases, id: \.rawValue) { severity in
                        HStack {
                            Circle()
                                .fill(severity.color)
                                .frame(width: 12, height: 12)
                            
                            Text(severity.displayName)
                                .font(.body)
                            
                            Spacer()
                            
                            if selectedSeverities.contains(severity) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedSeverities.contains(severity) {
                                selectedSeverities.remove(severity)
                            } else {
                                selectedSeverities.insert(severity)
                            }
                        }
                    }
                }
                
                Section {
                    Button("清除所有筛选") {
                        selectedEventTypes.removeAll()
                        selectedSeverities.removeAll()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("筛选条件")
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

#Preview {
    NavigationView {
        AccessControlSettingsView()
    }
}