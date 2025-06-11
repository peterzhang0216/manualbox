//
//  SearchBarView.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import SwiftUI
import CoreData

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var searchFilters: SearchFilters
    @Binding var showingFilterSheet: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
#if os(iOS)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索产品...", text: $searchText)
                        .submitLabel(.search)
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: {
                        showingFilterSheet = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(searchFilters.hasActiveFilters ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
#else
                // macOS 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索产品...", text: $searchText)
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: {
                        showingFilterSheet = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(searchFilters.hasActiveFilters ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)
#endif
            }
            // 如果有活跃的筛选器，显示筛选器摘要
            if searchFilters.hasActiveFilters {
                HStack {
                    Text("筛选条件:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(searchFilters.filterDescription)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Spacer()
                    Button(action: {
                        searchFilters = SearchFilters()
                    }) {
                        Text("清除")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            SearchFilterView(searchFilters: $searchFilters)
        }
    }
}