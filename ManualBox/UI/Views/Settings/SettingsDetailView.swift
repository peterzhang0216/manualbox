import SwiftUI

// MARK: - 设置详情视图
struct SettingsDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        switch viewModel.selectedPanel {
        case .notification:
            NotificationAdvancedSettingsPanel()
        case .appearance:
            ThemeSettingsPanel()
        case .appSettings:
            DataSettingsPanel(
                defaultWarrantyPeriod: Binding(
                    get: { viewModel.defaultWarrantyPeriod },
                    set: { period in
                        // 直接同步更新，避免异步延迟
                        viewModel.updateDefaultWarrantyPeriodSync(period)
                    }
                ),
                enableOCRByDefault: Binding(
                    get: { viewModel.enableOCRByDefault },
                    set: { enabled in
                        // 直接同步更新，避免异步延迟
                        viewModel.updateEnableOCRByDefaultSync(enabled)
                    }
                )
            )
        case .dataManagement:
            DataSettingsPanel(
                defaultWarrantyPeriod: Binding(
                    get: { viewModel.defaultWarrantyPeriod },
                    set: { period in
                        // 直接同步更新，避免异步延迟
                        viewModel.updateDefaultWarrantyPeriodSync(period)
                    }
                ),
                enableOCRByDefault: Binding(
                    get: { viewModel.enableOCRByDefault },
                    set: { enabled in
                        // 直接同步更新，避免异步延迟
                        viewModel.updateEnableOCRByDefaultSync(enabled)
                    }
                )
            )
        case .about:
            AboutSettingsPanel(
                showPrivacySheet: Binding(
                    get: { viewModel.showPrivacySheet },
                    set: { show in
                        // 直接同步更新，避免异步延迟
                        viewModel.togglePrivacySheetSync()
                    }
                ),
                showAgreementSheet: Binding(
                    get: { viewModel.showAgreementSheet },
                    set: { show in
                        // 直接同步更新，避免异步延迟
                        viewModel.toggleAgreementSheetSync()
                    }
                )
            )
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let viewModel = SettingsViewModel(viewContext: context)
    return SettingsDetailView(viewModel: viewModel)
}
