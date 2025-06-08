import SwiftUI

// MARK: - 主题色自定义
struct AccentColorPickerView: View {
    @AppStorage("accentColor") private var accentColor: String = "accentColor"
    
    // 添加完整的颜色数组，确保包含所有常用系统颜色
    let colors: [(key: String, color: Color, name: String)] = [
        ("accentColor", .accentColor, "系统"),
        ("blue", .blue, "蓝色"),
        ("green", .green, "绿色"),
        ("orange", .orange, "橙色"),
        ("pink", .pink, "粉色"),
        ("purple", .purple, "紫色"),
        ("red", .red, "红色"),
        ("teal", .teal, "青色"),
        ("yellow", .yellow, "黄色"),
        ("indigo", .indigo, "靛蓝")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(NSLocalizedString("Theme Color", comment: ""))
                    .font(.headline)
                
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60, maximum: 80))], spacing: 12) {
                ForEach(colors, id: \.key) { item in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 32, height: 32)
                                .shadow(color: item.color.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            if accentColor == item.key {
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 2)
                                    .frame(width: 16, height: 16)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(item.color.opacity(0.15))
                                .frame(width: 44, height: 44)
                        )
                        .overlay(
                            Circle()
                                .stroke(accentColor == item.key ? item.color : Color.clear, lineWidth: 2)
                                .frame(width: 44, height: 44)
                        )
                        
                        Text(NSLocalizedString(item.name, comment: ""))
                            .font(.caption2)
                            .foregroundColor(accentColor == item.key ? item.color : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            accentColor = item.key
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    AccentColorPickerView()
        .padding()
}