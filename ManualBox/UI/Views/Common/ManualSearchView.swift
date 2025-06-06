import SwiftUI
import CoreData
import PDFKit

struct ManualSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var searchResults: [Manual] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("搜索说明书内容...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                Group {
                    #if os(macOS)
                    Color(nsColor: .controlBackgroundColor)
                    #else
                    Color(uiColor: .systemGray6)
                    #endif
                }
            )
            .cornerRadius(10)
            .padding()
            
            if isSearching {
                ProgressView()
                    .progressViewStyle(.circular)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                ContentUnavailableView("未找到结果", 
                                     systemImage: "doc.text.magnifyingglass",
                                     description: Text("请尝试其他关键词"))
            } else {
                // 搜索结果列表
                List(searchResults) { manual in
                    NavigationLink {
                        if manual.isPDF {
                            PDFView(document: manual.getPDFDocument())
                        } else if manual.isImage {
                            if let image = PlatformImage(data: manual.fileData ?? Data()) {
                                ImageView(image: image)
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(manual.manualFileName)
                                    .font(.headline)
                                Spacer()
                                if let product = manual.product {
                                    Text(product.productName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let preview = manual.getPreviewText(for: searchText) {
                                Text(preview)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("说明书搜索")
        .onChange(of: searchText) { oldValue, newValue in
            if !newValue.isEmpty {
                performSearch()
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // 在后台线程执行搜索
        DispatchQueue.global(qos: .userInitiated).async {
            let results = Manual.searchManuals(in: viewContext, query: searchText)
            
            DispatchQueue.main.async {
                searchResults = results
                isSearching = false
            }
        }
    }
}

struct PDFView: View {
    let document: PDFKit.PDFDocument?
    
    var body: some View {
        if let document = document {
            PDFKitView(document: document)
        } else {
            ContentUnavailableView("无法加载PDF", 
                                 systemImage: "doc.text.fill",
                                 description: Text("文件可能已损坏或不存在"))
        }
    }
}

struct ImageView: View {
    let image: PlatformImage
    
    var body: some View {
        Image(platformImage: image)
            .resizable()
            .scaledToFit()
    }
}

#if os(iOS)
struct PDFKitView: UIViewRepresentable {
    let document: PDFKit.PDFDocument
    
    func makeUIView(context: Context) -> PDFKit.PDFView {
        let pdfView = PDFKit.PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFKit.PDFView, context: Context) {
        uiView.document = document
    }
}
#else
struct PDFKitView: NSViewRepresentable {
    let document: PDFKit.PDFDocument
    
    func makeNSView(context: Context) -> PDFKit.PDFView {
        let pdfView = PDFKit.PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFKit.PDFView, context: Context) {
        nsView.document = document
    }
}
#endif

#Preview {
    NavigationView {
        ManualSearchView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}