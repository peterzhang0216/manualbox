import SwiftUI

/// 设置面板总结视图，用于在右侧栏显示当前设置的概览和快速操作
struct SettingsSummaryView: View {
    let panel: SettingsPanel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 面板标题
            HStack {
                Image(systemName: panel.icon)
                    .font(.title2)
                    .foregroundColor(panel.color)
                Text(panel.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            // 面板内容
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch panel {
                    case .notification:
                        notificationSummary()
                    case .appearance:
                        themeSummary()
                    case .appSettings:
                        appSettingsSummary()
                    case .dataManagement:
                        dataSummary()
                    case .about:
                        aboutSummary()
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }
    
    // MARK: - 通知设置总结
    @ViewBuilder
    private func notificationSummary() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("通知设置概览")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 当前状态卡片
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                    Text("通知状态")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(settingsViewModel.enableNotifications ? "已启用" : "已禁用")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(settingsViewModel.enableNotifications ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundColor(settingsViewModel.enableNotifications ? .green : .red)
                        .clipShape(Capsule())
                }
                
                if settingsViewModel.enableNotifications {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("默认时间")
                            .font(.subheadline)
                        Spacer()
                        Text(settingsViewModel.notificationTime, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.purple)
                    Text("免打扰")
                        .font(.subheadline)
                    Spacer()
                    Text(settingsViewModel.enableSilentPeriod ? "已启用" : "已禁用")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(settingsViewModel.enableSilentPeriod ? Color.purple.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundColor(settingsViewModel.enableSilentPeriod ? .purple : .gray)
                        .clipShape(Capsule())
                }
                
                if settingsViewModel.enableSilentPeriod {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("免打扰时段:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Date(timeIntervalSince1970: settingsViewModel.silentStartTime), style: .time) - \(Date(timeIntervalSince1970: settingsViewModel.silentEndTime), style: .time)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 快速操作
            Text("快速操作")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                Button {
                    Task {
                        await settingsViewModel.send(.updateEnableNotifications(!settingsViewModel.enableNotifications))
                    }
                } label: {
                    HStack {
                        Image(systemName: settingsViewModel.enableNotifications ? "bell.slash.fill" : "bell.fill")
                            .foregroundColor(.orange)
                        Text(settingsViewModel.enableNotifications ? "禁用通知" : "启用通知")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                Button {
                    Task {
                        await settingsViewModel.send(.updateSilentPeriod(!settingsViewModel.enableSilentPeriod))
                    }
                } label: {
                    HStack {
                        Image(systemName: settingsViewModel.enableSilentPeriod ? "moon.slash.fill" : "moon.fill")
                            .foregroundColor(.purple)
                        Text(settingsViewModel.enableSilentPeriod ? "禁用免打扰" : "启用免打扰")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - 主题设置总结
    @ViewBuilder
    private func themeSummary() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("外观设置概览")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 当前主题状态
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundColor(.blue)
                    Text("主题模式")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("跟随系统")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .foregroundColor(.purple)
                    Text("主题色彩")
                        .font(.subheadline)
                    Spacer()
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 16, height: 16)
                }
                
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.green)
                    Text("语言")
                        .font(.subheadline)
                    Spacer()
                    Text("简体中文")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 预览区域
            Text("主题预览")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Text("示例文本")
                        .font(.subheadline)
                    Spacer()
                    Button("按钮") { }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                
                HStack {
                    Text("次要文本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Toggle("", isOn: .constant(true))
                        .labelsHidden()
                        .controlSize(.mini)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - 应用设置总结
    @ViewBuilder
    private func appSettingsSummary() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("应用设置概览")
                .font(.headline)
                .foregroundColor(.primary)

            // 默认参数状态
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                    Text("默认保修期")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(settingsViewModel.defaultWarrantyPeriod) 个月")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "doc.text.viewfinder")
                        .foregroundColor(.purple)
                    Text("OCR 识别")
                        .font(.subheadline)
                    Spacer()
                    Text(settingsViewModel.enableOCRByDefault ? "默认启用" : "默认禁用")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(settingsViewModel.enableOCRByDefault ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundColor(settingsViewModel.enableOCRByDefault ? .green : .gray)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 快速操作
            Text("快速操作")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                Button {
                    Task {
                        await settingsViewModel.send(.updateEnableOCRByDefault(!settingsViewModel.enableOCRByDefault))
                    }
                } label: {
                    HStack {
                        Image(systemName: settingsViewModel.enableOCRByDefault ? "doc.text.viewfinder.slash" : "doc.text.viewfinder")
                            .foregroundColor(.purple)
                        Text(settingsViewModel.enableOCRByDefault ? "禁用OCR" : "启用OCR")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 数据设置总结
    @ViewBuilder
    private func dataSummary() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("数据设置概览")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 默认设置状态
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                    Text("默认保修期")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(settingsViewModel.defaultWarrantyPeriod) 个月")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "doc.text.viewfinder")
                        .foregroundColor(.green)
                    Text("OCR 识别")
                        .font(.subheadline)
                    Spacer()
                    Text(settingsViewModel.enableOCRByDefault ? "默认启用" : "默认禁用")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(settingsViewModel.enableOCRByDefault ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundColor(settingsViewModel.enableOCRByDefault ? .green : .gray)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 数据统计（模拟数据）
            Text("数据统计")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("产品数量")
                        .font(.subheadline)
                    Spacer()
                    Text("42")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("分类数量")
                        .font(.subheadline)
                    Spacer()
                    Text("8")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("标签数量")
                        .font(.subheadline)
                    Spacer()
                    Text("12")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - 关于设置总结
    @ViewBuilder
    private func aboutSummary() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("应用信息")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 应用基本信息
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "app.badge.fill")
                        .foregroundColor(.blue)
                    Text("ManualBox")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(.orange)
                    Text("构建版本")
                        .font(.subheadline)
                    Spacer()
                    Text("2024.1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.green)
                    Text("发布日期")
                        .font(.subheadline)
                    Spacer()
                    Text("2024-01-01")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 快速链接
            Text("快速链接")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                Button {
                    // 检查更新
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.green)
                        Text("检查更新")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                Button {
                    // 技术支持
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("技术支持")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}



#Preview {
    SettingsSummaryView(panel: .notification)
        .environmentObject(SettingsViewModel(viewContext: PersistenceController.preview.container.viewContext))
        .frame(width: 300)
}
