//
//  ProductDetailViewComponents.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI
import CoreData

// MARK: - 产品详情视图组件扩展
extension ProductDetailView {
    
    // MARK: - 产品信息头部
    var productHeader: some View {
        HStack(spacing: 20) {
            // 产品图片
            Group {
                if let imageData = product.imageData,
                   let image = PlatformImage(data: imageData) {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // 产品基本信息
            VStack(alignment: .leading, spacing: 8) {
                Text(product.productName)
                    .font(.title)
                    .fontWeight(.bold)
                
                if !product.productBrand.isEmpty {
                    Text(product.productBrand)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                if !product.productModel.isEmpty {
                    Text("型号: \(product.productModel)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 保修状态
                HStack {
                    if product.hasActiveWarranty {
                        Label("保修有效", systemImage: "checkmark.shield.fill")
                            .foregroundColor(.green)
                    } else if product.order != nil {
                        Label("保修过期", systemImage: "xmark.shield.fill")
                            .foregroundColor(.red)
                    } else {
                        Text("未记录保修信息")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 基本信息部分
    var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)
            
            // 分类信息
            if let category = product.category {
                HStack {
                    Text("分类:")
                    Label(category.categoryName, systemImage: category.categoryIcon)
                        .foregroundColor(.blue)
                }
            }
            
            // 标签信息
            if let tags = product.tags, tags.count > 0 {
                HStack(alignment: .top) {
                    Text("标签:")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            let tagArray = (tags as NSSet).allObjects as? [Tag] ?? []
                            ForEach(tagArray.sorted { ($0.name ?? "") < ($1.name ?? "") }) { tag in
                                TagView(tag: tag)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 订单信息部分
    func orderInfoSection(order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("订单信息")
                .font(.headline)
            
            if let orderNumber = order.orderNumber, !orderNumber.isEmpty {
                HStack {
                    Text("订单号:")
                    Text(orderNumber)
                        .foregroundColor(.secondary)
                }
            }
            
            if let platform = order.platform, !platform.isEmpty {
                HStack {
                    Text("购买平台:")
                    Text(platform)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("购买日期:")
                Text(order.orderDate ?? Date(), style: .date)
                    .foregroundColor(.secondary)
            }
            
            if let warrantyEndDate = order.warrantyEndDate {
                HStack {
                    Text("保修期至:")
                    Text(warrantyEndDate, style: .date)
                        .foregroundColor(product.hasActiveWarranty ? .green : .red)
                        .fontWeight(product.hasActiveWarranty ? .semibold : .regular)
                }
            }
            
            // 发票显示
            if let invoiceData = order.invoiceData,
               let image = PlatformImage(data: invoiceData) {
                VStack(alignment: .leading) {
                    Text("发票:")
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - 维修记录部分
    func repairRecordsSection(records: NSSet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("维修记录")
                    .font(.headline)
                
                Spacer()
                
                if let order = product.order {
                    NavigationLink(destination: AddRepairRecordView(order: order)) {
                        Label("添加", systemImage: "plus.circle")
                            .font(.caption)
                    }
                }
            }
            
            let recordArray = (records as NSSet).allObjects as? [RepairRecord] ?? []
            let sortedRecords = recordArray.sorted { (record1: RepairRecord, record2: RepairRecord) in
                (record1.date ?? Date()) > (record2.date ?? Date())
            }
            
            if sortedRecords.isEmpty {
                Text("暂无维修记录")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 8)
            } else {
                ForEach(sortedRecords, id: \.id) { record in
                    NavigationLink(destination: RepairRecordDetailView(record: record)) {
                        RepairRecordRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - 说明书部分
    func manualsSection(manuals: NSSet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("说明书")
                .font(.headline)
            
            let manualArray = (manuals as NSSet).allObjects as? [Manual] ?? []
            let sortedManuals = manualArray.sorted { (manual1: Manual, manual2: Manual) in
                (manual1.fileName ?? "") < (manual2.fileName ?? "")
            }
            
            ForEach(sortedManuals, id: \.id) { manual in
                HStack {
                    Image(systemName: manual.fileType == "pdf" ? "doc.fill" : "doc.text.image")
                        .foregroundColor(.blue)
                    
                    if let fileName = manual.fileName {
                        Text(fileName)
                    }
                    
                    Spacer()
                    
                    Button {
                        selectedManual = manual
                    } label: {
                        Image(systemName: "eye")
                    }
                    .buttonStyle(.borderless)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - 标签视图
struct TagView: View {
    let tag: Tag
    
    var body: some View {
        HStack {
            Circle()
                .fill(tag.uiColor)
                .frame(width: 8, height: 8)
            Text(tag.tagName)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tag.uiColor.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tag.uiColor, lineWidth: 1)
        )
    }
}