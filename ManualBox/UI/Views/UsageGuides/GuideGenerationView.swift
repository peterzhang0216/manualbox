//
//  GuideGenerationView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI
import CoreData

// MARK: - 指南生成视图
struct GuideGenerationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guideService = UsageGuideGenerationService.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Product.name, ascending: true)],
        animation: .default
    ) private var products: FetchedResults<Product>
    
    @State private var selectedProduct: Product?
    @State private var selectedTemplate: GuideTemplate?
    @State private var generationConfig = GuideGenerationConfig.default
    @State private var searchText = ""
    @State private var showingTemplateSelector = false
    @State private var isGenerating = false
    @State private var generatedGuide: ProductUsageGuide?
    @State private var generationError: String?
    
    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return Array(products)
        } else {
            return products.filter { product in
                product.productName.localizedCaseInsensitiveContains(searchText) ||
                product.productBrand.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var canGenerate: Bool {
        guard let product = selectedProduct else { return false }
        return !product.productManuals.isEmpty && product.productManuals.contains { $0.isOCRProcessed }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isGenerating {
                    generationProgressView
                } else {
                    configurationView
                }
            }
            .navigationTitle("生成使用指南")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                    Button("生成") {
                        generateGuide()
                    }
                }
            })
            #else
            .toolbar(content: {
                SwiftUI.ToolbarItem(placement: .automatic) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                SwiftUI.ToolbarItem(placement: .automatic) {
                    Button("生成") {
                        generateGuide()
                    }
                }
            })
            #endif
            .sheet(isPresented: $showingTemplateSelector) {
                TemplateSelectionView(selectedTemplate: $selectedTemplate)
            }
            .sheet(item: $generatedGuide) { guide in
                UsageGuideDetailView(guide: guide)
            }
            .alert("生成失败", isPresented: .constant(generationError != nil)) {
                Button("确定") {
                    generationError = nil
                }
            } message: {
                if let error = generationError {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - 配置视图
    
    private var configurationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 产品选择
                productSelectionSection
                
                // 模板选择
                templateSelectionSection
                
                // 生成配置
                generationConfigSection
                
                // 预览信息
                if selectedProduct != nil {
                    previewSection
                }
            }
            .padding()
        }
    }
    
    // MARK: - 产品选择区域
    
    private var productSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择产品")
                .font(.headline)
                .fontWeight(.semibold)
            
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索产品...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ModernColors.System.gray6)
            .cornerRadius(10)
            
            // 产品列表
            LazyVStack(spacing: 8) {
                ForEach(filteredProducts.prefix(5), id: \.self) { product in
                    ProductSelectionRow(
                        product: product,
                        isSelected: selectedProduct == product
                    ) {
                        selectedProduct = product
                    }
                }
                
                if filteredProducts.count > 5 {
                    Text("显示前5个结果，请使用搜索缩小范围")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 模板选择区域
    
    private var templateSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("指南模板")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("选择模板") {
                    showingTemplateSelector = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if let template = selectedTemplate {
                TemplatePreviewCard(template: template)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.below.ecg")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("未选择模板")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("将使用默认模板生成指南")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ModernColors.System.gray6)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 生成配置区域
    
    private var generationConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("生成配置")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Toggle("包含技术规格", isOn: $generationConfig.includeSpecifications)
                Toggle("包含故障排除", isOn: $generationConfig.includeTroubleshooting)
                
                HStack {
                    Text("最大章节长度")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Picker("", selection: $generationConfig.maxSectionLength) {
                        Text("500字").tag(500)
                        Text("1000字").tag(1000)
                        Text("1500字").tag(1500)
                        Text("2000字").tag(2000)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 预览区域
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("生成预览")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let product = selectedProduct {
                VStack(alignment: .leading, spacing: 8) {
                    Text("将为以下产品生成使用指南：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.productName)
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            if !product.productBrand.isEmpty {
                                Text(product.productBrand)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(product.productManuals.count) 个说明书")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            let processedCount = product.productManuals.filter { $0.isOCRProcessed }.count
                            Text("\(processedCount) 个已处理")
                                .font(.caption)
                                .foregroundColor(processedCount > 0 ? .green : .red)
                        }
                    }
                    
                    if !canGenerate {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("该产品没有已处理的说明书，无法生成指南")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(ModernColors.Background.primary)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 生成进度视图
    
    private var generationProgressView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                ProgressView(value: guideService.generationProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)
                
                Text("正在生成使用指南...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(Int(guideService.generationProgress * 100))% 完成")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let product = selectedProduct {
                    Text("为 \(product.productName) 生成指南")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(30)
            .background(ModernColors.Background.primary)
            .cornerRadius(16)
            .shadow(radius: 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ModernColors.Background.secondary)
    }
    
    // MARK: - 生成指南
    
    private func generateGuide() {
        guard let product = selectedProduct else { return }
        
        isGenerating = true
        
        Task {
            do {
                let guide = try await guideService.generateUsageGuide(for: product)
                
                await MainActor.run {
                    isGenerating = false
                    generatedGuide = guide
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    generationError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - 产品选择行
struct ProductSelectionRow: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 选择指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.productName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if !product.productBrand.isEmpty {
                        Text(product.productBrand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(product.productManuals.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Text("说明书")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? ModernColors.System.gray6.opacity(0.1) : ModernColors.System.gray6)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 模板预览卡片
struct TemplatePreviewCard: View {
    let template: GuideTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(template.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ModernColors.System.gray5)
                    .cornerRadius(6)
            }
            
            Text("\(template.sections.count) 个章节")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(ModernColors.System.gray6)
        .cornerRadius(8)
    }
}

// MARK: - 预览
struct GuideGenerationView_Previews: PreviewProvider {
    static var previews: some View {
        GuideGenerationView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
