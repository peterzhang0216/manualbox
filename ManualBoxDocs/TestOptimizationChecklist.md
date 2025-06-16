# ManualBox 测试优化执行清单

## ✅ 已完成项目

- [x] 修复 ServiceLayerTests API 兼容性问题
- [x] 解决主 Actor 隔离违规警告  
- [x] 清理编译警告和未使用变量
- [x] 简化异步测试流程提升稳定性
- [x] 修复 EnhancedFeaturesIntegrationTests 并发问题

## 🔥 紧急处理 (本周必须完成)

### 1. 彻底修复 OCR 测试偶发失败

**当前问题**: `OCRServiceTests.testOCRServiceInitialization()` 偶发失败

**解决方案**:
```swift
@MainActor
func testOCRServiceInitialization() async {
    // 确保主 actor 稳定性
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    let service = OCRService.shared
    XCTAssertNotNil(service, "OCR服务应该能够正常初始化")
    XCTAssertFalse(service.isProcessing, "初始状态下不应该正在处理")
    XCTAssertEqual(service.currentProgress, 0.0, "初始进度应该为0")
    XCTAssertTrue(service.processingQueue.isEmpty, "初始队列应该为空")
}
```

**验证步骤**:
```bash
# 连续运行10次验证稳定性
for i in {1..10}; do 
    echo "测试第 $i 次"
    xcodebuild test -scheme ManualBox -destination 'platform=macOS' \
        -only-testing:ManualBoxTests/OCRServiceTests/testOCRServiceInitialization
done
```

### 2. 创建测试监控脚本

**文件**: `scripts/test_stability_check.sh`
```bash
#!/bin/bash
echo "ManualBox 测试稳定性检查"
FAIL_COUNT=0
TOTAL_RUNS=10

for i in $(seq 1 $TOTAL_RUNS); do
    echo "运行测试 $i/$TOTAL_RUNS"
    if ! xcodebuild test -scheme ManualBox -destination 'platform=macOS' > /dev/null 2>&1; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "❌ 第 $i 次测试失败"
    else
        echo "✅ 第 $i 次测试通过"
    fi
done

echo "稳定性报告: $((TOTAL_RUNS - FAIL_COUNT))/$TOTAL_RUNS 成功"
if [ $FAIL_COUNT -eq 0 ]; then
    echo "🎉 所有测试稳定通过!"
else
    echo "⚠️ 检测到 $FAIL_COUNT 次失败，需要进一步调查"
fi
```

## 📅 近期任务 (2周内)

### 3. 测试数据隔离改进

**目标**: 确保每个测试的数据独立性

**实现位置**: `ManualBoxTests/TestHelpers/TestDataManager.swift`
```swift
import CoreData

class TestDataManager {
    static func createIsolatedContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "ManualBox")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = URL(fileURLWithPath: "/dev/null")
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("测试数据栈创建失败: \(error)")
            }
        }
        
        return container.viewContext
    }
}
```

### 4. 增强错误处理测试

**需要添加的测试文件**: `ManualBoxTests/ErrorHandlingTests.swift`

**测试场景**:
- 文件权限拒绝处理
- 网络连接失败恢复
- 磁盘空间不足处理
- 内存压力下的行为
- OCR 服务不可用处理

### 5. 性能基准测试

**文件**: `ManualBoxTests/PerformanceBenchmarkTests.swift`
```swift
class PerformanceBenchmarkTests: XCTestCase {
    func testOCRPerformanceBenchmark() {
        measure {
            // OCR 性能基准测试
        }
    }
    
    func testSearchPerformanceBenchmark() {
        measure {
            // 搜索性能基准测试
        }
    }
}
```

## 🚀 中期目标 (1个月内)

### 6. CI/CD 集成

**文件**: `.github/workflows/tests.yml`
```yaml
name: Continuous Testing
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: 运行测试套件
        run: |
          xcodebuild test -scheme ManualBox \
            -destination 'platform=macOS' \
            -enableCodeCoverage YES \
            -resultBundlePath TestResults.xcresult
      
      - name: 上传测试结果
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: TestResults.xcresult
```

### 7. 测试覆盖率提升

**目标覆盖率**:
- 核心业务逻辑: 95% → 98%
- 错误处理: 75% → 90%
- 并发处理: 50% → 80%

### 8. 测试文档完善

**需要创建的文档**:
- `ManualBoxDocs/TestingGuide.md` - 测试编写指南
- `ManualBoxDocs/MockDataGuide.md` - 测试数据使用指南
- `ManualBoxDocs/DebugTestGuide.md` - 测试调试指南

## 📊 质量指标监控

### 每日检查项目
- [ ] 所有测试通过率 ≥ 99%
- [ ] 测试执行时间 ≤ 15分钟
- [ ] 无新增编译警告
- [ ] OCR 测试稳定性 ≥ 95%

### 每周检查项目
- [ ] 代码覆盖率趋势
- [ ] 性能测试基准对比
- [ ] CI/CD 成功率统计
- [ ] 测试债务清理进度

## 🔧 工具和脚本

### 快速测试命令
```bash
# 快速单元测试
alias unit-test="xcodebuild test -scheme ManualBox -destination 'platform=macOS' -only-testing:ManualBoxTests"

# 性能测试
alias perf-test="xcodebuild test -scheme ManualBox -destination 'platform=macOS' -only-testing:PerformanceTests"

# UI 测试
alias ui-test="xcodebuild test -scheme ManualBox -destination 'platform=macOS' -only-testing:ManualBoxUITests"
```

### 代码覆盖率检查
```bash
# 生成覆盖率报告
xcodebuild test -scheme ManualBox -destination 'platform=macOS' \
  -enableCodeCoverage YES \
  -resultBundlePath coverage.xcresult

# 解析覆盖率数据
xcrun xccov view --report coverage.xcresult
```

## 🚨 紧急联系方式

**测试负责人**: 核心开发团队  
**问题上报**: GitHub Issues  
**紧急情况**: 技术负责人  

## 📈 成功标准

**本周目标**: OCR 测试 10 次连续通过  
**两周目标**: 测试通过率稳定在 99%+  
**一个月目标**: 代码覆盖率达到 85%+  

---

**检查清单更新**: 2025年6月16日  
**负责人签字**: ________________  
**下次审核**: 2025年6月23日
