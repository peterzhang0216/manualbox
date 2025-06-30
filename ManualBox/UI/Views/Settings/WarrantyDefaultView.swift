import SwiftUI

// MARK: - 保修期默认设置视图
struct WarrantyDefaultView: View {
    @Binding var period: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactStepper("默认保修期", value: $period, in: 0...60, unit: "个月")

            // 说明文字
            Text("添加新商品时自动设置的保修期长度")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    @Previewable @State var period = 12
    
    return WarrantyDefaultView(period: $period)
        .padding()
}