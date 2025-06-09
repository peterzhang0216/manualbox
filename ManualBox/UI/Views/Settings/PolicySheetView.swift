import SwiftUI
import WebKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - 政策展示视图
struct PolicySheetView: View {
    let title: String
    let url: URL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            WebView(url: url)
                .navigationTitle(title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    SwiftUI.ToolbarItem(placement: .primaryAction) {
                        Button(NSLocalizedString("Done", comment: "")) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - WebView 包装器
#if os(iOS)
struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 不需要更新
    }
}
#elseif os(macOS)
struct WebView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 不需要更新
    }
}
#endif

#Preview {
    PolicySheetView(
        title: "Privacy Policy",
        url: URL(string: "https://example.com/privacy")!
    )
}