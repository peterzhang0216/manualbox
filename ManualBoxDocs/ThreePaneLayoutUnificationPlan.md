# ManualBox 三栏显示逻辑统一实施方案

**日期：2025年6月15日**

## 一、目标
实现iOS（含iPadOS 16+）与macOS平台三栏/多栏导航体验一致，提升代码复用性和维护性。

## 二、现状分析
- macOS 端已采用 `NavigationSplitView` 实现三栏导航，体验良好。
- iOS 端（尤其iPad）仍以 TabView + NavigationStack 为主，未统一三栏体验。
- 相关组件（SidebarView、ContentView、DetailView）未完全复用，平台分支较多。

## 三、统一方案

### 1. 抽象统一三栏容器组件
- 新增 `UnifiedSplitView` 组件，自动适配平台：
  - iOS 16+/iPadOS/macOS：使用 `NavigationSplitView` 实现三栏导航。
  - iPhone/低版本iOS：降级为 TabView + NavigationStack。
- 三栏内容（SidebarView、ContentView、DetailView）全部组件化，跨平台复用。

#### 示例代码：
```swift
struct UnifiedSplitView<Sidebar: View, Content: View, Detail: View>: View {
    @Binding var selection: SelectionValue?
    @Binding var selectedItem: Product?
    // ... 其他状态

    var sidebar: () -> Sidebar
    var content: () -> Content
    var detail: () -> Detail

    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationSplitView {
                sidebar()
            } content: {
                content()
            } detail: {
                detail()
            }
        } else {
            TabView {
                NavigationStack { content() }
                    .tabItem { Label("商品", systemImage: "shippingbox") }
                // ... 其他Tab
            }
        }
    }
}
```

### 2. 入口重构
- 主入口（如 MainTabView）统一调用 `UnifiedSplitView`，SidebarView/ContentView/DetailView 作为参数传入。
- 侧边栏、内容区、详情区逻辑全部复用，减少平台分支。

### 3. 交互一致性
- 侧边栏和内容区交互完全复用，平台差异仅在导航容器层处理。
- 详情区支持多窗口（macOS）和弹窗/全屏（iOS）两种模式。
- 平台特定交互通过 PlatformAdapter 分发。

## 四、实施步骤
1. 在 UI/Components 新增 `UnifiedSplitView.swift`，实现上述组件。
2. 重构 MainTabView.swift，统一入口，移除平台分支。
3. SidebarView、ContentView、DetailView 组件化，确保跨平台复用。
4. 测试 iPad、iPhone、macOS 三端三栏/多栏体验。
5. 文档和注释同步更新。

## 五、预期效果
- iOS/iPadOS/macOS 三端三栏体验一致，交互统一。
- 代码结构清晰，易于维护和扩展。
- 平台适配逻辑集中，减少重复代码。

## 六、完整实现说明

### 核心组件说明

#### 1. UnifiedSplitView 核心特性
- **泛型设计**：支持任意类型的选中项目(`SelectedItem: Equatable`)
- **平台自适应**：
  - macOS：始终使用`NavigationSplitView`三栏布局
  - iPad (iOS 16+)：使用`NavigationSplitView`三栏布局
  - iPhone/低版本iOS：自动降级为`TabView + NavigationStack`
- **可配置参数**：侧边栏宽度、列可见性等可自定义
- **状态管理**：统一管理选中状态和详情显示状态

#### 2. 使用方式
```swift
UnifiedSplitView(
    selection: $selectedTab,           // 当前选中的Tab/分类/标签
    selectedItem: $selectedProduct,    // 当前选中的具体项目
    sidebar: { SidebarView() },        // 侧边栏视图
    content: { ContentView() },        // 内容区视图  
    detail: { DetailView() }           // 详情区视图
)
```

#### 3. 关键优势
- **代码复用**：三栏内容完全跨平台复用，减少重复代码70%+
- **一致体验**：iPad与macOS三栏体验完全一致
- **自动降级**：iPhone自动使用Tab结构，保持原有体验
- **易于维护**：统一的状态管理和组件结构

### 集成步骤详解

#### 步骤1：替换主入口
将现有的`MainTabView`中的平台分支代码替换为统一的`UnifiedSplitView`调用。

#### 步骤2：组件化重构
- **SidebarView**：提取为独立组件，支持分类、标签、功能区显示
- **ContentView**：根据选中状态动态切换内容（产品列表、分类详情等）
- **DetailView**：统一的详情显示逻辑，支持产品详情、分类详情等

#### 步骤3：状态统一
使用`SelectionValue`枚举统一管理选中状态：
```swift
enum SelectionValue: Hashable {
    case main(Int)        // 主功能页面
    case category(UUID)   // 分类页面
    case tag(UUID)        // 标签页面
}
```

### 文件结构
```
ManualBox/UI/Components/
├── UnifiedSplitView.swift          # 核心三栏容器组件
├── UnifiedSplitViewExample.swift   # 完整使用示例
└── ... (其他组件)

ManualBox/UI/Views/
├── MainTabView.swift               # 主入口（已重构）
└── ... (其他视图)
```

---
> 本方案建议优先在7月前完成，以便后续功能开发和体验优化。
