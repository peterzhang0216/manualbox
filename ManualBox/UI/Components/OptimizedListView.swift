import SwiftUI
import Combine

// MARK: - 虚拟化列表配置
struct VirtualizedListConfiguration {
    let itemHeight: CGFloat
    let bufferSize: Int
    let enablePrefetching: Bool
    let enableRecycling: Bool
    let updateThreshold: Int
    
    static let `default` = VirtualizedListConfiguration(
        itemHeight: 60,
        bufferSize: 10,
        enablePrefetching: true,
        enableRecycling: true,
        updateThreshold: 5
    )
}

// MARK: - 列表项标识符协议
protocol ListItemIdentifiable {
    var listItemID: String { get }
}

// MARK: - 优化的列表视图
struct OptimizedListView<Item: ListItemIdentifiable, Content: View>: View {
    let items: [Item]
    let configuration: VirtualizedListConfiguration
    let content: (Item) -> Content
    
    @State private var visibleRange: Range<Int> = 0..<0
    @State private var scrollOffset: CGFloat = 0
    @State private var containerHeight: CGFloat = 0
    @State private var recycledViews: [String: AnyView] = [:]
    
    // 性能监控
    @StateObject private var performanceMonitor = ListPerformanceMonitor()
    
    init(
        items: [Item],
        configuration: VirtualizedListConfiguration = .default,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.configuration = configuration
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleItems, id: \.listItemID) { item in
                            itemView(for: item)
                                .frame(height: configuration.itemHeight)
                                .id(item.listItemID)
                        }
                    }
                    .background(
                        GeometryReader { contentGeometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: contentGeometry.frame(in: .named("scroll")).minY
                                )
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = -value
                    updateVisibleRange()
                }
                .onAppear {
                    containerHeight = geometry.size.height
                    updateVisibleRange()
                }
                .onChange(of: geometry.size.height) { _, newHeight in
                    containerHeight = newHeight
                    updateVisibleRange()
                }
                .onChange(of: items.count) { _, _ in
                    updateVisibleRange()
                }
            }
        }
        .onAppear {
            performanceMonitor.startMonitoring()
        }
        .onDisappear {
            performanceMonitor.stopMonitoring()
        }
    }
    
    // MARK: - 私有方法
    
    private var visibleItems: [Item] {
        let startIndex = max(0, visibleRange.lowerBound)
        let endIndex = min(items.count, visibleRange.upperBound)
        
        guard startIndex < endIndex else { return [] }
        
        return Array(items[startIndex..<endIndex])
    }
    
    private func itemView(for item: Item) -> some View {
        let view: AnyView

        if configuration.enableRecycling,
           let recycledView = recycledViews[item.listItemID] {
            view = recycledView
        } else {
            let newView = AnyView(content(item))
            if configuration.enableRecycling {
                recycledViews[item.listItemID] = newView
            }
            view = newView
        }

        return view
            .onAppear {
                performanceMonitor.recordItemAppear()
            }
            .onDisappear {
                performanceMonitor.recordItemDisappear()
            }
    }
    
    private func updateVisibleRange() {
        let itemsPerScreen = Int(ceil(containerHeight / configuration.itemHeight))
        let firstVisibleIndex = Int(scrollOffset / configuration.itemHeight)
        
        let bufferStart = max(0, firstVisibleIndex - configuration.bufferSize)
        let bufferEnd = min(items.count, firstVisibleIndex + itemsPerScreen + configuration.bufferSize)
        
        let newRange = bufferStart..<bufferEnd
        
        if newRange != visibleRange {
            visibleRange = newRange
            performanceMonitor.recordRangeUpdate(range: newRange)
            
            // 清理不再可见的回收视图
            if configuration.enableRecycling {
                cleanupRecycledViews()
            }
        }
    }
    
    private func cleanupRecycledViews() {
        let visibleIDs = Set(visibleItems.map(\.listItemID))
        recycledViews = recycledViews.filter { visibleIDs.contains($0.key) }
    }
}

