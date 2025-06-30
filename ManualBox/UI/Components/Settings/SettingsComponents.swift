import SwiftUI

// MARK: - 设置组件库

/// 设置页面容器
struct SettingsPageContainer<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let description: String?
    let content: () -> Content
    
    init(
        title: String,
        icon: String,
        iconColor: Color = .accentColor,
        description: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.description = description
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 页面标题
                SettingsPageHeader(
                    title: title,
                    icon: icon,
                    iconColor: iconColor,
                    description: description
                )
                
                // 内容区域
                content()
                
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .frame(maxWidth: 700, alignment: .leading)
        }
    }
}

/// 设置页面标题
struct SettingsPageHeader: View {
    let title: String
    let icon: String
    let iconColor: Color
    let description: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            if let description = description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 44)
            }
        }
    }
}

/// 增强的设置卡片
struct EnhancedSettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let description: String?
    let isEnabled: Bool
    let content: () -> Content
    
    init(
        title: String,
        icon: String,
        iconColor: Color = .accentColor,
        description: String? = nil,
        isEnabled: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.description = description
        self.isEnabled = isEnabled
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 卡片标题
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isEnabled ? iconColor : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((isEnabled ? iconColor : .secondary).opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isEnabled ? .primary : .secondary)
                    
                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // 卡片内容
            content()
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.adaptiveSecondaryBackground)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

/// 设置组
struct SettingsGroup<Content: View>: View {
    let title: String?
    let content: () -> Content
    
    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.adaptiveBackground)
            )
        }
    }
}

/// 增强的设置行
struct EnhancedSettingsRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let isEnabled: Bool
    let content: () -> Content
    
    init(
        icon: String,
        iconColor: Color = .accentColor,
        title: String,
        subtitle: String? = nil,
        isEnabled: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.isEnabled = isEnabled
        self.content = content
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isEnabled ? iconColor : .secondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill((isEnabled ? iconColor : .secondary).opacity(0.1))
                )
            
            // 标题和副标题
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isEnabled ? .primary : .secondary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 控件内容
            content()
                .disabled(!isEnabled)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

/// 设置切换开关
struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let isEnabled: Bool
    
    init(
        icon: String,
        iconColor: Color = .accentColor,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        isEnabled: Bool = true
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        EnhancedSettingsRow(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: subtitle,
            isEnabled: isEnabled
        ) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

/// 设置选择器行
struct SettingsPickerRow<SelectionValue: Hashable>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    @Binding var selection: SelectionValue
    let options: [(value: SelectionValue, label: String)]
    let isEnabled: Bool
    
    init(
        icon: String,
        iconColor: Color = .accentColor,
        title: String,
        subtitle: String? = nil,
        selection: Binding<SelectionValue>,
        options: [(value: SelectionValue, label: String)],
        isEnabled: Bool = true
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self._selection = selection
        self.options = options
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        EnhancedSettingsRow(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: subtitle,
            isEnabled: isEnabled
        ) {
            Picker("", selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}

/// 设置导航行
struct SettingsNavigationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let badge: String?
    let isEnabled: Bool
    let action: () -> Void
    
    init(
        icon: String,
        iconColor: Color = .accentColor,
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            EnhancedSettingsRow(
                icon: icon,
                iconColor: iconColor,
                title: title,
                subtitle: subtitle,
                isEnabled: isEnabled
            ) {
                HStack(spacing: 8) {
                    if let badge = badge {
                        Text(badge)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(iconColor.opacity(0.2))
                            )
                            .foregroundColor(iconColor)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
