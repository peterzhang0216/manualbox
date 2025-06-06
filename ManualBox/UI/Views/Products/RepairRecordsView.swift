import SwiftUI
import CoreData

struct RepairRecordsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: RepairRecord.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \RepairRecord.date, ascending: false)],
        animation: .default
    ) private var repairRecords: FetchedResults<RepairRecord>
    
    @State private var searchText = ""
    
    // 计算过滤后的维修记录
    private var filteredRecords: [RepairRecord] {
        if searchText.isEmpty {
            return Array(repairRecords)
        } else {
            return repairRecords.filter { record in
                guard let details = record.details else { return false }
                let searchLower = searchText.lowercased()
                return details.lowercased().contains(searchLower)
            }
        }
    }
    
    // 按月份分组的维修记录
    private var groupedRecords: [String: [RepairRecord]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        
        var groups = [String: [RepairRecord]]()
        
        for record in filteredRecords {
            if let date = record.date {
                let key = formatter.string(from: date)
                if groups[key] == nil {
                    groups[key] = [record]
                } else {
                    groups[key]?.append(record)
                }
            }
        }
        
        return groups
    }
    
    // 排序后的月份键
    private var sortedMonthKeys: [String] {
        groupedRecords.keys.sorted { key1, key2 in
            // 解析年月并比较
            let parts1 = key1.components(separatedBy: "年")
            let parts2 = key2.components(separatedBy: "年")
            
            guard let year1 = Int(parts1[0]), let year2 = Int(parts2[0]) else { return false }
            
            if year1 != year2 {
                return year1 > year2 // 年份降序
            }
            
            // 比较月份
            let month1 = Int(parts1[1].replacingOccurrences(of: "月", with: "")) ?? 0
            let month2 = Int(parts2[1].replacingOccurrences(of: "月", with: "")) ?? 0
            
            return month1 > month2 // 月份降序
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索维修记录", text: $searchText)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
#if os(iOS)
                .background(Color(.secondarySystemBackground))
#else
                .background(Color(NSColor.windowBackgroundColor))
#endif
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if filteredRecords.isEmpty {
                    ContentUnavailableView {
                        Label("暂无维修记录", systemImage: "wrench.and.screwdriver")
                    } description: {
                        if searchText.isEmpty {
                            Text("您尚未添加任何维修记录")
                        } else {
                            Text("没有找到匹配的记录")
                        }
                    }
                } else {
                    List {
                        ForEach(sortedMonthKeys, id: \.self) { monthKey in
                            Section(header: Text(monthKey)) {
                                ForEach(groupedRecords[monthKey] ?? [], id: \.id) { record in
                                    NavigationLink(destination: RepairRecordDetailView(record: record)) {
                                        RepairRecordListItem(record: record)
                                    }
                                }
                            }
                        }
                    }
#if os(iOS)
                    .listStyle(.insetGrouped)
#else
                    .listStyle(SidebarListStyle())
#endif
                }
            }
            .navigationTitle("维修记录")
        }
    }
}

// 维修记录列表项视图
struct RepairRecordListItem: View {
    let record: RepairRecord
    
    var body: some View {
        HStack(spacing: 16) {
            // 日期圆形标签
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                VStack(spacing: 0) {
                    if let date = record.date {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 产品名称
                if let product = record.order?.product {
                    Text(product.productName)
                        .font(.headline)
                }
                
                // 维修详情
                Text(record.recordDetails)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 维修费用
            Text(record.formattedCost)
                .font(.callout)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    RepairRecordsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
