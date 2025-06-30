import SwiftUI

// MARK: - 默认设置详细视图
struct DefaultSettingsDetailView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 默认保修期设置
                SettingsCard(
                    title: "默认保修期",
                    icon: "calendar.circle.fill",
                    iconColor: .blue,
                    description: "设置新产品的默认保修期长度"
                ) {
                    SettingsGroup {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 28, height: 28)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("保修期长度")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("新产品的默认保修期")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Stepper(
                                value: Binding(
                                    get: { viewModel.defaultWarrantyPeriod },
                                    set: { period in
                                        viewModel.send(.updateDefaultWarrantyPeriod(period))
                                    }
                                ),
                                in: 1...60
                            ) {
                                Text("\(viewModel.defaultWarrantyPeriod)个月")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // OCR识别设置
                SettingsCard(
                    title: "OCR文字识别",
                    icon: "doc.text.viewfinder",
                    iconColor: .green,
                    description: "控制是否默认启用OCR文字识别功能"
                ) {
                    SettingsGroup {
                        SettingsToggle(
                            title: "默认启用OCR",
                            description: "新产品默认开启文字识别功能",
                            icon: "doc.text.viewfinder",
                            iconColor: .green,
                            isOn: Binding(
                                get: { viewModel.enableOCRByDefault },
                                set: { enabled in
                                    viewModel.send(.updateEnableOCRByDefault(enabled))
                                }
                            )
                        )
                        
                        if viewModel.enableOCRByDefault {
                            Divider()
                                .padding(.vertical, 8)
                            
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                
                                Text("启用后，添加产品时会自动尝试识别图片中的文字信息。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // 快速设置预览
                SettingsCard(
                    title: "当前设置预览",
                    icon: "eye.fill",
                    iconColor: .purple,
                    description: "查看当前的默认设置"
                ) {
                    SettingsGroup {
                        VStack(spacing: 12) {
                            SettingPreviewRow(
                                icon: "calendar.badge.clock",
                                title: "默认保修期",
                                value: "\(viewModel.defaultWarrantyPeriod)个月",
                                color: .blue
                            )
                            
                            Divider()
                            
                            SettingPreviewRow(
                                icon: "doc.text.viewfinder",
                                title: "OCR识别",
                                value: viewModel.enableOCRByDefault ? "默认启用" : "默认关闭",
                                color: viewModel.enableOCRByDefault ? .green : .gray
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("默认设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - 数据管理详细视图
struct DataManagementDetailView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 数据导出
                SettingsCard(
                    title: "数据导出",
                    icon: "square.and.arrow.up.fill",
                    iconColor: .blue,
                    description: "将应用数据导出为文件"
                ) {
                    SettingsGroup {
                        Button(action: {
                            showingExportSheet = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("导出数据")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("将所有数据导出为JSON文件")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // 数据导入
                SettingsCard(
                    title: "数据导入",
                    icon: "square.and.arrow.down.fill",
                    iconColor: .green,
                    description: "从文件导入数据到应用"
                ) {
                    SettingsGroup {
                        Button(action: {
                            showingImportSheet = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("导入数据")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("从JSON文件导入数据")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // 数据备份
                SettingsCard(
                    title: "自动备份",
                    icon: "externaldrive.fill",
                    iconColor: .orange,
                    description: "配置自动备份设置"
                ) {
                    SettingsGroup {
                        VStack(spacing: 12) {
                            InfoRow(label: "iCloud同步", value: "数据会自动同步到您的iCloud账户")
                            
                            Divider()
                            
                            InfoRow(label: "数据安全", value: "所有数据都经过加密保护")
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("数据管理")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingExportSheet) {
            DataExportView()
        }
        .sheet(isPresented: $showingImportSheet) {
            DataImportView()
        }
    }
}

// MARK: - 危险操作详细视图
struct DangerousOperationsDetailView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    @State private var showingResetAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 警告信息
                SettingsCard(
                    title: "重要提醒",
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .red,
                    description: "以下操作具有风险，请谨慎操作"
                ) {
                    SettingsGroup {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                            
                            Text("这些操作可能会导致数据丢失，请在操作前确保已备份重要数据。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 重置所有数据
                SettingsCard(
                    title: "重置所有数据",
                    icon: "trash.circle.fill",
                    iconColor: .red,
                    description: "清除所有应用数据并恢复默认设置"
                ) {
                    SettingsGroup {
                        Button(action: {
                            showingResetAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash.circle.fill")
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("重置所有数据")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.red)
                                    Text("此操作不可恢复")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("危险操作")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("重置所有数据", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                viewModel.send(.resetAllData)
            }
        } message: {
            Text("此操作将删除所有产品、分类、标签和设置数据，且无法恢复。确定要继续吗？")
        }
    }
}

// MARK: - 设置预览行组件
struct SettingPreviewRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        DefaultSettingsDetailView()
            .environmentObject(SettingsViewModel(viewContext: PersistenceController.preview.container.viewContext))
    }
}
