//
//  OCRTextPostprocessor.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
import NaturalLanguage

// MARK: - 增强版文本后处理器
class TextPostprocessor {

    // 缓存常用的正则表达式
    private lazy var regexCache: [String: NSRegularExpression] = [:]

    // 常见词汇字典
    private lazy var commonWordsDictionary: Set<String> = {
        loadCommonWordsDictionary()
    }()

    // 技术术语字典
    private lazy var technicalTermsDictionary: [String: String] = {
        loadTechnicalTermsDictionary()
    }()

    // MARK: - 主要处理方法
    func enhance(_ text: String) -> String {
        var processedText = text

        // 1. 基础清理
        processedText = performBasicCleaning(processedText)

        // 2. 修正常见的OCR错误
        processedText = correctCommonOCRErrors(processedText)

        // 3. 语言特定的修正
        processedText = applyLanguageSpecificCorrections(processedText)

        // 4. 技术术语修正
        processedText = correctTechnicalTerms(processedText)

        // 5. 格式化处理
        processedText = formatText(processedText)

        // 6. 智能分段
        processedText = applySmartParagraphing(processedText)

        // 7. 最终质量检查
        processedText = performFinalQualityCheck(processedText)

        return processedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 增强的处理方法
    func enhanceWithContext(_ text: String, documentType: OCRDocumentType = .manual) -> String {
        var processedText = text

        // 根据文档类型应用特定的处理规则
        switch documentType {
        case .manual:
            processedText = applyManualSpecificCorrections(processedText)
        case .invoice:
            processedText = applyInvoiceSpecificCorrections(processedText)
        case .receipt:
            processedText = applyReceiptSpecificCorrections(processedText)
        case .general:
            break
        }

        return enhance(processedText)
    }
    
    // MARK: - 基础清理
    private func performBasicCleaning(_ text: String) -> String {
        var cleanedText = text
        
        // 去除多余的空白字符
        cleanedText = cleanedText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // 去除行首行尾空白
        cleanedText = cleanedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        
        // 去除空行
        cleanedText = cleanedText.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        
        return cleanedText
    }
    
    // MARK: - OCR错误修正
    private func correctCommonOCRErrors(_ text: String) -> String {
        var correctedText = text
        
        // 数字和字母混淆修正
        correctedText = correctNumberLetterConfusion(correctedText)
        
        // 标点符号修正
        correctedText = correctPunctuation(correctedText)
        
        // 全角半角字符修正
        correctedText = correctCharacterWidth(correctedText)
        
        // 常见词汇修正
        correctedText = correctCommonWords(correctedText)
        
        return correctedText
    }
    
    /// 数字和字母混淆修正
    private func correctNumberLetterConfusion(_ text: String) -> String {
        var correctedText = text
        
        // 在数字上下文中的修正规则
        let numberContextCorrections: [(String, String)] = [
            ("O", "0"), // 字母O误识别为数字0
            ("l", "1"), // 字母l误识别为数字1
            ("I", "1"), // 字母I误识别为数字1
            ("S", "5"), // 字母S误识别为数字5
            ("G", "6"), // 字母G误识别为数字6
            ("B", "8"), // 字母B误识别为数字8
            ("g", "9"), // 字母g误识别为数字9
        ]
        
        // 在字母上下文中的修正规则
        let letterContextCorrections: [(String, String)] = [
            ("0", "O"), // 数字0误识别为字母O
            ("1", "l"), // 数字1误识别为字母l
            ("5", "S"), // 数字5误识别为字母S
            ("6", "G"), // 数字6误识别为字母G
            ("8", "B"), // 数字8误识别为字母B
            ("9", "g"), // 数字9误识别为字母g
        ]
        
        // 应用数字上下文修正
        for (wrong, correct) in numberContextCorrections {
            correctedText = applyCorrectionInNumberContext(correctedText, wrong: wrong, correct: correct)
        }
        
        // 应用字母上下文修正
        for (wrong, correct) in letterContextCorrections {
            correctedText = applyCorrectionInLetterContext(correctedText, wrong: wrong, correct: correct)
        }
        
        return correctedText
    }
    
    /// 在数字上下文中应用修正
    private func applyCorrectionInNumberContext(_ text: String, wrong: String, correct: String) -> String {
        // 匹配数字模式：数字+错误字符+数字
        let pattern = "\\d+[" + NSRegularExpression.escapedPattern(for: wrong) + "]\\d*|\\d*[" + NSRegularExpression.escapedPattern(for: wrong) + "]\\d+"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            let matches = regex.matches(in: text, options: [], range: range)
            
            var correctedText = text
            // 从后往前替换以避免索引偏移问题
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    let matchString = String(text[range])
                    let correctedMatch = matchString.replacingOccurrences(of: wrong, with: correct)
                    correctedText = correctedText.replacingCharacters(in: range, with: correctedMatch)
                }
            }
            
