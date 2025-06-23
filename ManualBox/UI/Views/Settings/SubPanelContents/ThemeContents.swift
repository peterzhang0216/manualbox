import SwiftUI

// MARK: - 主题模式内容
struct ThemeModeContent: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    
    var body: some View {
        SettingsCard(
            title: "主题模式选择",
            icon: "circle.lefthalf.filled",
            iconColor: .blue,
            description: "选择应用的显示主题模式"
        ) {
            SettingsGroup {
                ThemePickerView()
            }
        }
    }
}

// MARK: - 显示设置内容
struct DisplaySettingsContent: View {
    var body: some View {
        SettingsCard(
            title: "显示效果设置",
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
                
                Divider()
                    .padding(.vertical, 8)
                
                SettingsToggle(
                    title: "大字体支持",
                    description: "支持系统动态字体大小调整",
                    icon: "textformat.size",
                    iconColor: .blue,
                    isOn: .constant(true)
                )
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ThemeModeContent()
        DisplaySettingsContent()
    }
    .padding()
}
