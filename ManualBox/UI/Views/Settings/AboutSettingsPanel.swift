import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - 关于与支持面板
struct AboutSettingsPanel: View {
    @Binding var showPrivacySheet: Bool
    @Binding var showAgreementSheet: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 页面标题
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text(NSLocalizedString("About & Support", comment: ""))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.top, 24)

                // 应用信息卡片
                SettingsCard(
                    title: "应用信息",
                    icon: "app.badge.fill",
                    iconColor: .blue,
                    description: "查看应用版本和基本信息"
                ) {
                    SettingsGroup {
                        AppInfoView()
                    }
                }

                // 法律与政策卡片
                SettingsCard(
                    title: "法律与政策",
                    icon: "doc.text.fill",
                    iconColor: .purple,
                    description: "查看隐私政策和用户协议"
                ) {
                    SettingsGroup {
                        Button { showPrivacySheet = true } label: {
                            SettingRow(
                                icon: "lock.shield.fill",
                                iconColor: .purple,
                                title: NSLocalizedString("Privacy Policy", comment: ""),
                                subtitle: NSLocalizedString("View app privacy policy", comment: ""),
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showPrivacySheet) {
                            PolicySheetView(title: NSLocalizedString("Privacy Policy", comment: ""), url: URL(string: "https://yourdomain.com/privacy")!)
                        }

                        Divider()
                            .padding(.vertical, 8)

                        Button { showAgreementSheet = true } label: {
                            SettingRow(
                                icon: "doc.text.fill",
                                iconColor: .blue,
                                title: NSLocalizedString("User Agreement", comment: ""),
                                subtitle: NSLocalizedString("View app user agreement", comment: ""),
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showAgreementSheet) {
                            PolicySheetView(title: NSLocalizedString("User Agreement", comment: ""), url: URL(string: "https://yourdomain.com/agreement")!)
                        }
                    }
                }

                // 更新与支持卡片
                SettingsCard(
                    title: "更新与支持",
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .green,
                    description: "检查更新和获取技术支持"
                ) {
                    SettingsGroup {
                        Button { checkForUpdate() } label: {
                            SettingRow(
                                icon: "arrow.triangle.2.circlepath",
                                iconColor: .green,
                                title: NSLocalizedString("Check for Updates", comment: ""),
                                subtitle: NSLocalizedString("Go to the latest version download page", comment: ""),
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

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 700, alignment: .leading)
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
    @Previewable @State var showPrivacy = false
    @Previewable @State var showAgreement = false
    
    return AboutSettingsPanel(
        showPrivacySheet: $showPrivacy,
        showAgreementSheet: $showAgreement
    )
}