            return correctedText
        } catch {
            return text
        }
    }
    
    /// 在字母上下文中应用修正
    private func applyCorrectionInLetterContext(_ text: String, wrong: String, correct: String) -> String {
        // 匹配字母模式：字母+错误字符+字母
        let pattern = "[A-Za-z]+[" + NSRegularExpression.escapedPattern(for: wrong) + "][A-Za-z]*|[A-Za-z]*[" + NSRegularExpression.escapedPattern(for: wrong) + "][A-Za-z]+"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            let matches = regex.matches(in: text, options: [], range: range)
            
            var correctedText = text
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    let matchString = String(text[range])
                    let correctedMatch = matchString.replacingOccurrences(of: wrong, with: correct)
                    correctedText = correctedText.replacingCharacters(in: range, with: correctedMatch)
                }
            }
            
            return correctedText
        } catch {
            return text
        }
    }
    
    /// 标点符号修正
    private func correctPunctuation(_ text: String) -> String {
        var correctedText = text
        
        // 全角标点符号修正
        let punctuationCorrections: [(String, String)] = [
            ("．", "."), // 全角句号
            ("，", ","), // 全角逗号
            ("：", ":"), // 全角冒号
            ("；", ";"), // 全角分号
            ("！", "!"), // 全角感叹号
            ("？", "?"), // 全角问号
            ("（", "("), // 全角左括号
            ("）", ")"), // 全角右括号
            ("【", "["), // 全角左方括号
            ("】", "]"), // 全角右方括号
            ("｛", "{"), // 全角左花括号
            ("｝", "}"), // 全角右花括号
            ("＂", "\""), // 全角双引号
            ("＇", "'"), // 全角单引号
            ("｜", "|"), // 全角竖线
            ("＼", "\\"), // 全角反斜杠
            ("／", "/"), // 全角斜杠
        ]
        
        for (wrong, correct) in punctuationCorrections {
            correctedText = correctedText.replacingOccurrences(of: wrong, with: correct)
        }
        
        return correctedText
    }
    
    /// 全角半角字符修正
    private func correctCharacterWidth(_ text: String) -> String {
        var correctedText = text
        
        // 数字全角转半角
        let fullWidthNumbers = "０１２３４５６７８９"
        let halfWidthNumbers = "0123456789"
        
        for (full, half) in zip(fullWidthNumbers, halfWidthNumbers) {
            correctedText = correctedText.replacingOccurrences(of: String(full), with: String(half))
        }
        
        // 字母全角转半角
        let fullWidthLetters = "ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ"
        let halfWidthLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        
        for (full, half) in zip(fullWidthLetters, halfWidthLetters) {
            correctedText = correctedText.replacingOccurrences(of: String(full), with: String(half))
        }
        
        return correctedText
    }
    
    /// 常见词汇修正
    private func correctCommonWords(_ text: String) -> String {
        var correctedText = text
        
        // 常见OCR错误词汇修正
        let wordCorrections: [(String, String)] = [
            ("rn", "m"), // rn误识别为m
            ("cl", "d"), // cl误识别为d
            ("vv", "w"), // vv误识别为w
            ("rn", "m"), // rn误识别为m
            ("1n", "ln"), // 1n误识别为ln
            ("0n", "On"), // 0n误识别为On
        ]
        
        for (wrong, correct) in wordCorrections {
            correctedText = correctedText.replacingOccurrences(of: wrong, with: correct)
        }
        
        return correctedText
    }
    
    // MARK: - 语言特定修正
    private func applyLanguageSpecificCorrections(_ text: String) -> String {
        var correctedText = text
        
        // 检测主要语言
        let language = detectPrimaryLanguage(text)
        
        switch language {
        case "zh":
            correctedText = applyChineseCorrections(correctedText)
        case "en":
            correctedText = applyEnglishCorrections(correctedText)
        case "ja":
            correctedText = applyJapaneseCorrections(correctedText)
        default:
            break
        }
        
        return correctedText
    }
    
    /// 检测主要语言
    private func detectPrimaryLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        guard let language = recognizer.dominantLanguage else {
            return "en" // 默认英语
        }
        
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return "zh"
        case .english:
            return "en"
        case .japanese:
            return "ja"
        default:
            return "en"
        }
    }
    
    /// 中文特定修正
    private func applyChineseCorrections(_ text: String) -> String {
        var correctedText = text
        
        // 中文常见OCR错误
        let chineseCorrections: [(String, String)] = [
            ("口", "日"), // 口误识别为日
            ("日", "目"), // 日误识别为目
            ("木", "术"), // 木误识别为术
            ("大", "太"), // 大误识别为太
            ("小", "少"), // 小误识别为少
            ("人", "入"), // 人误识别为入
            ("八", "人"), // 八误识别为人
        ]
        
        for (wrong, correct) in chineseCorrections {
            correctedText = correctedText.replacingOccurrences(of: wrong, with: correct)
        }
        
        return correctedText
    }
    
    /// 英文特定修正
    private func applyEnglishCorrections(_ text: String) -> String {
        var correctedText = text
        
        // 英文常见OCR错误
        let englishCorrections: [(String, String)] = [
            ("rn", "m"), // rn误识别为m
            ("cl", "d"), // cl误识别为d
            ("vv", "w"), // vv误识别为w
            ("1n", "ln"), // 1n误识别为ln
            ("0n", "On"), // 0n误识别为On
        ]
        
        for (wrong, correct) in englishCorrections {
            correctedText = correctedText.replacingOccurrences(of: wrong, with: correct)
        }
        
        return correctedText
    }
    
    /// 日文特定修正
    private func applyJapaneseCorrections(_ text: String) -> String {
        var correctedText = text
        
        // 日文常见OCR错误
        let japaneseCorrections: [(String, String)] = [
            ("口", "日"), // 口误识别为日
            ("日", "目"), // 日误识别为目
            ("木", "术"), // 木误识别为术
        ]
        
        for (wrong, correct) in japaneseCorrections {
            correctedText = correctedText.replacingOccurrences(of: wrong, with: correct)
        }
        
        return correctedText
    }
    
    // MARK: - 格式化处理
    private func formatText(_ text: String) -> String {
        var formattedText = text
        
        // 智能换行处理
        formattedText = formatLineBreaks(formattedText)
        
        // 段落格式化
        formattedText = formatParagraphs(formattedText)
        
        // 列表格式化
        formattedText = formatLists(formattedText)
        
        return formattedText
    }
    
    /// 智能换行处理
    private func formatLineBreaks(_ text: String) -> String {
        // 在句号、感叹号、问号后添加双换行
        var formattedText = text.replacingOccurrences(
            of: "([。！？])\\n([A-Za-z0-9\\u4e00-\\u9fff])",
            with: "$1\n\n$2",
            options: .regularExpression
        )
        
        // 在冒号后添加单换行
        formattedText = formattedText.replacingOccurrences(
            of: "([：:])\\n([A-Za-z0-9\\u4e00-\\u9fff])",
            with: "$1\n$2",
            options: .regularExpression
        )
        
        return formattedText
    }
    
    /// 段落格式化
    private func formatParagraphs(_ text: String) -> String {
        // 检测段落边界并添加适当的空行
        let lines = text.components(separatedBy: .newlines)
        var formattedLines: [String] = []
        
        for (index, line) in lines.enumerated() {
            formattedLines.append(line)
            
            // 在段落末尾添加空行
            if isParagraphEnd(line) && index < lines.count - 1 {
                formattedLines.append("")
            }
        }
        
        return formattedLines.joined(separator: "\n")
    }
    
    /// 判断是否为段落结束
    private func isParagraphEnd(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // 以句号、感叹号、问号结尾
        if trimmedLine.hasSuffix("。") || trimmedLine.hasSuffix("！") || trimmedLine.hasSuffix("？") {
            return true
        }
        
        // 以英文句号、感叹号、问号结尾
        if trimmedLine.hasSuffix(".") || trimmedLine.hasSuffix("!") || trimmedLine.hasSuffix("?") {
            return true
        }
        
        return false
    }
    
    /// 列表格式化
    private func formatLists(_ text: String) -> String {
        var formattedText = text
        
        // 检测并格式化数字列表
        formattedText = formatNumberedLists(formattedText)
        
        // 检测并格式化项目符号列表
        formattedText = formatBulletLists(formattedText)
        
        return formattedText
    }
    
    /// 格式化数字列表
    private func formatNumberedLists(_ text: String) -> String {
        // 匹配数字列表模式：数字. 内容
        let pattern = "(\\d+)\\.\\s*([^\\n]+)"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            
            return regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: range,
                withTemplate: "$1. $2"
            )
        } catch {
            return text
        }
    }
    
    /// 格式化项目符号列表
    private func formatBulletLists(_ text: String) -> String {
        // 匹配项目符号模式：• 内容 或 - 内容
        let pattern = "([•\\-])\\s*([^\\n]+)"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            
            return regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: range,
                withTemplate: "$1 $2"
            )
        } catch {
            return text
        }
    }
    
    // MARK: - 智能分段
    private func applySmartParagraphing(_ text: String) -> String {
        // 基于语义的智能分段
        let sentences = splitIntoSentences(text)
        var paragraphs: [String] = []
        var currentParagraph: [String] = []
        
        for sentence in sentences {
            currentParagraph.append(sentence)
            
            // 如果当前段落太长或遇到段落标记，开始新段落
            if shouldStartNewParagraph(currentParagraph) {
                if !currentParagraph.isEmpty {
                    paragraphs.append(currentParagraph.joined(separator: " "))
                    currentParagraph = []
                }
            }
        }
        
        // 添加最后一个段落
        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph.joined(separator: " "))
        }
        
        return paragraphs.joined(separator: "\n\n")
    }

    // MARK: - 新增的增强处理方法

    /// 技术术语修正
    private func correctTechnicalTerms(_ text: String) -> String {
        var correctedText = text

        for (incorrect, correct) in technicalTermsDictionary {
            correctedText = correctedText.replacingOccurrences(
                of: incorrect,
                with: correct,
                options: [.caseInsensitive, .regularExpression]
            )
        }

        return correctedText
    }

    /// 说明书特定修正
    private func applyManualSpecificCorrections(_ text: String) -> String {
        var correctedText = text

        // 修正常见的说明书术语
        let manualTerms = [
            ("操作步骤", "操作步骤"),
            ("注意事项", "注意事项"),
            ("安全警告", "安全警告"),
            ("技术参数", "技术参数"),
            ("故障排除", "故障排除"),
            ("维护保养", "维护保养")
        ]

        for (pattern, replacement) in manualTerms {
            correctedText = applyPatternCorrection(correctedText, pattern: pattern, replacement: replacement)
        }

        // 修正数字和单位的分离问题
        correctedText = correctNumberUnitSeparation(correctedText)

        return correctedText
    }

    /// 发票特定修正
    private func applyInvoiceSpecificCorrections(_ text: String) -> String {
        var correctedText = text

        // 修正金额格式
        correctedText = correctCurrencyFormat(correctedText)

        // 修正日期格式
        correctedText = correctDateFormat(correctedText)

        // 修正税号格式
        correctedText = correctTaxNumberFormat(correctedText)

        return correctedText
    }

    /// 收据特定修正
    private func applyReceiptSpecificCorrections(_ text: String) -> String {
        var correctedText = text

        // 修正商品名称和价格的对应关系
        correctedText = correctItemPriceAlignment(correctedText)

        // 修正小计、税费、总计的格式
        correctedText = correctReceiptTotals(correctedText)

        return correctedText
    }

    /// 最终质量检查
    private func performFinalQualityCheck(_ text: String) -> String {
        var checkedText = text

        // 检查并修正明显的错误
        checkedText = removeObviousErrors(checkedText)

        // 检查文本完整性
        checkedText = ensureTextCompleteness(checkedText)

        // 标准化空白字符
        checkedText = normalizeWhitespace(checkedText)

        return checkedText
    }

    // MARK: - 辅助方法

    /// 修正数字和单位的分离问题
    private func correctNumberUnitSeparation(_ text: String) -> String {
        // 修正如 "5 0 0 m m" -> "500mm" 的问题
        let pattern = #"(\d+(?:\s+\d+)*)\s*([a-zA-Z]+)"#

        guard let regex = getCachedRegex(pattern) else { return text }

        let range = NSRange(location: 0, length: text.utf16.count)
        let result = regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: "$1$2"
        )

        // 移除数字间的空格
        return result.replacingOccurrences(
            of: #"(\d)\s+(\d)"#,
            with: "$1$2",
            options: .regularExpression
        )
    }

    /// 修正货币格式
    private func correctCurrencyFormat(_ text: String) -> String {
        var correctedText = text

        // 修正如 "¥ 1 2 3 . 4 5" -> "¥123.45" 的问题
        let currencyPatterns = [
            (#"¥\s*(\d+(?:\s+\d+)*)\s*\.\s*(\d+(?:\s+\d+)*)"#, "¥$1.$2"),
            (#"\$\s*(\d+(?:\s+\d+)*)\s*\.\s*(\d+(?:\s+\d+)*)"#, "$$$1.$2"),
            (#"(\d+(?:\s+\d+)*)\s*元"#, "$1元")
        ]

        for (pattern, replacement) in currencyPatterns {
            correctedText = correctedText.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }

        // 移除货币数字间的空格
        correctedText = correctedText.replacingOccurrences(
            of: #"(¥|\$)(\d)\s+(\d)"#,
            with: "$1$2$3",
            options: .regularExpression
        )

        return correctedText
    }

    /// 修正日期格式
    private func correctDateFormat(_ text: String) -> String {
        var correctedText = text

        // 修正如 "2 0 2 3 - 1 2 - 3 1" -> "2023-12-31" 的问题
        let datePatterns = [
            (#"(\d)\s+(\d)\s+(\d)\s+(\d)\s*-\s*(\d)\s+(\d)\s*-\s*(\d)\s+(\d)"#, "$1$2$3$4-$5$6-$7$8"),
            (#"(\d)\s+(\d)\s+(\d)\s+(\d)\s*/\s*(\d)\s+(\d)\s*/\s*(\d)\s+(\d)"#, "$1$2$3$4/$5$6/$7$8"),
            (#"(\d)\s+(\d)\s+(\d)\s+(\d)\s*年\s*(\d)\s+(\d)\s*月\s*(\d)\s+(\d)\s*日"#, "$1$2$3$4年$5$6月$7$8日")
        ]

        for (pattern, replacement) in datePatterns {
            correctedText = correctedText.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }

        return correctedText
    }
    
    /// 分割成句子
    private func splitIntoSentences(_ text: String) -> [String] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: "。！？.!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        return sentences
    }
    
    /// 判断是否应该开始新段落
    private func shouldStartNewParagraph(_ sentences: [String]) -> Bool {
        // 如果段落太长（超过3个句子），开始新段落
        if sentences.count > 3 {
            return true
        }
        
        // 如果最后一个句子包含段落标记，开始新段落
        if let lastSentence = sentences.last {
            let paragraphMarkers = ["总之", "因此", "所以", "然而", "但是", "另外", "此外", "同时"]
            for marker in paragraphMarkers {
                if lastSentence.contains(marker) {
                    return true
                }
            }
        }
        
        return false
    }

    // MARK: - 字典加载方法

    /// 加载常用词汇字典
    private func loadCommonWordsDictionary() -> Set<String> {
        // 这里可以从文件或网络加载，现在使用硬编码的常用词汇
        return Set([
            "产品", "说明书", "操作", "使用", "安装", "维护", "保养", "故障", "排除",
            "技术", "参数", "规格", "型号", "品牌", "制造商", "生产日期", "保修期",
            "注意事项", "安全", "警告", "禁止", "允许", "建议", "推荐", "可选",
            "必须", "应该", "可以", "不能", "严禁", "确保", "检查", "测试",
            "电源", "电压", "电流", "功率", "频率", "温度", "湿度", "压力",
            "尺寸", "重量", "材质", "颜色", "包装", "配件", "附件", "工具"
        ])
    }

    /// 加载技术术语字典
    private func loadTechnicalTermsDictionary() -> [String: String] {
        return [
            // 常见OCR错误修正
            "电阻": "电阻",
            "电容": "电容",
            "电感": "电感",
            "二极管": "二极管",
            "三极管": "三极管",
            "集成电路": "集成电路",
            "微处理器": "微处理器",
            "传感器": "传感器",
            "执行器": "执行器",
            "控制器": "控制器",

            // 单位修正
            "毫米": "mm",
            "厘米": "cm",
            "米": "m",
            "千米": "km",
            "毫克": "mg",
            "克": "g",
            "千克": "kg",
            "毫升": "ml",
            "升": "L",
            "伏特": "V",
            "安培": "A",
            "瓦特": "W",
            "赫兹": "Hz",
            "摄氏度": "°C",

            // 常见错误修正
            "O": "0",  // 字母O误识别为数字0
            "l": "1",  // 小写l误识别为数字1
            "S": "5",  // 在某些上下文中
            "G": "6",  // 在某些上下文中
        ]
    }

    /// 获取缓存的正则表达式
    private func getCachedRegex(_ pattern: String) -> NSRegularExpression? {
        if let cached = regexCache[pattern] {
            return cached
        }

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            regexCache[pattern] = regex
            return regex
        } catch {
            print("正则表达式编译失败: \(pattern), 错误: \(error)")
            return nil
        }
    }

    /// 移除明显的错误
    private func removeObviousErrors(_ text: String) -> String {
        var cleanedText = text

        // 移除单独的特殊字符行
        cleanedText = cleanedText.replacingOccurrences(
            of: #"^[^\w\s\u4e00-\u9fff]+$"#,
            with: "",
            options: [.regularExpression, .anchored]
        )

        // 移除过短的行（可能是识别错误）
        let lines = cleanedText.components(separatedBy: .newlines)
        let filteredLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count >= 2 || trimmed.isEmpty
        }

        return filteredLines.joined(separator: "\n")
    }

    /// 确保文本完整性
    private func ensureTextCompleteness(_ text: String) -> String {
        var completeText = text

        // 检查是否有未完成的句子（以标点符号结尾）
        let sentences = completeText.components(separatedBy: CharacterSet(charactersIn: "。！？.!?"))
        if let lastSentence = sentences.last?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lastSentence.isEmpty && sentences.count > 1 {
            // 如果最后一句话没有标点符号，可能是不完整的
            completeText += "..."
        }

        return completeText
    }

    /// 标准化空白字符
    private func normalizeWhitespace(_ text: String) -> String {
        var normalizedText = text

        // 将多个连续空格替换为单个空格
        normalizedText = normalizedText.replacingOccurrences(
            of: #" +"#,
            with: " ",
            options: .regularExpression
        )

        // 将多个连续换行替换为最多两个换行
        normalizedText = normalizedText.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        // 移除行首行尾的空格
        let lines = normalizedText.components(separatedBy: .newlines)
        let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }

        return trimmedLines.joined(separator: "\n")
    }

    // MARK: - 其他辅助方法

    /// 修正税号格式
    private func correctTaxNumberFormat(_ text: String) -> String {
        // 修正税号中的空格问题
        return text.replacingOccurrences(
            of: #"税号[：:]\s*(\d+(?:\s+\d+)*)"#,
            with: "税号：$1",
            options: .regularExpression
        ).replacingOccurrences(
            of: #"(\d)\s+(\d)"#,
            with: "$1$2",
            options: .regularExpression
        )
    }

    /// 修正商品价格对齐
    private func correctItemPriceAlignment(_ text: String) -> String {
        // 这是一个复杂的功能，需要分析商品名称和价格的对应关系
        // 现在先做简单的格式化
        return text.replacingOccurrences(
            of: #"(\S+)\s+(¥\d+\.?\d*)"#,
            with: "$1 $2",
            options: .regularExpression
        )
    }

    /// 修正收据总计
    private func correctReceiptTotals(_ text: String) -> String {
        let totalPatterns = [
            ("小计", "小计"),
            ("税费", "税费"),
            ("总计", "总计"),
            ("合计", "合计"),
            ("应付", "应付")
        ]

        var correctedText = text
        for (pattern, replacement) in totalPatterns {
            correctedText = correctedText.replacingOccurrences(
                of: pattern + #"\s*[：:]\s*(¥?\d+\.?\d*)"#,
                with: replacement + "：$1",
                options: .regularExpression
            )
        }

        return correctedText
    }

    /// 应用模式修正
    private func applyPatternCorrection(_ text: String, pattern: String, replacement: String) -> String {
        return text.replacingOccurrences(
            of: pattern,
            with: replacement,
            options: .regularExpression
        )
    }
}

// MARK: - 文档类型枚举
enum OCRPostprocessorDocumentType {
    case manual      // 说明书
    case invoice     // 发票
    case receipt     // 收据
    case general     // 通用文档
}