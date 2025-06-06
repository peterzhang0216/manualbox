import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct DataImportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isImporting = false
    @State private var showFileImporter = false
    @State private var importStatus: ImportStatus = .idle
    @State private var importedItemsCount = 0
    
    enum ImportStatus {
        case idle
        case importing
        case success(Int) // 成功导入的数量
        case error(String) // 错误信息
        
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
    }
    
    var body: some View {
        Form {
            Section(header: Text("从文件导入")) {
                Button(action: {
                    showFileImporter = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("选择导入文件")
                    }
                }
                .disabled(isImporting)
                
                if isImporting {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("正在导入...")
                    }
                }
                
                if importStatus.isSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("成功导入\(importedItemsCount)个商品")
                    }
                }
                
                if importStatus.isError, case .error(let message) = importStatus {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(message)
                    }
                }
            }
            
            Section(header: Text("支持的格式"), footer: Text("导入将添加新商品，而不会替换现有数据")) {
                Label("CSV 文件", systemImage: "doc.text")
                    .font(.subheadline)
                Label("JSON 备份", systemImage: "doc.badge.gearshape")
                    .font(.subheadline)
            }
        }
        .navigationTitle("数据导入")
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .json],
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
    }
    
    private func importFile(from url: URL) {
        isImporting = true
        importStatus = .importing
        
        Task {
            do {
                // 根据文件类型选择不同的导入策略
                let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
                
                if contentType == UTType.commaSeparatedText {
                    // 导入CSV
                    let count = try await ImportService.importFromCSV(url: url, context: viewContext)
                    await MainActor.run {
                        importedItemsCount = count
                        importStatus = .success(count)
                    }
                } else if contentType == UTType.json {
                    // 导入JSON
                    let count = try await ImportService.importFromJSON(url: url, context: viewContext)
                    await MainActor.run {
                        importedItemsCount = count
                        importStatus = .success(count)
                    }
                } else {
                    await MainActor.run {
                        importStatus = .error("不支持的文件格式")
                    }
                }
            } catch {
                await MainActor.run {
                    importStatus = .error("导入失败: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isImporting = false
            }
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
