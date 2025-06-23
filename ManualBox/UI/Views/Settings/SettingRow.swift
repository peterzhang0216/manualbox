import SwiftUI

/// 设置行视图，用于设置页面中的各种列表项
struct SettingRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var warning: Bool = false
    var showChevron: Bool = false
    var trailingContent: (() -> AnyView)? = nil
    var isInteractive: Bool = true

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 16) {
            // 增强的图标设计
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        warning ?
                        LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [iconColor, iconColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: (warning ? .red : iconColor).opacity(0.25), radius: 3, x: 0, y: 2)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)

            // 改进的文本布局
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(warning ? .red : .primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(warning ? .red.opacity(0.8) : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            // 可选的末尾内容
            if let trailingContent = trailingContent {
                trailingContent()
            }

            // 改进的箭头图标
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.secondary)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPressed ? Color.secondary.opacity(0.08) : Color.clear)
                .animation(.easeInOut(duration: 0.15), value: isPressed)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isInteractive && !isPressed {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    if isPressed {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = false
                        }
                    }
                }
        )
    }
}

// 预览
#Preview {
    VStack {
        SettingRow(
            icon: "bell.badge.fill", 
            iconColor: .blue,
            title: "通知设置",
            subtitle: "管理提醒时间与通知方式"
        )
        
        SettingRow(
            icon: "trash.fill", 
            iconColor: .red,
            title: "删除数据",
            subtitle: "清除所有数据，此操作不可恢复",
            warning: true
        )
        
        SettingRow(
            icon: "arrow.up.arrow.down", 
            iconColor: .green,
            title: "数据导入导出",
            subtitle: "导入或导出应用数据",
            showChevron: true
        )
        
        SettingRow(
            icon: "checkmark.circle.fill", 
            iconColor: .accentColor,
            title: "选项设置",
            subtitle: "自定义应用选项",
            trailingContent: {
                AnyView(Toggle("", isOn: .constant(true)).labelsHidden())
            }
        )
    }
    .padding()
}
