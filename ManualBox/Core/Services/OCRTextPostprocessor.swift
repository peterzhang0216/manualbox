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
    
    // MARK: - 主要处理方法
    func enhance(_ text: String) -> String {
        var processedText = text
        
        // 1. 基础清理
        processedText = performBasicCleaning(processedText)
        
        // 2. 修正常见的OCR错误
        processedText = correctCommonOCRErrors(processedText)
        
        // 3. 语言特定的修正
        processedText = applyLanguageSpecificCorrections(processedText)
        
        // 4. 格式化处理
        processedText = formatText(processedText)
        
        // 5. 智能分段
        processedText = applySmartParagraphing(processedText)
        
        return processedText.trimmingCharacters(in: .whitespacesAndNewlines)
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
} 