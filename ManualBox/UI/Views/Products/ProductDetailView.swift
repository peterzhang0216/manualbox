//
//  ProductDetailView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI
import CoreData

// MARK: - 产品详情视图
struct ProductDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var detailPanelStateManager: DetailPanelStateManager
    
    let product: Product
    @State private var selectedManual: Manual?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 产品信息头部
                productHeader
                
                Divider()
                
                // 基本信息部分
                basicInfoSection
                
                // 订单信息部分
                if let order = product.order {
                    Divider()
                    orderInfoSection(order: order)
                    
                    // 维修记录部分
                    if let records = order.repairRecords, records.count > 0 {
                        Divider()
                        repairRecordsSection(records: records)
                    }
                }
                
                // 说明书部分
                if let manuals = product.manuals, manuals.count > 0 {
                    Divider()
                    manualsSection(manuals: manuals)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(product.productName)
        .toolbar {
            SwiftUI.ToolbarItem {
                Button {
                    detailPanelStateManager.showEditProduct(product)
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
            }
        }
        .sheet(item: $selectedManual) { manual in
            NavigationStack {
                ManualPreviewView(manual: manual)
            }
            .presentationDetents([.large, .medium])
        }
    }
}

// MARK: - 预览
struct ProductDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProductDetailView(product: PersistenceController.preview.previewProduct())
                .environmentObject(DetailPanelStateManager())
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}