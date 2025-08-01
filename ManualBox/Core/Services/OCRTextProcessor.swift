import Foundation
import NaturalLanguage

// MARK: - OCR文本处理器
class OCRTextProcessor {
    private let languageRecognizer = NLLanguageRecognizer()
    
    init() {}
    
    // MARK: - 文本处理方法
    func processText(_ text: String) -> String {
        let cleanedText = cleanText(text)
        let correctedText = correctCommonErrors(cleanedText)
        return enhanceReadability(correctedText)
    }
    
    func detectLanguage(in text: String) -> String? {
        languageRecognizer.processString(text)
        guard let language = languageRecognizer.dominantLanguage else { return nil }
        return language.rawValue
    }
    
    func extractKeywords(from text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        var keywords: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange])
            if token.count > 3 && !isStopWord(token) {
                keywords.append(token)
            }
            return true
        }
        
        return Array(Set(keywords)).sorted()
    }
    
    // MARK: - 私有辅助方法
    private func cleanText(_ text: String) -> String {
        var cleaned = text
        
        // 移除多余的空白字符
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // 修正常见的OCR错误
        cleaned = cleaned.replacingOccurrences(of: "0", with: "O", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "1", with: "l", options: .caseInsensitive)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func correctCommonErrors(_ text: String) -> String {
        var corrected = text
        
        // 常见OCR错误修正映射
        let corrections = [
            "rn": "m",
            "vv": "w",
            "cl": "d",
            "ii": "n"
        ]
        
        for (error, correction) in corrections {
            corrected = corrected.replacingOccurrences(of: error, with: correction)
        }
        
        return corrected
    }
    
    private func enhanceReadability(_ text: String) -> String {
        var enhanced = text
        
        // 确保句子间有适当的间距
        enhanced = enhanced.replacingOccurrences(of: "\\. ", with: ". ", options: .regularExpression)
        enhanced = enhanced.replacingOccurrences(of: "\\.", with: ". ", options: .regularExpression)
        
        return enhanced
    }
    
    private func isStopWord(_ word: String) -> Bool {
        let stopWords = ["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "是", "的", "了", "在", "有", "和", "与"]
        return stopWords.contains(word.lowercased())
    }
}