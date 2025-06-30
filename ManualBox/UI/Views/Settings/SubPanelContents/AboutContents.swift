import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - 应用信息内容（旧版本）
struct LegacyAppInfoContent: View {
    var body: some View {
        SettingsCard(
            title: "应用详细信息",
            icon: "app.badge.fill",
            iconColor: .blue,
            description: "查看应用版本和基本信息"
        ) {
            SettingsGroup {
                AppInfoView()
            }
        }
    }
}

// MARK: - 语言设置内容（旧版本）
struct LegacyLanguageSettingsContent: View {
    var body: some View {
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
    }
}

// MARK: - 法律与政策内容
struct LegalPoliciesContent: View {
    @Binding var showPrivacySheet: Bool
    @Binding var showAgreementSheet: Bool
    
    var body: some View {
        SettingsCard(
            title: "法律文档",
            icon: "doc.text.fill",
            iconColor: .purple,
            description: "查看隐私政策和用户协议"
        ) {
            SettingsGroup {
                Button { showPrivacySheet = true } label: {
                    SettingRow(
                        icon: "lock.shield.fill",
                        iconColor: .purple,
                        title: "隐私政策",
                        subtitle: "查看应用隐私政策",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showPrivacySheet) {
                    PolicySheetView(title: "隐私政策", url: URL(string: "https://yourdomain.com/privacy")!)
                }

                Divider()
                    .padding(.vertical, 8)

                Button { showAgreementSheet = true } label: {
                    SettingRow(
                        icon: "doc.text.fill",
                        iconColor: .blue,
                        title: "用户协议",
                        subtitle: "查看应用用户协议",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showAgreementSheet) {
                    PolicySheetView(title: "用户协议", url: URL(string: "https://yourdomain.com/agreement")!)
                }
            }
        }
    }
}

// MARK: - 更新与支持内容
struct UpdateSupportContent: View {
    var body: some View {
        SettingsCard(
            title: "更新与帮助",
            icon: "arrow.triangle.2.circlepath",
            iconColor: .green,
            description: "检查更新和获取技术支持"
        ) {
            SettingsGroup {
                Button { checkForUpdate() } label: {
                    SettingRow(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .green,
                        title: "检查更新",
                        subtitle: "前往最新版本下载页面",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.vertical, 8)

                Button {
                    // 打开技术支持页面
                    #if os(macOS)
                    if let url = URL(string: "mailto:support@yourdomain.com") {
                        NSWorkspace.shared.open(url)
                    }
                    #else
                    if let url = URL(string: "mailto:support@yourdomain.com") {
                        UIApplication.shared.open(url)
                    }
                    #endif
                } label: {
                    SettingRow(
                        icon: "questionmark.circle.fill",
                        iconColor: .orange,
                        title: "技术支持",
                        subtitle: "联系我们获取帮助和支持",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.vertical, 8)

                Button {
                    // 打开反馈页面
                    #if os(macOS)
                    if let url = URL(string: "https://github.com/yourusername/ManualBox/issues") {
                        NSWorkspace.shared.open(url)
                    }
                    #else
                    if let url = URL(string: "https://github.com/yourusername/ManualBox/issues") {
                        UIApplication.shared.open(url)
                    }
                    #endif
                } label: {
                    SettingRow(
                        icon: "exclamationmark.bubble.fill",
                        iconColor: .red,
                        title: "问题反馈",
                        subtitle: "报告问题或提出改进建议",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private func checkForUpdate() {
    #if os(macOS)
    if let url = URL(string: "https://github.com/yourusername/ManualBox/releases") {
        NSWorkspace.shared.open(url)
    }
    #else
    if let url = URL(string: "https://github.com/yourusername/ManualBox/releases") {
        UIApplication.shared.open(url)
    }
    #endif
}

#Preview {
    VStack(spacing: 20) {
        LegacyAppInfoContent()
        LegacyLanguageSettingsContent()
        LegalPoliciesContent(
            showPrivacySheet: .constant(false),
            showAgreementSheet: .constant(false)
        )
        UpdateSupportContent()
    }
    .environmentObject(SettingsManager.shared)
    .padding()
}
