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
                Text(NSLocalizedString("About & Support", comment: ""))
                    .font(.title2).bold()
                    .padding(.top, 24)
                    .foregroundColor(.accentColor)
                
                Divider().background(Color.accentColor.opacity(0.3))
                
                // 应用信息卡片
                VStack(alignment: .leading, spacing: 16) {
                    AppInfoView()
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 法律与政策卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Legal & Policies", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    Button { showPrivacySheet = true } label: {
                        SettingRow(
                            icon: "lock.shield.fill",
                            iconColor: .purple,
                            title: NSLocalizedString("Privacy Policy", comment: ""),
                            subtitle: NSLocalizedString("View app privacy policy", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showPrivacySheet) {
                        PolicySheetView(title: NSLocalizedString("Privacy Policy", comment: ""), url: URL(string: "https://yourdomain.com/privacy")!)
                    }
                    
                    Button { showAgreementSheet = true } label: {
                        SettingRow(
                            icon: "doc.text.fill",
                            iconColor: .blue,
                            title: NSLocalizedString("User Agreement", comment: ""),
                            subtitle: NSLocalizedString("View app user agreement", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showAgreementSheet) {
                        PolicySheetView(title: NSLocalizedString("User Agreement", comment: ""), url: URL(string: "https://yourdomain.com/agreement")!)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 更新与支持卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Text(NSLocalizedString("Updates & Support", comment: ""))
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    Button { checkForUpdate() } label: {
                        SettingRow(
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: .green,
                            title: NSLocalizedString("Check for Updates", comment: ""),
                            subtitle: NSLocalizedString("Go to the latest version download page", comment: "")
                        )
                    }
                    .buttonStyle(.plain)
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