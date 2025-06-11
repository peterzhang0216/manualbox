//
//  ProductFilterView.swift
//  ManualBox
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import SwiftUI
import CoreData

struct ProductFilterView: View {
    @ObservedObject var viewModel: ProductListViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // 搜索栏
            searchBar
            
            // 工具栏
            toolBar
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        #if os(macOS)
        .background(Color(.windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("搜索产品、品牌、型号...", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.send(.updateSearchText($0)) }
            ))
                .textFieldStyle(.plain)
            
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.send(.updateSearchText(""))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        #if os(macOS)
        .background(Color(.controlBackgroundColor))
        #else
        .background(Color(.systemGray6))
        #endif
        .cornerRadius(10)
    }
    
    private var toolBar: some View {
        HStack {
            // 筛选按钮
            Button {
                viewModel.send(.toggleFilters)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("筛选")
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            // 排序选择
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        viewModel.send(.updateSort(option))
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if viewModel.selectedSort == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(viewModel.selectedSort.rawValue)
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            // 视图样式切换
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    let newStyle: ViewStyle = viewModel.viewStyle == .list ? .grid : .list
                    viewModel.send(.updateViewStyle(newStyle))
                }
            } label: {
                Image(systemName: viewModel.viewStyle.icon)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
    }
}

// FilterView is now defined in FilterView.swift to avoid duplication