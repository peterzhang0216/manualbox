//
//  ProductDetailPlaceholderView.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct ProductDetailPlaceholderView: View {
    private var backgroundColorForPlatform: Color {
#if os(iOS)
        Color(UIColor.systemBackground).opacity(0.7)
#else
        Color(NSColor.controlBackgroundColor).opacity(0.7)
#endif
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "shippingbox.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            Text("请选择一个产品")
                .font(.title2)
                .bold()
            Text("在左侧选择或新建一个产品以查看详情")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColorForPlatform)
        .navigationTitle("产品详情")
    }
}