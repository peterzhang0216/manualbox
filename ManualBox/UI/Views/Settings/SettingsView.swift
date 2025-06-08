import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import CoreData

// MARK: - 设置视图
struct SettingsView: View {
    @AppStorage("defaultWarrantyPeriod") private var defaultWarrantyPeriod = 12
    @AppStorage("enableOCRByDefault") private var enableOCRByDefault = true
    @EnvironmentObject private var notificationManager: AppNotificationManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showResetAlert = false
    @State private var showPrivacySheet = false
    @State private var showAgreementSheet = false
    @State private var selectedPanel: SettingsPanel = .notification
    
    enum SettingsPanel: Hashable {
        case notification
        case theme
        case data
        case about
    }
    
    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $selectedPanel) {
                Section(header: Text("设置")) {
                    NavigationLink(value: SettingsPanel.notification) {
                        Label("通知与提醒", systemImage: "bell.badge.fill")
                    }
                    NavigationLink(value: SettingsPanel.theme) {
                        Label("外观与主题", systemImage: "paintbrush")
                    }
                    NavigationLink(value: SettingsPanel.data) {
                        Label("数据与默认", systemImage: "tray.full")
                    }
                    NavigationLink(value: SettingsPanel.about) {
                        Label("关于与支持", systemImage: "info.circle")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置")
        } detail: {
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
        #else
        NavigationStack {
            List {
                Section(header: Text("设置")) {
                    NavigationLink(destination: NotificationAdvancedSettingsPanel()) {
                        SettingRow(
                            icon: "bell.badge.fill",
                            iconColor: .orange,
                            title: "通知与提醒",
                            subtitle: "管理通知偏好设置"
                        )
                    }
                    NavigationLink(destination: ThemeSettingsPanel()) {
                        SettingRow(
                            icon: "paintbrush",
                            iconColor: .purple,
                            title: "外观与主题",
                            subtitle: "自定义应用外观"
                        )
                    }
                    NavigationLink(destination: DataSettingsPanel(
                        defaultWarrantyPeriod: $defaultWarrantyPeriod,
                        enableOCRByDefault: $enableOCRByDefault
                    )) {
                        SettingRow(
                            icon: "tray.full",
                            iconColor: .blue,
                            title: "数据与默认",
                            subtitle: "管理应用数据和默认设置"
                        )
                    }
                    NavigationLink(destination: AboutSettingsPanel(
                        showPrivacySheet: $showPrivacySheet,
                        showAgreementSheet: $showAgreementSheet
                    )) {
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
}
