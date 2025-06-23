import SwiftUI

/// 设置卡片组件，用于包装设置面板中的各个功能区域
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let description: String?
    let content: Content
    
    @State private var isHovered = false
    
    init(
        title: String,
        icon: String,
        iconColor: Color = .accentColor,
        description: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.description = description
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 卡片头部
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [iconColor, iconColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: iconColor.opacity(0.3), radius: 3, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let description = description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            
            // 分隔线
            Divider()
                .background(iconColor.opacity(0.2))
            
            // 卡片内容
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.03))
                .stroke(Color.secondary.opacity(isHovered ? 0.15 : 0.08), lineWidth: 1)
                .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// 设置组件，用于包装单个设置项
struct SettingsGroup<Content: View>: View {
    let title: String?
    let content: Content
    
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            VStack(spacing: 8) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.04))
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
            )
        }
    }
}

/// 设置切换开关组件
struct SettingsToggle: View {
    let title: String
    let description: String?
    let icon: String
    let iconColor: Color
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 文本内容
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if let description = description {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // 切换开关
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: iconColor))
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

/// 设置选择器组件
struct SettingsPicker<SelectionValue: Hashable>: View {
    let title: String
    let description: String?
    let icon: String
    let iconColor: Color
    @Binding var selection: SelectionValue
    let options: [(value: SelectionValue, label: String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // 文本内容
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if let description = description {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            
            // 选择器
            Picker("", selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预览
#Preview {
    ScrollView {
        VStack(spacing: 24) {
            SettingsCard(
                title: "通知设置",
                icon: "bell.badge.fill",
                iconColor: .orange,
                description: "管理应用通知和提醒设置"
            ) {
                SettingsGroup(title: "基本设置") {
                    SettingsToggle(
                        title: "启用通知",
                        description: "允许应用发送通知提醒",
                        icon: "bell.fill",
                        iconColor: .orange,
                        isOn: .constant(true)
                    )
                    
                    SettingsToggle(
                        title: "免打扰模式",
                        description: "在指定时间段内静音通知",
                        icon: "moon.fill",
                        iconColor: .purple,
                        isOn: .constant(false)
                    )
                }
            }
            
            SettingsCard(
                title: "外观设置",
                icon: "paintbrush.fill",
                iconColor: .blue,
                description: "自定义应用的外观和主题"
            ) {
                SettingsGroup(title: "主题模式") {
                    SettingsPicker(
                        title: "主题模式",
                        description: "选择应用的显示主题",
                        icon: "circle.lefthalf.filled",
                        iconColor: .blue,
                        selection: .constant("system"),
                        options: [
                            ("light", "浅色"),
                            ("dark", "深色"),
                            ("system", "跟随系统")
                        ]
                    )
                }
            }
        }
        .padding()
    }
}
