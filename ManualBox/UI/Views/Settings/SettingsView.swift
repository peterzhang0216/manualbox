import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import CoreData

// MARK: - 设置视图
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject private var notificationManager: AppNotificationManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    init() {
        let context = PersistenceController.shared.container.viewContext
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(viewContext: context))
    }
    

    
    var body: some View {
        #if os(macOS)
        // 使用新的三栏布局
        ThreeColumnSettingsView()
        #else
        // iOS 保持原有的导航栈布局
        NavigationStack {
            List {
                Section(header: Text("设置")) {
                    NavigationLink(destination: NotificationAdvancedSettingsPanel()
                        .environmentObject(viewModel)
                    ) {
                        SettingRow(
                            icon: "bell.badge.fill",
                            iconColor: .orange,
                            title: "通知与提醒",
                            subtitle: "管理通知偏好设置"
                        )
                    }
                    NavigationLink(destination: ThemeSettingsPanel()
                        .environmentObject(viewModel)
                    ) {
                        SettingRow(
                            icon: "paintbrush",
                            iconColor: .purple,
                            title: "外观与主题",
                            subtitle: "自定义应用外观"
                        )
                    }
                    NavigationLink(destination: DataSettingsPanel(
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
                        .environmentObject(viewModel)
                    ) {
                        SettingRow(
                            icon: "tray.full",
                            iconColor: .blue,
                            title: "数据与默认",
                            subtitle: "管理应用数据和默认设置"
                        )
                    }
                    NavigationLink(destination: AboutSettingsPanel(
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
                        .environmentObject(viewModel)
                    ) {
                        SettingRow(
                            icon: "info.circle",
                            iconColor: .green,
                            title: "关于与支持",
                            subtitle: "应用信息和支持"
                        )
                    }
                }
            }
            .navigationTitle("设置")
        }
        #endif
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppNotificationManager())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
