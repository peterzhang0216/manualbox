//
//  OCRImageExtractor.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
@preconcurrency import CoreData
import SwiftUI

// MARK: - 图像提取器
extension OCRService {
    
    func getOptimizedImage(from manual: Manual) async -> PlatformImage? {
        // 直接在当前上下文中获取图片，避免并发问题
        return manual.getPreviewImage()
    }
} 