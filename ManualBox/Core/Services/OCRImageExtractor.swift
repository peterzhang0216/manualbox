//
//  OCRImageExtractor.swift
//  ManualBox
//
//  Created by Peter's Mac on 2025/4/27.
//

import Foundation
import CoreData
import SwiftUI

// MARK: - 图像提取器
extension OCRService {
    
    func getOptimizedImage(from manual: Manual) async -> PlatformImage? {
        return await withCheckedContinuation { continuation in
            // 创建manual的本地副本以避免Sendable问题
            let manualObjectID = manual.objectID
            let context = manual.managedObjectContext
            
            DispatchQueue.global(qos: .userInitiated).async { [context] in
                var image: PlatformImage?
                
                // 在后台上下文中安全访问Core Data对象
                context?.perform {
                    if let bgManual = try? context?.existingObject(with: manualObjectID) as? Manual {
                        image = bgManual.getPreviewImage()
                    }
                    continuation.resume(returning: image)
                }
            }
        }
    }
} 