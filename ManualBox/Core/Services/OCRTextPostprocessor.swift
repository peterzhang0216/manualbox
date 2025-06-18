//
//  OCRTextPostprocessor.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation

// MARK: - 文本后处理器
class TextPostprocessor {
    func enhance(_ text: String) -> String {
        var processedText = text
        
        // 1. 去除多余的空白字符
        processedText = processedText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // 2. 修正常见的OCR错误
        processedText = correctCommonOCRErrors(processedText)
        
        // 3. 格式化换行
        processedText = formatLineBreaks(processedText)
        
        return processedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func correctCommonOCRErrors(_ text: String) -> String {
        var correctedText = text
        
        // 常见OCR错误修正规则
        let corrections: [(String, String)] = [
            ("O", "0"), // 字母O误识别为数字0的情况
            ("l", "1"), // 字母l误识别为数字1的情况
            ("｜", "|"), // 全角符号修正
            ("．", "."), // 全角句号修正
            ("，", ","), // 中文逗号保持
        ]
        
        for (wrong, correct) in corrections {
            // 在特定上下文中应用修正
            correctedText = applyCorrectionInContext(correctedText, wrong: wrong, correct: correct)
        }
        
        return correctedText
    }
    
    private func applyCorrectionInContext(_ text: String, wrong: String, correct: String) -> String {
        // 在数字上下文中的修正
        let numberPattern = "\\d+[" + NSRegularExpression.escapedPattern(for: wrong) + "]\\d*|\\d*[" + NSRegularExpression.escapedPattern(for: wrong) + "]\\d+"
        
        do {
            let regex = try NSRegularExpression(pattern: numberPattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            
            _ = regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: range,
                withTemplate: ""
            )
            
            // 手动处理每个匹配项
            var correctedText = text
            let matches = regex.matches(in: text, options: [], range: range)
            
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
            // 如果正则表达式失败，返回原文本
            return text
        }
    }
    
    private func formatLineBreaks(_ text: String) -> String {
        // 智能换行处理
        return text.replacingOccurrences(of: "(?<=[。！？])\n(?=[A-Za-z0-9\\u4e00-\\u9fff])", with: "\n\n", options: .regularExpression)
    }
} 