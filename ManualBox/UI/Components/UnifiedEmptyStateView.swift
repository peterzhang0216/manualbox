import SwiftUI

// MARK: - 统一空状态视图
struct UnifiedEmptyStateView: View {
    let type: EmptyStateType
    let title: String
    let description: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        type: EmptyStateType,
        title: String,
        description: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.type = type
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: UnifiedDesignSystem.Spacing.xl) {
            // 图标
            Image(systemName: type.iconName)
                .font(.system(size: 64, weight: .light))
                .foregroundColor(type.iconColor)
                .symbolRenderingMode(.hierarchical)
            
            // 文本内容
            VStack(spacing: UnifiedDesignSystem.Spacing.md) {
                Text(title)
                    .unifiedTitle(.title2)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .unifiedBody(.callout)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 300)
            
            // 操作按钮
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Label(actionTitle, systemImage: type.actionIcon)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, UnifiedDesignSystem.Spacing.xl)
                        .padding(.vertical, UnifiedDesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: UnifiedDesignSystem.CornerRadius.button)
                                .fill(UnifiedDesignSystem.Colors.primary)
                        )
                }
                .buttonStyle(.plain)
                .unifiedTouchTarget()
                .unifiedHover()
            }
        }
        .padding(UnifiedDesignSystem.Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .unifiedBackground(.primary)
    }
}

// MARK: - 空状态类型
enum EmptyStateType {
    case noProducts
    case noCategories
    case noTags
    case noRepairRecords
    case noSearchResults
    case noFilterResults
    case networkError
    case loadingError
    case noData
    case noPermission
    
    var iconName: String {
        switch self {
        case .noProducts:
            return "shippingbox"
        case .noCategories:
            return "folder"
        case .noTags:
            return "tag"
        case .noRepairRecords:
            return "wrench.and.screwdriver"
        case .noSearchResults:
            return "magnifyingglass"
        case .noFilterResults:
            return "line.3.horizontal.decrease.circle"
        case .networkError:
            return "wifi.slash"
        case .loadingError:
            return "exclamationmark.triangle"
        case .noData:
            return "tray"
        case .noPermission:
            return "lock"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .noProducts, .noCategories, .noTags, .noRepairRecords, .noData:
            return UnifiedDesignSystem.Colors.secondary
        case .noSearchResults, .noFilterResults:
            return UnifiedDesignSystem.Colors.info
        case .networkError, .loadingError:
            return UnifiedDesignSystem.Colors.error
        case .noPermission:
            return UnifiedDesignSystem.Colors.warning
        }
    }
    
    var actionIcon: String {
        switch self {
        case .noProducts, .noCategories, .noTags, .noRepairRecords:
            return "plus"
        case .noSearchResults, .noFilterResults:
            return "arrow.clockwise"
        case .networkError, .loadingError:
            return "arrow.clockwise"
        case .noData:
            return "square.and.arrow.down"
        case .noPermission:
            return "gear"
        }
    }
}

// MARK: - 预定义空状态视图
extension UnifiedEmptyStateView {
    
    // MARK: - 产品相关
    static func noProducts(onAddProduct: @escaping () -> Void) -> UnifiedEmptyStateView {
        UnifiedEmptyStateView(
            type: .noProducts,
            title: "暂无产品",
            description: "您还没有添加任何产品。点击下方按钮开始添加您的第一个产品。",
            actionTitle: "添加产品",
            action: onAddProduct
        )
    }
    
    static func noSearchResults(searchText: String, onClearSearch: @escaping () -> Void) -> UnifiedEmptyStateView {
        UnifiedEmptyStateView(
            type: .noSearchResults,
            title: "未找到结果",
            description: "没有找到包含\"\(searchText)\"的产品。请尝试其他关键词或清除搜索条件。",
            actionTitle: "清除搜索",
            action: onClearSearch
        )
    }
    
    static func noFilterResults(onClearFilters: @escaping () -> Void) -> UnifiedEmptyStateView {
        UnifiedEmptyStateView(
            type: .noFilterResults,
            title: "没有符合条件的产品",
            description: "当前筛选条件下没有找到任何产品。请调整筛选条件或清除所有筛选。",
            actionTitle: "清除筛选",
            action: onClearFilters
        )
    }
    
