import SwiftUI
import CoreData

struct DataExportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedExportType = ExportType.csv
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var isExporting = false
    
    enum ExportType: String, CaseIterable {
        case csv = "CSV"
        case pdf = "PDF"
        case json = "JSON"
    }
    
    var body: some View {
        Form {
            Section(header: Text("导出格式")) {
                Picker("格式", selection: $selectedExportType) {
                    ForEach(ExportType.allCases, id: \.self) { type in
                        Text(type.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section {
                Button(action: exportData) {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("导出数据")
                        }
                    }
                }
                .disabled(isExporting)
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
        
        // 获取所有产品
        let request: NSFetchRequest<Product> = Product.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Product.updatedAt, ascending: false)]
        
        do {
            let products = try viewContext.fetch(request)
            
            // 根据选择的格式导出数据
            let data: Data?
            let ext: String
            
            switch selectedExportType {
            case .csv:
                data = ExportService.exportToCSV(products: products)
                ext = "csv"
            case .pdf:
                data = ExportService.exportToPDF(products: products)
                ext = "pdf"
            case .json:
                data = ExportService.exportToJSON(products: products)
                ext = "json"
            }
            
            if let exportData = data,
               let url = ExportService.saveFile(
                exportData,
                name: "ManualBox_Export_\(Date().formatted(.iso8601))",
                ext: ext
               ) {
                exportURL = url
                showShareSheet = true
            }
        } catch {
            print("导出失败: \(error.localizedDescription)")
        }
        
        isExporting = false
    }
}

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
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