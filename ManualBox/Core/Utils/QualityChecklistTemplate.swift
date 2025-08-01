//
//  QualityChecklistTemplate.swift
//  ManualBox
//
//  Created by Assistant on 2025/7/29.
//

import Foundation

/**
 * 代码质量检查清单模板
 * 用于代码审查和质量控制
 */

// MARK: - 代码审查检查清单

struct CodeReviewChecklist {
    
    // MARK: - 编码规范检查
    static let codingStandards = [
        "✅ 遵循 Swift 命名规范（camelCase, PascalCase）",
        "✅ 类型和函数名称清晰表达意图",
        "✅ 避免使用缩写和不清晰的名称",
        "✅ 使用适当的访问控制修饰符",
        "✅ 代码缩进和格式化一致"
    ]
    
    // MARK: - 架构和设计检查
    static let architectureChecks = [
        "✅ 遵循 MVC/MVVM 架构模式",
        "✅ 职责分离清晰，单一职责原则",
        "✅ 依赖注入正确使用",
        "✅ 协议导向编程应用适当",
        "✅ 避免循环依赖"
    ]
    
    // MARK: - 代码质量检查
    static let qualityChecks = [
        "✅ 无重复代码，DRY 原则",
        "✅ 函数长度适中（<50行）",
        "✅ 类文件长度合理（<500行）",
        "✅ 复杂度控制在合理范围",
        "✅ 错误处理完善"
    ]
    
    // MARK: - 性能检查
    static let performanceChecks = [
        "✅ 避免主线程阻塞操作",
        "✅ 合理使用异步编程",
        "✅ 内存管理得当，避免循环引用",
        "✅ 数据库查询优化",
        "✅ 资源使用高效"
    ]
    
    // MARK: - 测试检查
    static let testingChecks = [
        "✅ 单元测试覆盖关键逻辑",
        "✅ 测试用例清晰明确",
        "✅ 边界条件测试完善",
        "✅ 错误情况测试覆盖",
        "✅ 集成测试适当添加"
    ]
    
    // MARK: - 文档检查
    static let documentationChecks = [
        "✅ 公共API有详细注释",
        "✅ 复杂算法有解释说明",
        "✅ README 文档更新",
        "✅ 变更日志记录",
        "✅ 使用示例完整"
    ]
}

// MARK: - 质量门控检查

struct QualityGateChecks {
    
    /// 编译检查
    static let buildChecks = [
        "无编译错误",
        "编译警告 < 5个",
        "所有测试通过",
        "代码覆盖率 > 75%"
    ]
    
    /// 静态分析检查
    static let staticAnalysisChecks = [
        "SwiftLint 检查通过",
        "无重复代码块",
        "圈复杂度 < 10",
        "认知复杂度 < 15"
    ]
    
    /// 安全检查
    static let securityChecks = [
        "无硬编码敏感信息",
        "用户输入验证完善",
        "数据加密存储正确",
        "权限检查适当"
    ]
}

// MARK: - 代码重构检查清单

struct RefactoringChecklist {
    
    /// 重构前检查
    static let preRefactoringChecks = [
        "✅ 有充足的测试覆盖",
        "✅ 理解现有代码逻辑",
        "✅ 确定重构目标和范围",
        "✅ 备份当前代码状态"
    ]
    
    /// 重构过程检查
    static let duringRefactoringChecks = [
        "✅ 小步骤增量式重构",
        "✅ 每步后运行测试",
        "✅ 保持功能不变",
        "✅ 及时提交版本控制"
    ]
    
    /// 重构后检查
    static let postRefactoringChecks = [
        "✅ 所有测试通过",
        "✅ 性能无明显下降",
        "✅ 代码可读性提升",
        "✅ 架构更加清晰",
        "✅ 文档更新完成"
    ]
}

// MARK: - Swift 6 兼容性检查

struct Swift6CompatibilityChecklist {
    
    static let concurrencyChecks = [
        "✅ 正确使用 @MainActor",
        "✅ 异步函数标记适当",
        "✅ Sendable 协议应用正确",
        "✅ 数据竞争问题解决",
        "✅ 遗留代码使用 @preconcurrency"
    ]
    
    static let typeChecks = [
        "✅ 可选类型使用合理",
        "✅ 泛型约束清晰",
        "✅ 协议关联类型正确",
        "✅ 类型推断优化"
    ]
}

// MARK: - 使用指南

/**
 使用方法：
 
 1. 开发前检查
    - 确保开发环境配置正确
    - 理解需求和设计规范
    - 选择合适的架构模式
 
 2. 开发中检查
    - 遵循编码规范
    - 及时编写测试
    - 保持代码整洁
 
 3. 代码提交前检查
    - 运行完整测试套件
    - 静态代码分析
    - 代码审查自检
 
 4. 发布前检查
    - 性能测试通过
    - 安全检查完成
    - 文档更新完善
 
 示例使用：
 
 ```swift
 // 在代码审查时使用
 let checklist = CodeReviewChecklist.codingStandards + 
                CodeReviewChecklist.qualityChecks
 
 // 检查每个项目
 checklist.forEach { item in
     print("检查项: \(item)")
 }
 ```
 */
