import SwiftUI
import CoreData

// MARK: - 三栏设置视图
struct ThreeColumnSettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @State private var selectedPanel: SettingsPanel = .notification
    @State private var selectedSubPanel: SettingsSubPanel? = nil
    @Environment(\.managedObjectContext) private var viewContext
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(viewContext: context))
    }
    
    var body: some View {
        NavigationSplitView {
            // 第一栏：主要分类
            List(selection: $selectedPanel) {
                Section("设置") {
                    ForEach(SettingsPanel.allCases, id: \.self) { panel in
                        NavigationLink(value: panel) {
                            Label(panel.title, systemImage: panel.icon)
                                .foregroundColor(panel.color)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置")
        } content: {
            // 第二栏：子分类
            List(selection: $selectedSubPanel) {
                Section(selectedPanel.title) {
                    ForEach(subPanelsForCurrentPanel, id: \.self) { subPanel in
                        NavigationLink(value: subPanel) {
                            Label(subPanel.title, systemImage: subPanel.icon)
                                .foregroundColor(subPanel.color)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(selectedPanel.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        } detail: {
            // 第三栏：详细内容
            Group {
                if let subPanel = selectedSubPanel {
                    subPanelDetailView(for: subPanel)
                } else {
                    // 默认显示面板概览
                    panelOverviewView(for: selectedPanel)
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .onChange(of: selectedPanel) { _, newPanel in
            // 当主面板改变时，自动选择第一个子面板
            selectedSubPanel = subPanelsForPanel(newPanel).first
        }
        .onAppear {
            // 初始化时选择第一个子面板
            selectedSubPanel = subPanelsForCurrentPanel.first
        }
    }
    
    // MARK: - 计算属性
    private var subPanelsForCurrentPanel: [SettingsSubPanel] {
        subPanelsForPanel(selectedPanel)
    }
    
    private func subPanelsForPanel(_ panel: SettingsPanel) -> [SettingsSubPanel] {
        SettingsSubPanel.allCases.filter { $0.parentPanel == panel }
    }
    
    // MARK: - 视图构建器
    @ViewBuilder
    private func panelOverviewView(for panel: SettingsPanel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 面板标题
                HStack {
                    Image(systemName: panel.icon)
                        .font(.title2)
                        .foregroundColor(panel.color)
                    Text(panel.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.top, 24)
                
                // 面板概览内容
                switch panel {
                case .notification:
                    notificationOverview()
                case .theme:
                    themeOverview()
                case .data:
                    dataOverview()
                case .about:
                    aboutOverview()
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 700, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private func subPanelDetailView(for subPanel: SettingsSubPanel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 子面板标题
                HStack {
                    Image(systemName: subPanel.icon)
                        .font(.title2)
                        .foregroundColor(subPanel.color)
                    Text(subPanel.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.top, 24)
                
                // 子面板具体内容
                subPanelContent(for: subPanel)
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 700, alignment: .leading)
        }
    }
    
    // MARK: - 面板概览内容
    @ViewBuilder
    private func notificationOverview() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("通知与提醒设置")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("管理应用的通知权限、提醒计划和免打扰时段设置。")
                .font(.body)
                .foregroundColor(.secondary)
            
            // 快速状态显示
            HStack {
                StatusIndicator(
                    title: "通知权限",
                    status: viewModel.enableNotifications ? "已启用" : "已禁用",
                    color: viewModel.enableNotifications ? .green : .red
                )
                
                StatusIndicator(
                    title: "免打扰",
                    status: viewModel.enableSilentPeriod ? "已启用" : "已禁用",
                    color: viewModel.enableSilentPeriod ? .orange : .gray
                )
            }
        }
    }
    
    @ViewBuilder
    private func themeOverview() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("外观与主题设置")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("自定义应用的外观、主题模式和显示效果。")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func dataOverview() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("数据与默认设置")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("管理应用数据、设置默认参数和进行数据维护操作。")
                .font(.body)
                .foregroundColor(.secondary)
            
            // 快速状态显示
            HStack {
                StatusIndicator(
                    title: "默认保修期",
                    status: "\(viewModel.defaultWarrantyPeriod)个月",
                    color: .blue
                )
                
                StatusIndicator(
                    title: "OCR识别",
                    status: viewModel.enableOCRByDefault ? "默认启用" : "默认关闭",
                    color: viewModel.enableOCRByDefault ? .green : .gray
                )
            }
        }
    }
    
    @ViewBuilder
    private func aboutOverview() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("关于与支持")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("查看应用信息、管理语言设置、访问法律文档和获取技术支持。")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 子面板内容
    @ViewBuilder
    private func subPanelContent(for subPanel: SettingsSubPanel) -> some View {
        switch subPanel {
        // 通知相关
        case .notificationPermissions:
            NotificationPermissionsContent()
                .environmentObject(viewModel)
        case .notificationSchedule:
            NotificationScheduleContent()
                .environmentObject(viewModel)
        case .silentPeriod:
            SilentPeriodContent()
                .environmentObject(viewModel)

        // 主题相关
        case .themeMode:
            ThemeModeContent()
        case .displaySettings:
            DisplaySettingsContent()

        // 数据相关
        case .defaultSettings:
            DefaultSettingsContent(
                defaultWarrantyPeriod: Binding(
                    get: { viewModel.defaultWarrantyPeriod },
                    set: { period in
                        viewModel.send(.updateDefaultWarrantyPeriod(period))
                    }
                ),
                enableOCRByDefault: Binding(
                    get: { viewModel.enableOCRByDefault },
                    set: { enabled in
                        viewModel.send(.updateEnableOCRByDefault(enabled))
                    }
                )
            )
        case .dataManagement:
            DataManagementContent()
        case .dataHealth:
            DataHealthContent()
        case .dangerousOperations:
            DangerousOperationsContent()

        // 关于相关
        case .appInfo:
            AppInfoContent()
        case .languageSettings:
            LanguageSettingsContent()
        case .legalPolicies:
            LegalPoliciesContent(
                showPrivacySheet: Binding(
                    get: { viewModel.showPrivacySheet },
                    set: { _ in
                        viewModel.send(.togglePrivacySheet)
                    }
                ),
                showAgreementSheet: Binding(
                    get: { viewModel.showAgreementSheet },
                    set: { _ in
                        viewModel.send(.toggleAgreementSheet)
                    }
                )
            )
        case .updateSupport:
            UpdateSupportContent()
        }
    }
}

// MARK: - 状态指示器组件
struct StatusIndicator: View {
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(status)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ThreeColumnSettingsView()
        .environmentObject(AppNotificationManager())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
