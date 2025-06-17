import SwiftUI

// MARK: - 设置详情视图
struct SettingsDetailView: View {
    let selectedPanel: SettingsPanel
    @AppStorage("defaultWarrantyPeriod") private var defaultWarrantyPeriod = 12
    @AppStorage("enableOCRByDefault") private var enableOCRByDefault = true
    @State private var showPrivacySheet = false
    @State private var showAgreementSheet = false
    
    var body: some View {
        switch selectedPanel {
        case .notification:
            NotificationAdvancedSettingsPanel()
        case .theme:
            ThemeSettingsPanel()
        case .data:
            DataSettingsPanel(
                defaultWarrantyPeriod: $defaultWarrantyPeriod,
                enableOCRByDefault: $enableOCRByDefault
            )
        case .about:
            AboutSettingsPanel(
                showPrivacySheet: $showPrivacySheet,
                showAgreementSheet: $showAgreementSheet
            )
        }
    }
}

#Preview {
    SettingsDetailView(selectedPanel: .notification)
}
