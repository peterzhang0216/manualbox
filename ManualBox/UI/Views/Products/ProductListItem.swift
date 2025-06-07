import SwiftUI
import CoreData

struct ProductListItem: View {
    let product: Product
    
    var body: some View {
        HStack {
            if let imageData = product.imageData,
               let image = PlatformImage(data: imageData) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.gray)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .frame(width: 60, height: 60)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.headline)
                
                if let order = product.order {
                    Text("购买日期: \(order.orderDate?.formatted() ?? "")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let order = product.order,
               let warrantyEndDate = order.warrantyEndDate {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("保修到期")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(warrantyEndDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(warrantyEndDate > Date() ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}