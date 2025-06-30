import Foundation
import NaturalLanguage

// MARK: - OCR专用文本处理器
/// 专门负责OCR后的文本清理、修正和优化
class OCRTextProcessor {
    
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
    
    /// OCR文本增强处理
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
        
        return processedText
    }
    
    /// 批量文本处理
    func enhanceBatch(_ texts: [String]) -> [String] {
        return texts.map { enhance($0) }
    }
    
    /// 针对特定文档类型的文本处理
    func processForDocumentType(_ text: String, documentType: OCRDocumentType) -> String {
        var processedText = enhance(text)
        
        switch documentType {
        case .manual:
            processedText = applyManualSpecificProcessing(processedText)
        case .invoice:
            processedText = applyInvoiceSpecificProcessing(processedText)
        case .receipt:
            processedText = applyReceiptSpecificProcessing(processedText)
        case .general:
            break // 已经应用了通用处理
        }
        
        return processedText
    }
    
    // MARK: - 基础文本清理
    
    private func performBasicCleaning(_ text: String) -> String {
        var cleanedText = text
        
        // 移除多余的空白字符
        cleanedText = cleanedText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // 移除行首行尾空白
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 统一换行符
        cleanedText = cleanedText.replacingOccurrences(of: "\r\n", with: "\n")
        cleanedText = cleanedText.replacingOccurrences(of: "\r", with: "\n")
        
        // 移除多余的换行符
        cleanedText = cleanedText.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        return cleanedText
    }
    
    // MARK: - OCR错误修正
    
    private func correctCommonOCRErrors(_ text: String) -> String {
        var correctedText = text
        
        // 常见的OCR字符识别错误
        let ocrErrorMappings: [String: String] = [
            "0": "O", // 数字0误识别为字母O
            "1": "l", // 数字1误识别为小写l
            "5": "S", // 数字5误识别为字母S
            "8": "B", // 数字8误识别为字母B
            "rn": "m", // rn误识别为m
            "vv": "w", // vv误识别为w
            "cl": "d", // cl误识别为d
            "li": "h", // li误识别为h
        ]
        
        // 应用错误映射（需要上下文判断）
        for (wrong, correct) in ocrErrorMappings {
            correctedText = applyContextualCorrection(correctedText, wrong: wrong, correct: correct)
        }
        
        return correctedText
    }
    
    private func applyContextualCorrection(_ text: String, wrong: String, correct: String) -> String {
        // 这里应该实现更智能的上下文判断
        // 暂时使用简单的替换
        return text.replacingOccurrences(of: wrong, with: correct)
    }
    
    // MARK: - 语言特定修正
    
    private func applyLanguageSpecificCorrections(_ text: String) -> String {
        let detectedLanguage = detectLanguage(text)
        
        switch detectedLanguage {
        case "zh":
            return applyChineseCorrections(text)
        case "en":
            return applyEnglishCorrections(text)
        case "ja":
            return applyJapaneseCorrections(text)
        default:
            return text
        }
    }
    
    private func applyChineseCorrections(_ text: String) -> String {
        var correctedText = text
        
        // 中文标点符号修正
        correctedText = correctedText.replacingOccurrences(of: ",", with: "，")
        correctedText = correctedText.replacingOccurrences(of: ".", with: "。")
        correctedText = correctedText.replacingOccurrences(of: ";", with: "；")
        correctedText = correctedText.replacingOccurrences(of: ":", with: "：")
        correctedText = correctedText.replacingOccurrences(of: "?", with: "？")
        correctedText = correctedText.replacingOccurrences(of: "!", with: "！")
        
        return correctedText
    }
    
    private func applyEnglishCorrections(_ text: String) -> String {
        var correctedText = text
        
        // 英文常见错误修正
        correctedText = correctedText.replacingOccurrences(of: " i ", with: " I ")
        correctedText = correctedText.replacingOccurrences(of: "^i ", with: "I ", options: .regularExpression)
        
        return correctedText
    }
    
    private func applyJapaneseCorrections(_ text: String) -> String {
        // 日文特定修正
        return text
    }
    
    // MARK: - 技术术语修正
    
    private func correctTechnicalTerms(_ text: String) -> String {
        var correctedText = text
        
        for (wrong, correct) in technicalTermsDictionary {
            correctedText = correctedText.replacingOccurrences(of: wrong, with: correct, options: .caseInsensitive)
        }
        
        return correctedText
    }
    
    // MARK: - 文本格式化
    
    private func formatText(_ text: String) -> String {
        var formattedText = text
        
        // 标题格式化
        formattedText = formatTitles(formattedText)
        
        // 列表格式化
        formattedText = formatLists(formattedText)
        
        // 段落格式化
        formattedText = formatParagraphs(formattedText)
        
        return formattedText
    }
    
    private func formatTitles(_ text: String) -> String {
        // 识别并格式化标题
        return text.replacingOccurrences(
            of: "^([A-Z][A-Za-z\\s]+)$",
            with: "# $1",
            options: .regularExpression
        )
    }
    
    private func formatLists(_ text: String) -> String {
        // 识别并格式化列表项
        return text.replacingOccurrences(
            of: "^([0-9]+\\.|[•·-])\\s*",
            with: "- ",
            options: .regularExpression
        )
    }
    
    private func formatParagraphs(_ text: String) -> String {
        // 段落间距调整
        return text.replacingOccurrences(of: "\n\n+", with: "\n\n", options: .regularExpression)
    }
    
    // MARK: - 智能分段
    
    private func applySmartParagraphing(_ text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: "。！？.!?"))
        var paragraphs: [String] = []
        var currentParagraph = ""
        
        for sentence in sentences {
            let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSentence.isEmpty {
                currentParagraph += trimmedSentence + "。"
                
                // 如果句子长度超过阈值，开始新段落
                if currentParagraph.count > 100 {
                    paragraphs.append(currentParagraph)
                    currentParagraph = ""
                }
            }
        }
        
        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph)
        }
        
        return paragraphs.joined(separator: "\n\n")
    }
    
    // MARK: - 文档类型专用处理
    
    private func applyManualSpecificProcessing(_ text: String) -> String {
        var processedText = text
        
        // 说明书特定的格式化
        processedText = formatManualSections(processedText)
        processedText = formatTechnicalSpecifications(processedText)
        
        return processedText
    }
    
    private func applyInvoiceSpecificProcessing(_ text: String) -> String {
        var processedText = text
        
        // 发票特定的格式化
        processedText = formatInvoiceFields(processedText)
        processedText = formatCurrencyValues(processedText)
        
        return processedText
    }
    
    private func applyReceiptSpecificProcessing(_ text: String) -> String {
        var processedText = text
        
        // 收据特定的格式化
        processedText = formatReceiptItems(processedText)
        processedText = formatPrices(processedText)
        
        return processedText
    }
    
    // MARK: - 辅助方法
    
    private func formatManualSections(_ text: String) -> String {
        // 格式化说明书章节
        return text
    }
    
    private func formatTechnicalSpecifications(_ text: String) -> String {
        // 格式化技术规格
        return text
    }
    
    private func formatInvoiceFields(_ text: String) -> String {
        // 格式化发票字段
        return text
    }
    
    private func formatCurrencyValues(_ text: String) -> String {
        // 格式化货币值
        return text
    }
    
    private func formatReceiptItems(_ text: String) -> String {
        // 格式化收据项目
        return text
    }
    
    private func formatPrices(_ text: String) -> String {
        // 格式化价格
        return text
    }
    
    private func performFinalQualityCheck(_ text: String) -> String {
        // 最终质量检查
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func detectLanguage(_ text: String) -> String? {
        if #available(iOS 14.0, macOS 11.0, *) {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)
            return recognizer.dominantLanguage?.rawValue
        }
        return nil
    }
    
    private func loadCommonWordsDictionary() -> Set<String> {
        // 加载常见词汇字典
        return Set(["the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"])
    }
    
    private func loadTechnicalTermsDictionary() -> [String: String] {
        // 加载技术术语字典
        return [
            "wifi": "Wi-Fi",
            "bluetooth": "Bluetooth",
            "usb": "USB",
            "hdmi": "HDMI",
            "cpu": "CPU",
            "gpu": "GPU",
            "ram": "RAM",
            "ssd": "SSD"
        ]
    }
}
