import SwiftUI

// MARK: - 主题模式详细视图
struct ThemeModeDetailView: View {
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("accentColor") private var accentColorKey: String = "blue"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 主题模式选择
                SettingsCard(
                    title: "主题模式",
                    icon: "circle.lefthalf.filled",
                    iconColor: .primary,
                    description: "选择应用的外观主题"
                ) {
                    SettingsGroup {
                        VStack(spacing: 0) {
                            ThemeModeRow(
                                title: "跟随系统",
                                description: "根据系统设置自动切换",
                                icon: "gear",
                                isSelected: colorScheme == "system"
                            ) {
                                colorScheme = "system"
                            }
                            
                            Divider()
                            
                            ThemeModeRow(
                                title: "浅色模式",
                                description: "始终使用浅色主题",
                                icon: "sun.max.fill",
                                isSelected: colorScheme == "light"
                            ) {
                                colorScheme = "light"
                            }
                            
                            Divider()
                            
                            ThemeModeRow(
                                title: "深色模式",
                                description: "始终使用深色主题",
                                icon: "moon.fill",
                                isSelected: colorScheme == "dark"
                            ) {
                                colorScheme = "dark"
                            }
                        }
                    }
                }
                
                // 主题色选择
                SettingsCard(
                    title: "主题色",
                    icon: "paintpalette.fill",
                    iconColor: .purple,
                    description: "选择应用的主题色彩"
                ) {
                    SettingsGroup {
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
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("主题模式")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - 显示设置详细视图
struct DisplaySettingsDetailView: View {
    @AppStorage("enableAnimations") private var enableAnimations: Bool = true
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback: Bool = true
    @AppStorage("showBadges") private var showBadges: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 动画设置
                SettingsCard(
                    title: "动画效果",
                    icon: "sparkles",
                    iconColor: .yellow,
                    description: "控制应用中的动画效果"
                ) {
                    SettingsGroup {
                        SettingsToggle(
                            title: "启用动画",
                            description: "显示界面切换和交互动画",
                            icon: "sparkles",
                            iconColor: .yellow,
                            isOn: $enableAnimations
                        )
                    }
                }
                
                // 触觉反馈设置
                SettingsCard(
                    title: "触觉反馈",
                    icon: "hand.tap.fill",
                    iconColor: .blue,
                    description: "控制触摸时的震动反馈"
                ) {
                    SettingsGroup {
                        SettingsToggle(
                            title: "启用触觉反馈",
                            description: "在交互时提供震动反馈",
                            icon: "hand.tap.fill",
                            iconColor: .blue,
                            isOn: $enableHapticFeedback
                        )
                    }
                }
                
                // 徽章设置
                SettingsCard(
                    title: "徽章显示",
                    icon: "app.badge.fill",
                    iconColor: .red,
                    description: "控制应用图标上的徽章显示"
                ) {
                    SettingsGroup {
                        SettingsToggle(
                            title: "显示徽章",
                            description: "在应用图标上显示未读数量",
                            icon: "app.badge.fill",
                            iconColor: .red,
                            isOn: $showBadges
                        )
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("显示设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - 主题模式行组件
struct ThemeModeRow: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}



#Preview {
    NavigationStack {
        ThemeModeDetailView()
    }
}
