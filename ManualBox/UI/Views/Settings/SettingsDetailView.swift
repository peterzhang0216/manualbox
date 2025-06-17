import SwiftUI

// MARK: - 设置详情视图
struct SettingsDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        switch viewModel.selectedPanel {
        case .notification:
            NotificationAdvancedSettingsPanel()
        case .theme:
            ThemeSettingsPanel()
        case .data:
            DataSettingsPanel(
                defaultWarrantyPeriod: Binding(
                    get: { viewModel.defaultWarrantyPeriod },
                    set: { period in
                        Task {
                            await viewModel.send(.updateDefaultWarrantyPeriod(period))
                        }
                    }
                ),
                enableOCRByDefault: Binding(
                    get: { viewModel.enableOCRByDefault },
                    set: { enabled in
                        Task {
                            await viewModel.send(.updateEnableOCRByDefault(enabled))
                        }
                    }
                )
            )
        case .about:
            AboutSettingsPanel(
                showPrivacySheet: Binding(
                    get: { viewModel.showPrivacySheet },
                    set: { show in
                        Task {
                            await viewModel.send(.togglePrivacySheet)
                        }
                    }
                ),
                showAgreementSheet: Binding(
                    get: { viewModel.showAgreementSheet },
                    set: { show in
                        Task {
                            await viewModel.send(.toggleAgreementSheet)
                        }
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
