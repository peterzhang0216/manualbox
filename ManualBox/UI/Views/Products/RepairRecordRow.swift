import SwiftUI
import CoreData

struct RepairRecordRow: View {
    let record: RepairRecord
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 日期圆形标签
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                VStack(spacing: 0) {
                    if let date = record.date {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Text(monthAbbreviation(from: date))
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // 维修详情
            VStack(alignment: .leading, spacing: 4) {
                Text(record.recordDetails)
                    .font(.callout)
                    .lineLimit(1)
                
                Text(record.formattedCost)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 查看详情箭头
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(0.7)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.1))
        )
        .padding(.vertical, 4)
    }
    
    // 获取月份缩写
    private func monthAbbreviation(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}

#Preview {
    RepairRecordRow(record: RepairRecord.preview)
        .padding()
}
