import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - 应用信息详细视图
struct AppInfoDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 应用基本信息
                SettingsCard(
                    title: "应用信息",
                    icon: "app.badge.fill",
                    iconColor: .blue,
                    description: "查看应用的基本信息和版本"
                ) {
                    SettingsGroup {
                        AppInfoView()
                    }
                }
                
                // 系统信息
                SettingsCard(
                    title: "系统信息",
                    icon: "gear.circle.fill",
                    iconColor: .gray,
                    description: "查看设备和系统信息"
                ) {
                    SettingsGroup {
                        VStack(spacing: 12) {
                            InfoDetailRow(
                                title: "设备型号",
                                value: deviceModel
                            )
                            
                            Divider()
                            
                            InfoDetailRow(
                                title: "系统版本",
                                value: systemVersion
                            )
                            
                            Divider()
                            
                            InfoDetailRow(
                                title: "应用版本",
                                value: appVersion
                            )
                            
                            Divider()
                            
                            InfoDetailRow(
                                title: "构建版本",
                                value: buildVersion
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("应用信息")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private var deviceModel: String {
        #if os(iOS)
        return UIDevice.current.model
        #else
        return "Mac"
        #endif
    }
    
    private var systemVersion: String {
        #if os(iOS)
        return "iOS \(UIDevice.current.systemVersion)"
        #else
        return "macOS"
        #endif
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
    }
    
    private var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知"
    }
}

// MARK: - 语言设置详细视图
struct LanguageSettingsDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 语言选择
                SettingsCard(
                    title: "显示语言",
                    icon: "globe",
                    iconColor: .green,
                    description: "选择应用的显示语言"
                ) {
                    SettingsGroup {
                        CompactLanguagePickerView()
                    }
                }
                
                // 语言说明
                SettingsCard(
                    title: "语言说明",
                    icon: "info.circle.fill",
                    iconColor: .blue,
                    description: "了解语言设置的相关信息"
                ) {
                    SettingsGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: "多语言支持", value: "应用支持中文和英文两种语言")
                            
                            Divider()
                            
                            InfoRow(label: "即时生效", value: "语言更改会立即在应用中生效")
                            
                            Divider()
                            
                            InfoRow(label: "系统设置", value: "也可以在系统设置中更改应用语言")
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("语言设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - 法律与政策详细视图
struct LegalPoliciesDetailView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 隐私政策
                SettingsCard(
                    title: "隐私政策",
                    icon: "hand.raised.fill",
                    iconColor: .blue,
                    description: "了解我们如何保护您的隐私"
                ) {
                    SettingsGroup {
                        Button(action: {
                            viewModel.send(.togglePrivacySheet)
                        }) {
                            HStack {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("查看隐私政策")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("了解数据收集和使用政策")
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
                
                // 用户协议
                SettingsCard(
                    title: "用户协议",
                    icon: "doc.text.fill",
                    iconColor: .orange,
                    description: "查看使用条款和服务协议"
                ) {
                    SettingsGroup {
                        Button(action: {
                            viewModel.send(.toggleAgreementSheet)
                        }) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("查看用户协议")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("了解使用条款和服务协议")
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
                
                // 开源许可
                SettingsCard(
                    title: "开源许可",
                    icon: "heart.fill",
                    iconColor: .red,
                    description: "查看使用的开源组件许可信息"
                ) {
                    SettingsGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: "SwiftUI", value: "Apple的现代UI框架")
                            
                            Divider()
                            
                            InfoRow(label: "Core Data", value: "Apple的数据持久化框架")
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("法律与政策")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - 更新与支持详细视图
struct UpdateSupportDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 获取帮助
                SettingsCard(
                    title: "获取帮助",
                    icon: "questionmark.circle.fill",
                    iconColor: .blue,
                    description: "寻找问题解答和使用指南"
                ) {
                    SettingsGroup {
                        VStack(spacing: 12) {
                            SupportOptionRow(
                                icon: "book.fill",
                                title: "使用指南",
                                description: "查看详细的使用说明",
                                action: {
                                    // 打开使用指南
                                }
                            )
                            
                            Divider()
                            
                            SupportOptionRow(
                                icon: "questionmark.bubble.fill",
                                title: "常见问题",
                                description: "查看常见问题解答",
                                action: {
                                    // 打开FAQ
                                }
                            )
                        }
                    }
                }
                
                // 反馈与建议
                SettingsCard(
                    title: "反馈与建议",
                    icon: "envelope.fill",
                    iconColor: .green,
                    description: "向我们发送反馈和建议"
                ) {
                    SettingsGroup {
                        VStack(spacing: 12) {
                            SupportOptionRow(
                                icon: "envelope.fill",
                                title: "发送反馈",
                                description: "报告问题或提出建议",
                                action: {
                                    sendFeedback()
                                }
                            )
                            
                            Divider()
                            
                            SupportOptionRow(
                                icon: "star.fill",
                                title: "应用评分",
                                description: "在App Store中为应用评分",
                                action: {
                                    rateApp()
                                }
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("更新与支持")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func sendFeedback() {
        #if os(iOS)
        if let url = URL(string: "mailto:support@example.com?subject=ManualBox反馈") {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    private func rateApp() {
        #if os(iOS)
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id123456789") {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - 信息详情行组件
struct InfoDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
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

// MARK: - 支持选项行组件
struct SupportOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Text(description)
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

// MARK: - InfoRow 组件
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        AppInfoDetailView()
    }
}