// MARK: - 智能更新列表视图
struct SmartUpdateListView<Item: ListItemIdentifiable & Equatable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    
    @State private var previousItems: [Item] = []
    @State private var changedItems: Set<String> = []
    @State private var updateCounter = 0
    
    init(
        items: [Item],
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.content = content
    }
    
    var body: some View {
        List {
            ForEach(items, id: \.listItemID) { item in
                SmartUpdateItemView(
                    item: item,
                    hasChanged: changedItems.contains(item.listItemID),
                    content: content
                )
            }
        }
        .onChange(of: items) { oldItems, newItems in
            detectChanges(from: oldItems, to: newItems)
        }
        .onAppear {
            previousItems = items
        }
    }
    
    private func detectChanges(from oldItems: [Item], to newItems: [Item]) {
        let oldItemsDict = Dictionary(uniqueKeysWithValues: oldItems.map { ($0.listItemID, $0) })
        let newItemsDict = Dictionary(uniqueKeysWithValues: newItems.map { ($0.listItemID, $0) })
        
        var newChangedItems: Set<String> = []
        
        for (id, newItem) in newItemsDict {
            if let oldItem = oldItemsDict[id], oldItem != newItem {
                newChangedItems.insert(id)
            } else if oldItemsDict[id] == nil {
                // 新增项
                newChangedItems.insert(id)
            }
        }
        
        changedItems = newChangedItems
        previousItems = newItems
        
        // 清理变更标记
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            changedItems.removeAll()
        }
    }
}

// MARK: - 智能更新项视图
struct SmartUpdateItemView<Item: ListItemIdentifiable, Content: View>: View {
    let item: Item
    let hasChanged: Bool
    let content: (Item) -> Content
    
    @State private var isHighlighted = false
    
    var body: some View {
        content(item)
            .background(
                hasChanged ? Color.blue.opacity(0.1) : Color.clear
            )
            .animation(.easeInOut(duration: 0.3), value: hasChanged)
            .onChange(of: hasChanged) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHighlighted = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHighlighted = false
                        }
                    }
                }
            }
    }
}

// MARK: - 分页列表视图
struct PaginatedListView<Item: ListItemIdentifiable, Content: View>: View {
    @Binding var items: [Item]
    let pageSize: Int
    let loadMore: () async -> [Item]
    let content: (Item) -> Content
    
    @State private var isLoading = false
    @State private var hasMorePages = true
    
    init(
        items: Binding<[Item]>,
        pageSize: Int = 20,
        loadMore: @escaping () async -> [Item],
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self._items = items
        self.pageSize = pageSize
        self.loadMore = loadMore
        self.content = content
    }
    
    var body: some View {
        List {
            ForEach(items, id: \.listItemID) { item in
                content(item)
                    .onAppear {
                        if item.listItemID == items.last?.listItemID && hasMorePages && !isLoading {
                            loadMoreItems()
                        }
                    }
            }
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("加载更多...")
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    private func loadMoreItems() {
        guard !isLoading && hasMorePages else { return }
        
        isLoading = true
        
        Task {
            let newItems = await loadMore()
            
            await MainActor.run {
                if newItems.count < pageSize {
                    hasMorePages = false
                }
                
                items.append(contentsOf: newItems)
                isLoading = false
            }
        }
    }
}

// MARK: - 性能监控
class ListPerformanceMonitor: ObservableObject {
    @Published var itemsAppeared = 0
    @Published var itemsDisappeared = 0
    @Published var rangeUpdates = 0
    @Published var averageRenderTime: TimeInterval = 0
    
    private var renderTimes: [TimeInterval] = []
    private var startTime: CFAbsoluteTime = 0
    
    func startMonitoring() {
        startTime = CFAbsoluteTimeGetCurrent()
    }
    
    func stopMonitoring() {
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        print("[ListPerformance] 总渲染时间: \(totalTime)s, 项目出现: \(itemsAppeared), 范围更新: \(rangeUpdates)")
    }
    
    func recordItemAppear() {
        itemsAppeared += 1
    }
    
    func recordItemDisappear() {
        itemsDisappeared += 1
    }
    
    func recordRangeUpdate(range: Range<Int>) {
        rangeUpdates += 1
    }
    
    func recordRenderTime(_ time: TimeInterval) {
        renderTimes.append(time)
        if renderTimes.count > 100 {
            renderTimes.removeFirst()
        }
        averageRenderTime = renderTimes.reduce(0, +) / Double(renderTimes.count)
    }
}

// MARK: - 辅助类型

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 便捷扩展

extension View {
    func optimizedList<Item: ListItemIdentifiable>(
        items: [Item],
        configuration: VirtualizedListConfiguration = .default
    ) -> some View where Self == OptimizedListView<Item, AnyView> {
        OptimizedListView(items: items, configuration: configuration) { _ in
            AnyView(self)
        }
    }
}
