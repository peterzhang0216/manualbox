import SwiftUI

// MARK: - 保修期默认设置视图
struct WarrantyDefaultView: View {
    @Binding var period: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题部分使用更明显的设计
            Label("默认保修期", systemImage: "clock.fill")
                .foregroundColor(.accentColor)
                .font(.headline)
            
            // 数值展示部分
            HStack(alignment: .center) {
                Text("\(period)")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(minWidth: 30, alignment: .trailing)
                
                Text("个月")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 修复 Stepper 组件，明确显示文本
                Stepper(
                    value: $period, 
                    in: 0...60,
                    label: { Text("设置保修期").foregroundColor(.clear).frame(width: 0) }
                )
            }
            
            // 说明文字
            Text("新增商品时的默认保修期限")
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