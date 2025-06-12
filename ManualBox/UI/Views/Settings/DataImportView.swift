import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct DataImportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isImporting = false
    @State private var showFileImporter = false
    @State private var showBatchImporter = false
    @State private var importStatus: ImportStatus = .idle
    @State private var importedItemsCount = 0
    @State private var selectedImportType = ImportType.auto
    @State private var showImportOptions = false
    @State private var replaceExisting = false
    @State private var importProgress: Double = 0.0
    
    enum ImportType: String, CaseIterable {
        case auto = "自动检测"
        case csv = "CSV 文件"
        case json = "JSON 备份"
        case fullBackup = "完整备份"
    }
    
    enum ImportStatus: Equatable {
        case idle
        case importing
        case success(Int) // 成功导入的数量
        case error(String) // 错误信息
        case warning(String, Int) // 警告信息和成功数量
        
        var isError: Bool {
            if case .error(_) = self {
                return true
            }
            return false
        }
        
        var isSuccess: Bool {
            if case .success(_) = self {
                return true
            }
            return false
        }
        
        var isWarning: Bool {
            if case .warning(_, _) = self {
                return true
            }
            return false
        }
        
        static func == (lhs: ImportStatus, rhs: ImportStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.importing, .importing):
                return true
            case (.success(let count1), .success(let count2)):
                return count1 == count2
            case (.error(let msg1), .error(let msg2)):
                return msg1 == msg2
            case (.warning(let msg1, let count1), .warning(let msg2, let count2)):
                return msg1 == msg2 && count1 == count2
            default:
                return false
            }
        }
    }
    
    var body: some View {
        Form {
            // 导入选项配置
            Section(header: Text("导入设置")) {
                Picker("导入类型", selection: $selectedImportType) {
                    ForEach(ImportType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                
                Toggle("替换现有数据", isOn: $replaceExisting)
                    .help("开启后将替换同名商品，关闭后将跳过重复项")
            }
            
            // 单文件导入
            Section(header: Text("从文件导入")) {
                Button(action: {
                    showFileImporter = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("选择导入文件")
                        Spacer()
                        if selectedImportType != .auto {
                            Text(selectedImportType.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(isImporting)
                
                // 批量导入选项
                Button(action: {
                    showBatchImporter = true
                }) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("批量导入文件")
                        Spacer()
                        Text("多文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(isImporting)
            }
            
            // 导入状态显示
            if isImporting || importStatus != .idle {
                Section(header: Text("导入状态")) {
                    if isImporting {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                                Text("正在导入...")
                                Spacer()
                                Text("\(Int(importProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if importProgress > 0 {
                                ProgressView(value: importProgress)
                                    .progressViewStyle(.linear)
                            }
                        }
                    }
                    
                    if importStatus.isSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("导入成功")
                                    .font(.headline)
                                Text("成功导入 \(importedItemsCount) 个商品")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    
                    if importStatus.isWarning, case .warning(let message, let count) = importStatus {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("部分成功")
                                    .font(.headline)
                                Text("成功导入 \(count) 个商品")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                        }
                    }
                    
                    if importStatus.isError, case .error(let message) = importStatus {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading) {
                                Text("导入失败")
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
            
            // 支持格式说明
            Section(header: Text("支持的格式"), footer: Text(footerText)) {
                Label("CSV 文件 (.csv)", systemImage: "doc.text")
                    .font(.subheadline)
                Label("JSON 备份 (.json)", systemImage: "doc.badge.gearshape")
                    .font(.subheadline)
                Label("完整备份 (.manualbox)", systemImage: "externaldrive")
                    .font(.subheadline)
            }
        }
        .navigationTitle("数据导入")
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importFile(from: url)
                }
            case .failure(let error):
                importStatus = .error("文件选择失败: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $showBatchImporter,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                importBatchFiles(urls: urls)
            case .failure(let error):
                importStatus = .error("批量文件选择失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var allowedContentTypes: [UTType] {
        switch selectedImportType {
        case .auto:
            return [.commaSeparatedText, .json, UTType("com.manualbox.backup") ?? .data]
        case .csv:
            return [.commaSeparatedText]
        case .json:
            return [.json]
        case .fullBackup:
            return [UTType("com.manualbox.backup") ?? .data]
        }
    }
    
    private var footerText: String {
        if replaceExisting {
            return "导入时将替换同名商品。请谨慎使用此选项。"
        } else {
            return "导入将添加新商品，跳过重复项。现有数据不会被修改。"
        }
    }
    
    // MARK: - Import Methods
    
    private func importFile(from url: URL) {
        isImporting = true
        importStatus = .importing
        importProgress = 0.0
        
        Task {
            do {
                updateProgress(0.1)
                
                // 根据文件类型或用户选择确定导入策略
                let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
                let importType = selectedImportType == .auto ? detectImportType(contentType: contentType) : selectedImportType
                
                updateProgress(0.2)
                
                var count = 0
                var warnings: [String] = []
                
                let result: ImportResult
                
                switch importType {
                case .csv:
                    result = try await ImportService.importFromCSV(
                        url: url,
                        context: viewContext,
                        replaceExisting: replaceExisting,
                        progressCallback: { progress in
                            Task { @MainActor in
                                importProgress = 0.2 + progress * 0.7
                            }
                        },
                        warningCallback: { newWarnings in
                            Task { @MainActor in
                                warnings.append(contentsOf: newWarnings)
                            }
                        }
                    )
                    
                case .json:
                    result = try await ImportService.importFromJSON(
                        url: url,
                        context: viewContext,
                        replaceExisting: replaceExisting,
                        progressCallback: { progress in
                            Task { @MainActor in
                                importProgress = 0.2 + progress * 0.7
                            }
                        },
                        warningCallback: { newWarnings in
                            Task { @MainActor in
                                warnings.append(contentsOf: newWarnings)
                            }
                        }
                    )
                    
                case .fullBackup:
                    result = try await ImportService.importFullBackup(
                        url: url,
                        context: viewContext,
                        progressCallback: { progress in
                            Task { @MainActor in
                                importProgress = 0.2 + progress * 0.7
                            }
                        },
                        warningCallback: { newWarnings in
                            Task { @MainActor in
                                warnings.append(contentsOf: newWarnings)
                            }
                        }
                    )
                    
                case .auto:
                    // 这种情况不应该发生，因为已经检测了类型
                    throw ImportService.ImportError.invalidFormat
                }
                
                count = result.importedCount
                warnings.append(contentsOf: result.warnings)
                
                updateProgress(1.0)
                
                await MainActor.run {
                    importedItemsCount = count
                    if warnings.isEmpty {
                        importStatus = .success(count)
                    } else {
                        importStatus = .warning(warnings.joined(separator: "; "), count)
                    }
                }
                
            } catch {
                await MainActor.run {
                    importStatus = .error("导入失败: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isImporting = false
                importProgress = 0.0
            }
        }
    }
    
    private func importBatchFiles(urls: [URL]) {
        isImporting = true
        importStatus = .importing
        importProgress = 0.0
        
        Task {
            do {
                updateProgress(0.1)
                
                let result = try await ImportService.importBatchFiles(
                    urls: urls,
                    context: viewContext,
                    replaceExisting: replaceExisting,
                    progressCallback: { progress in
                        Task { @MainActor in
                            importProgress = 0.1 + progress * 0.9
                        }
                    },
                    warningCallback: { warnings in
                        // 警告会在最后统一处理
                    }
                )
                
                updateProgress(1.0)
                
                await MainActor.run {
                    importedItemsCount = result.importedCount
                    if result.warnings.isEmpty {
                        importStatus = .success(result.importedCount)
                    } else {
                        importStatus = .warning(result.warnings.joined(separator: "; "), result.importedCount)
                    }
                }
                
            } catch {
                await MainActor.run {
                    importStatus = .error("批量导入失败: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isImporting = false
                importProgress = 0.0
            }
        }
    }
    

    
    private func detectImportType(contentType: UTType?) -> ImportType {
        guard let contentType = contentType else { return .csv }
        
        if contentType == UTType.commaSeparatedText {
            return .csv
        } else if contentType == UTType.json {
            return .json
        } else {
            return .csv // 默认尝试CSV
        }
    }
    
    @MainActor
    private func updateProgress(_ progress: Double) {
        importProgress = progress
    }
}

// MARK: - Import Error
enum ImportError: LocalizedError {
    case unsupportedFormat
    case fileNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "不支持的文件格式"
        case .fileNotFound:
            return "文件未找到"
        case .invalidData:
            return "文件数据无效"
        }
    }
}

extension UTType {
    static let commaSeparatedText = UTType(exportedAs: "public.comma-separated-values-text")
}

#Preview {
    NavigationView {
        DataImportView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