    // MARK: - 分类相关
    static func noCategories(onAddCategory: @escaping () -> Void) -> UnifiedEmptyStateView {
        UnifiedEmptyStateView(
            type: .noCategories,
            title: "暂无分类",
            description: "您还没有创建任何产品分类。创建分类可以帮助您更好地组织产品。",
            actionTitle: "添加分类",
            action: onAddCategory
        )
    }
    
    // MARK: - 标签相关
    static func noTags(onAddTag: @escaping () -> Void) -> UnifiedEmptyStateView {
        UnifiedEmptyStateView(
            type: .noTags,
            title: "暂无标签",
            description: "您还没有创建任何标签。标签可以帮助您快速标记和查找产品。",
            actionTitle: "添加标签",
            action: onAddTag
        )
    }
    
    // MARK: - 维修记录相关
    static func noRepairRecords(onAddRecord: @escaping () -> Void) -> UnifiedEmptyStateView {
        UnifiedEmptyStateView(
            type: .noRepairRecords,
            title: "暂无维修记录",
            description: "您还没有任何维修记录。记录维修信息可以帮助您跟踪产品的维护历史。",
            actionTitle: "添加记录",
            action: onAddRecord
        )
    }
    
    // MARK: - 错误状态
    static func networkError(onRetry: @escaping () -> Void) -> UnifiedEmptyStateView {
        UnifiedEmptyStateView(
            type: .networkError,
            title: "网络连接失败",
            description: "无法连接到网络，请检查您的网络连接后重试。",
            actionTitle: "重试",
            action: onRetry
        )
    }
    
    static func loadingError(onRetry: @escaping () -> Void) -> UnifiedEmptyStateView {
        UnifiedEmptyStateView(
            type: .loadingError,
            title: "加载失败",
            description: "数据加载时出现错误，请稍后重试。",
            actionTitle: "重试",
            action: onRetry
        )
    }
    
    static func noPermission(onOpenSettings: @escaping () -> Void) -> UnifiedEmptyStateView {
        UnifiedEmptyStateView(
            type: .noPermission,
            title: "权限不足",
            description: "需要相应权限才能访问此功能。请在设置中授予必要的权限。",
            actionTitle: "打开设置",
            action: onOpenSettings
        )
    }
    
    // MARK: - 通用状态
    static func noData(title: String, description: String, actionTitle: String? = nil, action: (() -> Void)? = nil) -> UnifiedEmptyStateView {
        UnifiedEmptyStateView(
            type: .noData,
            title: title,
            description: description,
            actionTitle: actionTitle,
            action: action
        )
    }
}

// MARK: - 加载状态视图
struct UnifiedLoadingView: View {
    let message: String
    
    init(message: String = "加载中...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: UnifiedDesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: UnifiedDesignSystem.Colors.primary))
            
            Text(message)
                .unifiedBody(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .unifiedBackground(.primary)
    }
}

// MARK: - 错误状态视图
struct UnifiedErrorView: View {
    let error: Error
    let onRetry: (() -> Void)?
    
    init(error: Error, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(spacing: UnifiedDesignSystem.Spacing.xl) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(UnifiedDesignSystem.Colors.error)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: UnifiedDesignSystem.Spacing.md) {
                Text("出现错误")
                    .unifiedTitle(.title2)
                
                Text(error.localizedDescription)
                    .unifiedBody(.callout)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 300)
            
            if let onRetry = onRetry {
                Button(action: onRetry) {
                    Label("重试", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, UnifiedDesignSystem.Spacing.xl)
                        .padding(.vertical, UnifiedDesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: UnifiedDesignSystem.CornerRadius.button)
                                .fill(UnifiedDesignSystem.Colors.primary)
                        )
                }
                .buttonStyle(.plain)
                .unifiedTouchTarget()
                .unifiedHover()
            }
        }
        .padding(UnifiedDesignSystem.Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .unifiedBackground(.primary)
    }
}

#Preview {
    VStack(spacing: 20) {
        UnifiedEmptyStateView.noProducts {
            print("Add product tapped")
        }
        
        Divider()
        
        UnifiedLoadingView(message: "正在加载产品...")
        
        Divider()
        
        UnifiedErrorView(error: NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "这是一个测试错误"])) {
            print("Retry tapped")
        }
    }
}
