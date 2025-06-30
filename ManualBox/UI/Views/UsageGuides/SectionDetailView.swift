//
//  SectionDetailView.swift
//  ManualBox
//
//  Created by Assistant on 2025/6/24.
//

import SwiftUI

// MARK: - 章节详情视图
struct SectionDetailView: View {
    let section: GuideSection
    let guide: ProductUsageGuide
    @Environment(\.dismiss) private var dismiss
    @State private var fontSize: CGFloat = 16
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 章节头部
                    sectionHeader
                    
                    // 章节内容
                    sectionContent
                }
                .padding()
            }
            .navigationTitle(section.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button(action: {
                            fontSize = max(12, fontSize - 2)
                        }) {
                            Label("缩小字体", systemImage: "textformat.size.smaller")
                        }

                        Button(action: {
                            fontSize = min(24, fontSize + 2)
                        }) {
                            Label("放大字体", systemImage: "textformat.size.larger")
                        }

                        Divider()

                        Button(action: {
                            showingShareSheet = true
                        }) {
                            Label("分享章节", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }

                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("编辑") {
                        showingEditSheet = true
                    }
                }
            }
            #endif
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [generateSectionShareContent()])
            }
        }
    }
    
    // MARK: - 章节头部
    
    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: section.type.icon)
                    .font(.title)
                    .foregroundColor(Color(section.type.color))
                    .frame(width: 50, height: 50)
                    .background(Color(section.type.color).opacity(0.1))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(section.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 章节信息
            HStack {
                InfoChip(
                    icon: "list.bullet",
                    text: "\(section.content.count) 项内容",
                    color: .blue
                )
                
                InfoChip(
                    icon: "doc.text",
                    text: "\(section.formattedContent.count) 字",
                    color: .green
                )
                
                Spacer()
            }
        }
        .padding()
        #if os(iOS)
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(.windowBackgroundColor))
        #endif
        #else
        .background(Color(.windowBackgroundColor))
        #endif
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    // MARK: - 章节内容
    
    private var sectionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("内容详情")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(section.content.enumerated()), id: \.offset) { index, content in
                    ContentItem(
                        index: index + 1,
                        content: content,
                        fontSize: fontSize
                    )
                }
            }
        }
        .padding()
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(.windowBackgroundColor))
        #endif
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    // MARK: - 分享内容生成
    
    private func generateSectionShareContent() -> String {
        return """
        \(guide.title) - \(section.title)
        
        \(section.formattedContent)
        
        ---
        来自 ManualBox 使用指南
        """
    }
}

// MARK: - 信息标签
struct InfoChip: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 内容项
struct ContentItem: View {
    let index: Int
    let content: String
    let fontSize: CGFloat
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 序号
            Text("\(index)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .cornerRadius(12)
            
            // 内容
            Text(content)
                .font(.system(size: fontSize))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
        #if os(iOS)
        .background(Color(.systemGray6))
        #else
        .background(Color(.controlBackgroundColor))
        #endif
        .cornerRadius(12)
    }
}

// MARK: - 模板选择视图
struct TemplateSelectionView: View {
    @Binding var selectedTemplate: GuideTemplate?
    @Environment(\.dismiss) private var dismiss
    
    private let templates = GuideTemplate.defaultTemplates
    
    var body: some View {
        NavigationView {
            List {
                ForEach(templates, id: \.id) { template in
                    TemplateRow(
                        template: template,
                        isSelected: selectedTemplate?.id == template.id
                    ) {
                        selectedTemplate = template
                        dismiss()
                    }
                }
            }
            .navigationTitle("选择模板")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
}

// MARK: - 模板行
struct TemplateRow: View {
    let template: GuideTemplate
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(template.category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(template.sections.count) 个章节")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 批量生成视图
struct BatchGuideGenerationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guideService = UsageGuideGenerationService.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Product.name, ascending: true)],
        animation: .default
    ) private var products: FetchedResults<Product>
    
    @State private var selectedProducts: Set<Product> = []
    @State private var isGenerating = false
    @State private var generatedGuides: [ProductUsageGuide] = []
    
    private var eligibleProducts: [Product] {
        return products.filter { product in
            !product.productManuals.isEmpty && product.productManuals.contains { $0.isOCRProcessed }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isGenerating {
                    batchGenerationProgressView
                } else {
                    productSelectionView
                }
            }
            .navigationTitle("批量生成指南")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("生成") {
                        generateBatchGuides()
                    }
                    .disabled(selectedProducts.isEmpty || isGenerating)
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("生成") {
                        generateBatchGuides()
                    }
                    .disabled(selectedProducts.isEmpty || isGenerating)
                }
            }
            #endif
        }
    }
    
    // MARK: - 产品选择视图
    
    private var productSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 选择统计
            HStack {
                Text("已选择 \(selectedProducts.count) / \(eligibleProducts.count) 个产品")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(selectedProducts.count == eligibleProducts.count ? "取消全选" : "全选") {
                    if selectedProducts.count == eligibleProducts.count {
                        selectedProducts.removeAll()
                    } else {
                        selectedProducts = Set(eligibleProducts)
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            // 产品列表
            List {
                ForEach(eligibleProducts, id: \.self) { product in
                    BatchProductRow(
                        product: product,
                        isSelected: selectedProducts.contains(product)
                    ) {
                        if selectedProducts.contains(product) {
                            selectedProducts.remove(product)
                        } else {
                            selectedProducts.insert(product)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 批量生成进度视图
    
    private var batchGenerationProgressView: some View {
        VStack(spacing: 20) {
            Text("正在批量生成指南...")
                .font(.headline)
            
            ProgressView(value: guideService.generationProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 250)
            
            Text("\(Int(guideService.generationProgress * 100))% 完成")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("已生成 \(generatedGuides.count) / \(selectedProducts.count) 个指南")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(30)
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(.windowBackgroundColor))
        #endif
        .cornerRadius(16)
        .shadow(radius: 4)
    }
    
    // MARK: - 批量生成
    
    private func generateBatchGuides() {
        isGenerating = true
        generatedGuides.removeAll()
        
        Task {
            do {
                let guides = try await guideService.generateUsageGuides(for: Array(selectedProducts))
                
                await MainActor.run {
                    isGenerating = false
                    generatedGuides = guides
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }
}

// MARK: - 批量产品行
struct BatchProductRow: View {
    let product: Product
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.productName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(product.productManuals.count) 个说明书")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 预览
struct SectionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SectionDetailView(
            section: GuideSection(
                id: UUID(),
                title: "基本操作",
                type: .basicOperations,
                priority: 1,
                content: ["第一步：开机", "第二步：设置", "第三步：使用"]
            ),
            guide: ProductUsageGuide(
                id: UUID(),
                productId: UUID(),
                productName: "测试产品",
                title: "测试指南",
                subtitle: "测试副标题",
                sections: [],
                estimatedReadingTime: 10,
                difficultyLevel: .beginner,
                generatedAt: Date(),
                version: "1.0",
                language: "zh-CN"
            )
        )
    }
}
