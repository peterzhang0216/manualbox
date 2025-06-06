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
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(warning ? .red : iconColor == .accentColor ? .accentColor : iconColor)
                .frame(width: 28, height: 28)
                .background((iconColor == .accentColor ? Color.accentColor : iconColor).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // 标题和副标题
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                    .foregroundColor(warning ? .red : .primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(warning ? .red : .secondary)
            }
            
            Spacer()
            
            // 可选的末尾内容
            if let trailingContent = trailingContent {
                trailingContent()
            }
            
            // 可选的箭头图标
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
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
