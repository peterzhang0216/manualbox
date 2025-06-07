import SwiftUI
import CoreData


struct RepairRecordDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let record: RepairRecord
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 维修记录信息头部
                recordHeader
                
                Divider()
                
                // 维修记录详细信息
                detailsSection
                
                Divider()
                
                // 关联产品信息
                if let order = record.order, let product = order.product {
                    relatedProductSection(product: product)
                }
                
                Spacer(minLength: 20)
                
                // 删除按钮
                Button(role: .destructive, action: {
                    showingDeleteAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("删除此维修记录")
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
                .padding(.top, 10)
            }
            .padding()
        }
        .navigationTitle("维修记录详情")
        .toolbar {
            ToolbarItem {
                Button(action: {
                    showingEditSheet = true
                }) {
                    Label("编辑", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                EditRepairRecordView(record: record)
            }
            .presentationDetents([.medium, .large])
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("此操作无法撤销，确定要删除此维修记录吗？")
        }
    }
    
    // 维修记录信息头部
    private var recordHeader: some View {
        HStack(spacing: 20) {
            // 维修图标
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(Double(0.2)))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }
            
            // 基本信息
            VStack(alignment: .leading, spacing: 8) {
                Text(record.formattedDate)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(record.formattedCost)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // 维修详细信息部分
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("维修详情")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text(record.recordDetails)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(Double(0.1)))
                )
        }
    }
    
    // 关联产品信息部分
    private func relatedProductSection(product: Product) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("关联产品")
                .font(.headline)
                .padding(.bottom, 4)
            
            NavigationLink(destination: ProductDetailView(product: product)) {
                HStack {
                    // 产品图片
                    if let imageData = product.imageData,
                       let image = PlatformImage(data: imageData) {
                        Image(platformImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.gray)
                            .padding(5)
                            .background(Color.gray.opacity(Double(0.1)))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.productName)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        if !product.productBrand.isEmpty {
                            Text(product.productBrand)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(Double(0.1)))
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // 删除记录
    private func deleteRecord() {
        viewContext.delete(record)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("删除记录失败: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        RepairRecordDetailView(record: RepairRecord.preview)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
