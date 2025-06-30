//
//  ExtendedWarrantyListView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/25.
//

import SwiftUI

// MARK: - 扩展保修列表视图
struct ExtendedWarrantyListView: View {
    @StateObject private var warrantyService = EnhancedWarrantyService.shared
    @State private var searchText = ""
    @State private var selectedWarranty: ExtendedWarrantyInfo?
    @State private var showingAddWarranty = false
    
    private var filteredWarranties: [ExtendedWarrantyInfo] {
        if searchText.isEmpty {
            return warrantyService.extendedWarranties
        } else {
            return warrantyService.extendedWarranties.filter { warranty in
                warranty.provider.localizedCaseInsensitiveContains(searchText) ||
                warranty.type.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            SearchBar(text: $searchText, placeholder: "搜索保修服务...")
                .padding()
            
            if filteredWarranties.isEmpty {
                emptyStateView
            } else {
                warrantyList
            }
        }
        .sheet(item: $selectedWarranty) { warranty in
            NavigationView {
                VStack {
                    Text("扩展保修详情")
                        .font(.headline)
                    Text("功能开发中...")
                        .foregroundColor(.secondary)
                }
                .navigationTitle("保修详情")
                #if os(macOS)
                .platformToolbar(trailing: {
                    Button("关闭") {
                        selectedWarranty = nil
                    }
                })
                #else
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                        Button("关闭") {
                            selectedWarranty = nil
                        }
                    }
                }
                #endif
            }
        }
        .sheet(isPresented: $showingAddWarranty) {
            NavigationView {
                VStack {
                    Text("添加扩展保修")
                        .font(.headline)
                    Text("功能开发中...")
                        .foregroundColor(.secondary)
                }
                .navigationTitle("添加保修")
                #if os(macOS)
                .platformToolbar(trailing: {
                    Button("关闭") {
                        showingAddWarranty = false
                    }
                })
                #else
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                        Button("关闭") {
                            showingAddWarranty = false
                        }
                    }
                }
                #endif
            }
        }
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无扩展保修")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("添加扩展保修服务以获得更好的产品保护")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                showingAddWarranty = true
            }) {
                Label("添加扩展保修", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 保修列表
    
    private var warrantyList: some View {
        List {
            ForEach(filteredWarranties) { warranty in
                ExtendedWarrantyCard(warranty: warranty) {
                    selectedWarranty = warranty
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - 扩展保修卡片
struct ExtendedWarrantyCard: View {
    let warranty: ExtendedWarrantyInfo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // 头部信息
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(warranty.provider)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: warranty.type.icon)
                                .foregroundColor(Color(warranty.type.color))
                            
                            Text(warranty.type.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        WarrantyStatusBadge(status: warranty.status)
                        
                        Text("¥\(NSDecimalNumber(decimal: warranty.cost).doubleValue, specifier: "%.0f")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                
                // 时间信息
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("开始日期")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(DateFormatter.mediumDate.string(from: warranty.startDate))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 2) {
                        Text("剩余天数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(warranty.daysRemaining)天")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(warranty.daysRemaining <= 30 ? .orange : .primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("到期日期")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(DateFormatter.mediumDate.string(from: warranty.endDate))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                // 覆盖范围
                if !warranty.coverage.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("保修范围")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(warranty.coverage.prefix(3).joined(separator: " • "))
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        if warranty.coverage.count > 3 {
                            Text("还有\(warranty.coverage.count - 3)项...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 续费信息
                if let renewalInfo = warranty.renewalInfo {
                    HStack {
                        Image(systemName: renewalInfo.isAutoRenewal ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                            .foregroundColor(renewalInfo.isAutoRenewal ? .green : .secondary)
                        
                        Text(renewalInfo.isAutoRenewal ? "自动续费" : "手动续费")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let renewalDate = renewalInfo.renewalDate {
                            Spacer()
                            
                            Text("续费日期: \(DateFormatter.shortDate.string(from: renewalDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            #if os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
            #else
            .background(Color(.systemBackground))
            #endif
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

// MARK: - 保修状态徽章
struct WarrantyStatusBadge: View {
    let status: ProductSearchFilters.WarrantyStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(status))
            .cornerRadius(8)
    }
}

// MARK: - 搜索栏
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(.systemGray6))
        #endif
        .cornerRadius(10)
    }
}

// MARK: - DateFormatter 扩展
extension DateFormatter {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

// MARK: - 预览
struct ExtendedWarrantyListView_Previews: PreviewProvider {
    static var previews: some View {
        ExtendedWarrantyListView()
    }
}
