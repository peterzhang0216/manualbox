import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - 增强的iOS设置视图
struct EnhancediOSSettingsView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            List {
                // 通知与提醒分组
                Section {
                    NavigationLink(destination: NotificationCategoryView()
                        .environmentObject(viewModel)
                    ) {
                        SettingRow(
                            icon: "bell.badge.fill",
                            iconColor: .orange,
                            title: "通知与提醒",
                            subtitle: "管理通知偏好设置"
                        )
                    }
                } header: {
                    Text("通知")
                } footer: {
                    Text("管理应用通知权限、提醒时间和免打扰设置")
                }
                
                // 外观与主题分组
                Section {
                    NavigationLink(destination: ThemeCategoryView()
                        .environmentObject(viewModel)
                    ) {
                        SettingRow(
                            icon: "paintbrush.fill",
                            iconColor: .purple,
                            title: "外观与主题",
                            subtitle: "自定义应用外观"
                        )
                    }
                } header: {
                    Text("外观")
                } footer: {
                    Text("设置主题模式、颜色方案和显示选项")
                }
                
                // 数据与默认设置分组
                Section {
                    NavigationLink(destination: DataCategoryView()
                        .environmentObject(viewModel)
                    ) {
                        SettingRow(
                            icon: "tray.full.fill",
                            iconColor: .blue,
                            title: "数据与默认",
                            subtitle: "管理应用数据和默认设置"
                        )
                    }
                } header: {
                    Text("数据")
                } footer: {
                    Text("设置默认参数、管理数据和进行备份操作")
                }
                
                // 关于与支持分组
                Section {
                    NavigationLink(destination: AboutCategoryView()
                        .environmentObject(viewModel)
                    ) {
                        SettingRow(
                            icon: "info.circle.fill",
                            iconColor: .green,
                            title: "关于与支持",
                            subtitle: "应用信息和支持"
                        )
                    }
                } header: {
                    Text("关于")
                } footer: {
                    Text("查看应用信息、语言设置和法律文档")
                }
            }
            .navigationTitle("设置")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

// MARK: - 通知分类视图
struct NotificationCategoryView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        List {
            Section {
                NavigationLink(destination: NotificationPermissionsDetailView()
                    .environmentObject(viewModel)
                ) {
                    SettingRow(
                        icon: "bell.circle.fill",
                        iconColor: .orange,
                        title: "通知权限",
                        subtitle: "管理应用通知权限"
                    )
                }
                
                NavigationLink(destination: NotificationScheduleDetailView()
                    .environmentObject(viewModel)
                ) {
                    SettingRow(
                        icon: "clock.fill",
                        iconColor: .blue,
                        title: "提醒时间",
                        subtitle: "设置默认提醒时间"
                    )
                }

                NavigationLink(destination: CustomNotificationTimeView()) {
                    SettingRow(
                        icon: "clock.badge.checkmark",
                        iconColor: .cyan,
                        title: "自定义时间",
                        subtitle: "为不同分类设置专属时间"
                    )
                }
                
                NavigationLink(destination: SilentPeriodDetailView()
                    .environmentObject(viewModel)
                ) {
                    SettingRow(
                        icon: "moon.fill",
                        iconColor: .purple,
                        title: "免打扰时段",
                        subtitle: "设置静音时间段"
                    )
                }

                NavigationLink(destination: NotificationHistoryDetailView()) {
                    SettingRow(
                        icon: "clock.arrow.circlepath",
                        iconColor: .green,
                        title: "通知历史",
                        subtitle: "查看历史通知记录"
                    )
                }

                NavigationLink(destination: NotificationCategoryManagementView()) {
                    SettingRow(
                        icon: "folder.badge.gearshape",
                        iconColor: .purple,
                        title: "通知分类",
                        subtitle: "管理通知分类设置"
                    )
                }

                NavigationLink(destination: BatchNotificationOperationsView()) {
                    SettingRow(
                        icon: "checkmark.circle.badge.xmark",
                        iconColor: .red,
                        title: "批量操作",
                        subtitle: "批量管理通知记录"
                    )
                }

                NavigationLink(destination: NotificationStatisticsView()) {
                    SettingRow(
                        icon: "chart.bar.fill",
                        iconColor: .indigo,
                        title: "通知统计",
                        subtitle: "查看通知数据分析"
                    )
                }
            } header: {
                Text("通知设置")
            } footer: {
                Text("配置通知权限、提醒时间和免打扰时段")
            }
        }
        .navigationTitle("通知与提醒")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - 主题分类视图
