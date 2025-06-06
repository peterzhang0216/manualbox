import SwiftUI

/// 主题选择视图
struct ThemePickerView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    
    let themes = [
        ("system", "跟随系统", "circle.lefthalf.filled"),
        ("light", "浅色", "sun.max.fill"),
        ("dark", "深色", "moon.stars.fill")
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(themes, id: \.0) { theme in
                    ThemeButton(
                        id: theme.0,
                        title: NSLocalizedString(theme.1, comment: ""),
                        icon: theme.2,
                        isSelected: appTheme == theme.0,
                        totalCount: themes.count,
                        index: themes.firstIndex(where: { $0.0 == theme.0 }) ?? 0
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            appTheme = theme.0
                        }
                    }
                }
            }
            .frame(height: 44)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct ThemeButton: View {
    let id: String
    let title: String
    let icon: String
    let isSelected: Bool
    let totalCount: Int
    let index: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(title)
                .font(.subheadline)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            isSelected ?
                RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor)
                .padding(4)
                : nil
        )
        .foregroundColor(isSelected ? .white : .primary)
        .contentShape(Rectangle())
    }
}

// 预览
#Preview {
    VStack {
        ThemePickerView()
    }
    .padding()
}
