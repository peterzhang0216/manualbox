import SwiftUI

/// 统一的信息行组件，用于显示标签和值的键值对
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

/// 带标题参数的 InfoRow 初始化器，用于兼容性
extension InfoRow {
    init(title: String, value: String) {
        self.label = title
        self.value = value
    }
}

#Preview {
    VStack(spacing: 8) {
        InfoRow(label: "标签", value: "值")
        InfoRow(title: "标题", value: "内容")
    }
    .padding()
}