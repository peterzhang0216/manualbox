import SwiftUI
import CoreData

struct ProductRowView: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: 16) {
            // 产品图片
            Group {
                if let imageData = product.imageData,
                   let uiImage = PlatformImage(data: imageData) {
                    Image(platformImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "shippingbox")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(width: 48, height: 48)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 产品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name ?? "未命名产品")
                    .font(.headline)
                HStack {
                    if let brand = product.brand {
                        Text(brand)
                            .foregroundColor(.secondary)
                    }
                    if let model = product.model {
                        Text("・\(model)")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
                // 保修状态
                if let order = product.order,
                   let warrantyEnd = order.warrantyEndDate {
                    HStack {
                        let daysRemaining = Calendar.current.numberOfDaysBetween(Date(), and: warrantyEnd)
                        if daysRemaining > 0 {
                            Label("还剩 \(daysRemaining) 天", systemImage: "clock")
                                .foregroundColor(.green)
                        } else {
                            Label("已过保", systemImage: "exclamationmark.triangle")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.caption)
                }
            }
            Spacer()
            // 右侧分类标签
            if let category = product.category {
                Label(category.name ?? "", systemImage: category.icon ?? "folder")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
#if os(iOS)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
#else
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
#endif
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
