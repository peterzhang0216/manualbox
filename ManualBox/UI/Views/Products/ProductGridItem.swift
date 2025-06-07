import SwiftUI
import CoreData

struct ProductGridItem: View {
    let product: Product
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 产品图片
            Group {
                if let imageData = product.imageData,
                   let image = PlatformImage(data: imageData) {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 120)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundColor(.gray)
                        }
                }
            }
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                // 产品名称
                Text(product.productName)
                    .font(.headline)
                    .lineLimit(2)
                
                // 品牌和型号
                if !product.productBrand.isEmpty && !product.productModel.isEmpty {
                    Text("\(product.productBrand) \(product.productModel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // 标签
                if let tags = product.tags as? Set<Tag>, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(tags).prefix(3), id: \.objectID) { tag in
                                Text(tag.tagName)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                // 保修状态
                if let warrantyDate = product.order?.warrantyEndDate {
                    HStack {
                        Image(systemName: warrantyDate > Date() ? "checkmark.seal" : "exclamationmark.triangle")
                            .foregroundColor(warrantyDate > Date() ? .green : .orange)
                        
                        Text(warrantyDate > Date() ? "保修中" : "已过保")
                            .font(.caption2)
                            .foregroundColor(warrantyDate > Date() ? .green : .orange)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            Spacer()
        }
        .padding(12)
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .onTapGesture {
            onTap()
        }
    }
}