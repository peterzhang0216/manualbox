import SwiftUI

// MARK: - 主题设置面板
struct ThemeSettingsPanel: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 页面标题
                HStack {
                    Image(systemName: "paintbrush.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("外观与主题".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.top, 24)

                // 主题模式设置卡片
                SettingsCard(
                    title: "主题模式",
                    icon: "circle.lefthalf.filled",
                    iconColor: .blue,
                    description: "选择应用的显示主题模式"
                ) {
                    SettingsGroup {
                        ThemePickerView()
                    }
                }

                // 显示设置卡片
                SettingsCard(
                    title: "显示设置",
                    icon: "display",
                    iconColor: .orange,
                    description: "调整应用的显示效果和动画"
                ) {
                    SettingsGroup {
                        SettingsToggle(
                            title: "减少动画",
                            description: "减少界面动画效果以提升性能",
                            icon: "speedometer",
                            iconColor: .orange,
                            isOn: .constant(false)
                        )

                        Divider()
                            .padding(.vertical, 8)

                        SettingsToggle(
                            title: "高对比度",
                            description: "增强界面对比度以提升可读性",
                            icon: "circle.lefthalf.filled",
                            iconColor: .gray,
                            isOn: .constant(false)
                        )
                    }
                }

                // 语言设置卡片
                SettingsCard(
                    title: "语言设置",
                    icon: "globe",
                    iconColor: .green,
                    description: "选择应用的显示语言"
                ) {
                    SettingsGroup {
                        LanguageSettingsCard()
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

#Preview {
    ThemeSettingsPanel()
        .environmentObject(SettingsViewModel(viewContext: PersistenceController.preview.container.viewContext))
}