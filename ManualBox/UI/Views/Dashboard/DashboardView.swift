//
//  DashboardView.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import SwiftUI
import Charts

// MARK: - 数据统计仪表板
struct DashboardView: View {
    @ObservedObject private var statisticsService = StatisticsService.shared
    @State private var selectedTimeRange: StatisticsTimeRange = .month
    @State private var selectedCardTypes: Set<StatisticCardType> = Set(StatisticCardType.allCases)
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if statisticsService.isLoading {
                        loadingView
                    } else if let stats = statisticsService.dashboardStats {
                        dashboardContent(stats)
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("数据统计")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProductUsageAnalysisView()) {
                        Image(systemName: "chart.bar.doc.horizontal")
                    }

                    Button("刷新") {
                        Task {
                            await statisticsService.refreshStatistics()
                        }
                    }

                    Button("设置") {
                        showingSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                dashboardSettingsView
            }
            .refreshable {
                await statisticsService.refreshStatistics()
            }
        }
        .onAppear {
            if statisticsService.dashboardStats == nil {
                Task {
                    await statisticsService.refreshStatistics()
                }
            }
        }
    }
}

// MARK: - 预览
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}