struct ThemeCategoryView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        List {
            Section {
                NavigationLink(destination: ThemeModeDetailView()) {
                    SettingRow(
                        icon: "circle.lefthalf.filled",
                        iconColor: .primary,
                        title: "主题模式",
                        subtitle: "选择浅色或深色主题"
                    )
                }
                
                NavigationLink(destination: DisplaySettingsDetailView()) {
                    SettingRow(
                        icon: "display",
                        iconColor: .blue,
                        title: "显示设置",
                        subtitle: "调整显示选项"
                    )
                }
            } header: {
                Text("外观设置")
            } footer: {
                Text("自定义应用的外观和显示效果")
            }
        }
        .navigationTitle("外观与主题")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - 数据分类视图
struct DataCategoryView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        List {
            Section {
                NavigationLink(destination: DefaultSettingsDetailView()
                    .environmentObject(viewModel)
                ) {
                    SettingRow(
                        icon: "gear.circle.fill",
                        iconColor: .blue,
                        title: "默认设置",
                        subtitle: "配置默认参数"
                    )
                }
                
                NavigationLink(destination: DataManagementDetailView()
                    .environmentObject(viewModel)
                ) {
                    SettingRow(
                        icon: "externaldrive.fill",
                        iconColor: .green,
                        title: "数据管理",
                        subtitle: "导入导出和备份"
                    )
                }
                
                NavigationLink(destination: DangerousOperationsDetailView()
                    .environmentObject(viewModel)
                ) {
                    SettingRow(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .red,
                        title: "危险操作",
                        subtitle: "重置和清除数据",
                        warning: true
                    )
                }
            } header: {
                Text("数据设置")
            } footer: {
                Text("管理应用数据、设置默认值和进行维护操作")
            }
        }
        .navigationTitle("数据与默认")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - 关于分类视图
struct AboutCategoryView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        List {
            Section {
                NavigationLink(destination: AppInfoDetailView()) {
                    SettingRow(
                        icon: "app.badge.fill",
                        iconColor: .blue,
                        title: "应用信息",
                        subtitle: "查看版本和详细信息"
                    )
                }
                
                NavigationLink(destination: LanguageSettingsDetailView()) {
                    SettingRow(
                        icon: "globe",
                        iconColor: .green,
                        title: "语言设置",
                        subtitle: "选择显示语言"
                    )
                }
                
                NavigationLink(destination: LegalPoliciesDetailView()
                    .environmentObject(viewModel)
                ) {
                    SettingRow(
                        icon: "doc.text.fill",
                        iconColor: .orange,
                        title: "法律与政策",
                        subtitle: "隐私政策和用户协议"
                    )
                }
                
                NavigationLink(destination: UpdateSupportDetailView()) {
                    SettingRow(
                        icon: "questionmark.circle.fill",
                        iconColor: .purple,
                        title: "更新与支持",
                        subtitle: "获取帮助和支持"
                    )
                }
            } header: {
                Text("关于设置")
            } footer: {
                Text("查看应用信息、管理语言和获取支持")
            }
        }
        .navigationTitle("关于与支持")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        EnhancediOSSettingsView()
            .environmentObject(SettingsViewModel(viewContext: PersistenceController.preview.container.viewContext))
    }
}
