import SwiftUI

// MARK: - 主题模式内容（旧版本）
struct LegacyThemeModeContent: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("accentColor") private var accentColorKey: String = "blue"

    var body: some View {
        VStack(spacing: 24) {
            // 主题模式选择
            SettingsCard(
                title: "主题模式选择",
                icon: "circle.lefthalf.filled",
                iconColor: .blue,
                description: "选择应用的显示主题模式"
            ) {
                LegacySettingsGroup {
                    ThemePickerView()
                }
            }

            // 主题色选择
            SettingsCard(
                title: "主题色",
                icon: "paintpalette.fill",
                iconColor: .purple,
                description: "选择应用的主题色彩"
            ) {
                LegacySettingsGroup {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        AccentColorOption(
                            color: .accentColor,
                            name: "系统",
                            key: "accentColor",
                            isSelected: accentColorKey == "accentColor"
                        ) {
                            accentColorKey = "accentColor"
                        }

                        AccentColorOption(
                            color: .blue,
                            name: "蓝色",
                            key: "blue",
                            isSelected: accentColorKey == "blue"
                        ) {
                            accentColorKey = "blue"
                        }

                        AccentColorOption(
                            color: .green,
                            name: "绿色",
                            key: "green",
                            isSelected: accentColorKey == "green"
                        ) {
                            accentColorKey = "green"
                        }

                        AccentColorOption(
                            color: .orange,
                            name: "橙色",
                            key: "orange",
                            isSelected: accentColorKey == "orange"
                        ) {
                            accentColorKey = "orange"
                        }

                        AccentColorOption(
                            color: .pink,
                            name: "粉色",
                            key: "pink",
                            isSelected: accentColorKey == "pink"
                        ) {
                            accentColorKey = "pink"
                        }

                        AccentColorOption(
                            color: .purple,
                            name: "紫色",
                            key: "purple",
                            isSelected: accentColorKey == "purple"
                        ) {
                            accentColorKey = "purple"
                        }

                        AccentColorOption(
                            color: .red,
                            name: "红色",
                            key: "red",
                            isSelected: accentColorKey == "red"
                        ) {
                            accentColorKey = "red"
                        }

                        AccentColorOption(
                            color: .teal,
                            name: "青色",
                            key: "teal",
                            isSelected: accentColorKey == "teal"
                        ) {
                            accentColorKey = "teal"
                        }

                        AccentColorOption(
                            color: .yellow,
                            name: "黄色",
                            key: "yellow",
                            isSelected: accentColorKey == "yellow"
                        ) {
                            accentColorKey = "yellow"
                        }

                        AccentColorOption(
                            color: .indigo,
                            name: "靛蓝",
                            key: "indigo",
                            isSelected: accentColorKey == "indigo"
                        ) {
                            accentColorKey = "indigo"
                        }

                        AccentColorOption(
                            color: .mint,
                            name: "薄荷",
                            key: "mint",
                            isSelected: accentColorKey == "mint"
                        ) {
                            accentColorKey = "mint"
                        }

                        AccentColorOption(
                            color: .cyan,
                            name: "青蓝",
                            key: "cyan",
                            isSelected: accentColorKey == "cyan"
                        ) {
                            accentColorKey = "cyan"
                        }

                        AccentColorOption(
                            color: .brown,
                            name: "棕色",
                            key: "brown",
                            isSelected: accentColorKey == "brown"
                        ) {
                            accentColorKey = "brown"
                        }
                    }
                    .padding(.vertical, 8)
                }
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
            LegacySettingsGroup {
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

// MARK: - 主题色选项组件
struct AccentColorOption: View {
    let color: Color
    let name: String
    let key: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 40, height: 40)

                    if isSelected {
                        Circle()
                            .stroke(Color.primary, lineWidth: 3)
                            .frame(width: 46, height: 46)

                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Text(name)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        LegacyThemeModeContent()
        DisplaySettingsContent()
    }
    .padding()
}
