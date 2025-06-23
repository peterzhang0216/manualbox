import SwiftUI

// MARK: - OCR 默认设置视图
struct OCRDefaultView: View {
    @Binding var enabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题部分
            Label("智能文字识别", systemImage: "doc.text.viewfinder")
                .foregroundColor(.orange)
                .font(.headline)

            // 开关组件，更明确的显示
            HStack {
                Toggle(isOn: $enabled) {
                    Text("默认启用 OCR 识别")
                        .font(.body)
                }
                .toggleStyle(SwitchToggleStyle(tint: .orange))
            }

            // 说明文字
            Text("上传说明书图片时自动提取其中的文字内容")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    @Previewable @State var enabled = true
    
    return OCRDefaultView(enabled: $enabled)
        .padding()
}