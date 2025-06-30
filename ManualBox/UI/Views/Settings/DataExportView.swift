import SwiftUI
import CoreData

struct DataExportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedExportType = ExportType.csv
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var includeCategories = true
    @State private var includeTags = true
    @State private var includeRepairRecords = true
    @State private var includeImages = false
    @State private var selectedDateRange = DateRange.all
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var exportStatus: ExportStatus = .idle
    
    enum ExportType: String, CaseIterable {
        case csv = "CSV"
        case pdf = "PDF"
        case json = "JSON"
        case fullBackup = "完整备份"
        
        var description: String {
            switch self {
            case .csv:
                return "表格格式，适合Excel等软件打开"
            case .pdf:
                return "PDF文档，适合打印和分享"
            case .json:
                return "结构化数据，适合程序处理"
            case .fullBackup:
                return "包含所有数据的完整备份文件"
            }
        }
    }
    
    enum DateRange: String, CaseIterable {
        case all = "全部"
        case lastMonth = "最近一个月"
        case lastThreeMonths = "最近三个月"
        case lastYear = "最近一年"
        case custom = "自定义范围"
    }
    
    enum ExportStatus {
        case idle
        case exporting
        case success(URL)
        case error(String)
        
        var isSuccess: Bool {
            if case .success(_) = self {
                return true
            }
            return false
        }
        
        var isError: Bool {
            if case .error(_) = self {
                return true
            }
            return false
        }
        
        static func == (lhs: ExportStatus, rhs: ExportStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.exporting, .exporting):
                return true
            case (.success, .success):
                return true
            case (.error, .error):
                return true
            default:
                return false
            }
        }
        
        static func != (lhs: ExportStatus, rhs: ExportStatus) -> Bool {
            return !(lhs == rhs)
        }
    }
    
    var body: some View {
        Form {
            // 导出格式选择
            Section(header: Text("导出格式")) {
                Picker("格式", selection: $selectedExportType) {
                    ForEach(ExportType.allCases, id: \.self) { type in
                        VStack(alignment: .leading) {
                            Text(type.rawValue)
                                .font(.headline)
                            Text(type.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // 数据范围选择
            Section(header: Text("数据范围")) {
                Picker("时间范围", selection: $selectedDateRange) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
                
                if selectedDateRange == .custom {
                    DatePicker("开始日期", selection: $customStartDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $customEndDate, displayedComponents: .date)
                }
            }
            
            // 包含内容选择
            Section(header: Text("包含内容")) {
                Toggle("分类信息", isOn: $includeCategories)
                Toggle("标签信息", isOn: $includeTags)
                Toggle("维修记录", isOn: $includeRepairRecords)
                Toggle("产品图片", isOn: $includeImages)
                    .help("包含图片会显著增加文件大小")
            }
            
            // 导出操作
            Section {
                Button(action: exportData) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        
                        VStack(alignment: .leading) {
                            Text(isExporting ? "正在导出..." : "导出数据")
                                .font(.headline)
                            if isExporting {
                                Text("\(Int(exportProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .disabled(isExporting)
                
                if isExporting && exportProgress > 0 {
                    ProgressView(value: exportProgress)
                        .progressViewStyle(.linear)
                }
            }
            
            // 导出状态显示
            if exportStatus != .idle {
                Section(header: Text("导出状态")) {
                    if exportStatus.isSuccess, case .success(let url) = exportStatus {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("导出成功")
                                    .font(.headline)
                                Text("文件已保存到: \(url.lastPathComponent)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    
                    if exportStatus.isError, case .error(let message) = exportStatus {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading) {
                                Text("导出失败")
                                    .font(.headline)
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("数据导出")
        .sheet(isPresented: $showShareSheet, content: {
            if let url = exportURL {
                #if os(iOS)
                ShareSheet(activityItems: [url])
                #else
                ShareView(url: url)
                #endif
            }
        })
    }
    
    private func exportData() {
        isExporting = true
        exportStatus = .exporting
        exportProgress = 0.0
        
        Task {
            do {
                await updateProgress(0.1)
                
                // 获取过滤后的产品数据
                let products = try await fetchFilteredProducts()
                await updateProgress(0.3)
                
                // 根据选择的格式导出数据
                let data: Data?
                let ext: String
                let fileName: String
                
                switch selectedExportType {
                case .csv:
                    await updateProgress(0.4)
                    data = await exportToCSV(products: products)
                    ext = "csv"
                    fileName = "ManualBox_Products_\(dateStamp())"
                    
                case .pdf:
                    await updateProgress(0.4)
                    data = await exportToPDF(products: products)
                    ext = "pdf"
                    fileName = "ManualBox_Report_\(dateStamp())"
                    
                case .json:
                    await updateProgress(0.4)
                    data = await exportToJSON(products: products)
                    ext = "json"
                    fileName = "ManualBox_Backup_\(dateStamp())"
                    
                case .fullBackup:
                    await updateProgress(0.4)
                    let backupURL = try await exportFullBackup()
                    await updateProgress(1.0)
                    
                    await MainActor.run {
                        exportURL = backupURL
                        exportStatus = .success(backupURL)
                        showShareSheet = true
                        isExporting = false
                        exportProgress = 0.0
                    }
                    return
                }
                
                await updateProgress(0.8)
                
                guard let exportData = data else {
                    throw ExportError.dataGenerationFailed
                }
                
                let url = try await saveExportFile(data: exportData, fileName: fileName, ext: ext)
                await updateProgress(1.0)
                
                await MainActor.run {
                    exportURL = url
                    exportStatus = .success(url)
                    showShareSheet = true
                }
                
            } catch {
                await MainActor.run {
                    exportStatus = .error("导出失败: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isExporting = false
                exportProgress = 0.0
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchFilteredProducts() async throws -> [Product] {
        return try await viewContext.perform {
            let request: NSFetchRequest<Product> = Product.fetchRequest()
            
            // 添加日期过滤
            var predicates: [NSPredicate] = []
            
            switch self.selectedDateRange {
            case .lastMonth:
                let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                predicates.append(NSPredicate(format: "createdAt >= %@", oneMonthAgo as NSDate))
                
            case .lastThreeMonths:
                let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
                predicates.append(NSPredicate(format: "createdAt >= %@", threeMonthsAgo as NSDate))
                
            case .lastYear:
                let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
                predicates.append(NSPredicate(format: "createdAt >= %@", oneYearAgo as NSDate))
                
            case .custom:
                predicates.append(NSPredicate(format: "createdAt >= %@ AND createdAt <= %@", 
                                            self.customStartDate as NSDate, self.customEndDate as NSDate))
                
            case .all:
                break
            }
            
            if !predicates.isEmpty {
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }
            
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Product.updatedAt, ascending: false)]
            
            return try self.viewContext.fetch(request)
        }
    }
    
    private func exportToCSV(products: [Product]) async -> Data? {
        return ExportService.exportToCSV(products: products)
    }
    
    private func exportToPDF(products: [Product]) async -> Data? {
        return ExportService.exportToPDF(products: products)
    }
    
    private func exportToJSON(products: [Product]) async -> Data? {
        return ExportService.exportToJSON(products: products)
    }
    
    private func exportFullBackup() async throws -> URL {
        let exportService = DataExportService(persistentContainer: PersistenceController.shared.container)
        return try await exportService.exportFullDatabase()
    }
    
    private func saveExportFile(data: Data, fileName: String, ext: String) async throws -> URL {
        guard let url = ExportService.saveFile(data, name: fileName, ext: ext) else {
            throw ExportError.fileSaveFailed
        }
        return url
    }
    
    private func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
    
    @MainActor
    private func updateProgress(_ progress: Double) {
        exportProgress = progress
    }
}

// MARK: - Export Error
enum ExportError: LocalizedError {
    case dataGenerationFailed
    case fileSaveFailed
    case invalidConfiguration
    case encodingFailed
    case pdfGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .dataGenerationFailed:
            return "数据生成失败"
        case .fileSaveFailed:
            return "文件保存失败"
        case .invalidConfiguration:
            return "导出配置无效"
        case .encodingFailed:
            return "编码失败"
        case .pdfGenerationFailed:
            return "PDF生成失败"
        }
    }
}

#if os(iOS)
// ShareSheet 已在 UsageGuideDetailView.swift 中定义
#else
struct ShareView: View {
    let url: URL
    
    var body: some View {
        VStack {
            Text("文件已导出到：")
            Text(url.path)
                .textSelection(.enabled)
            
            Button("在访达中显示") {
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            }
            .padding()
        }
        .padding()
    }
}
#endif

#Preview {
    NavigationView {
        DataExportView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}