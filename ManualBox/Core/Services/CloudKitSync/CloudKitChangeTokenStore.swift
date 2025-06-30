//
//  CloudKitChangeTokenStore.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//

import Foundation
import CloudKit

// MARK: - 变更令牌存储管理
class ChangeTokenStore {
    private let userDefaults = UserDefaults.standard
    private let tokenKey = "CloudKitSyncToken"
    private let zoneTokensKey = "CloudKitZoneTokens"
    
    // MARK: - 数据库级别令牌
    
    func saveToken(_ token: CKServerChangeToken) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            userDefaults.set(data, forKey: tokenKey)
            print("✅ 保存同步令牌成功")
        } catch {
            print("❌ 保存同步令牌失败: \(error)")
        }
    }
    
    func loadToken() -> CKServerChangeToken? {
        guard let data = userDefaults.data(forKey: tokenKey) else {
            print("📝 未找到同步令牌，将执行完整同步")
            return nil
        }
        
        do {
            let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
            print("✅ 加载同步令牌成功")
            return token
        } catch {
            print("❌ 加载同步令牌失败: \(error)")
            return nil
        }
    }
    
    func clearToken() {
        userDefaults.removeObject(forKey: tokenKey)
        print("🗑️ 清除同步令牌")
    }
    
    // MARK: - 区域级别令牌
    
    func saveZoneToken(_ token: CKServerChangeToken, for zoneID: CKRecordZone.ID) {
        var zoneTokens = loadZoneTokens()
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            zoneTokens[zoneID.zoneName] = data
            
            let allTokensData = try NSKeyedArchiver.archivedData(withRootObject: zoneTokens, requiringSecureCoding: true)
            userDefaults.set(allTokensData, forKey: zoneTokensKey)
            
            print("✅ 保存区域令牌成功: \(zoneID.zoneName)")
        } catch {
            print("❌ 保存区域令牌失败: \(error)")
        }
    }
    
    func loadZoneToken(for zoneID: CKRecordZone.ID) -> CKServerChangeToken? {
        let zoneTokens = loadZoneTokens()
        
        guard let data = zoneTokens[zoneID.zoneName] else {
            print("📝 未找到区域令牌: \(zoneID.zoneName)")
            return nil
        }
        
        do {
            let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
            print("✅ 加载区域令牌成功: \(zoneID.zoneName)")
            return token
        } catch {
            print("❌ 加载区域令牌失败: \(error)")
            return nil
        }
    }
    
    func clearZoneToken(for zoneID: CKRecordZone.ID) {
        var zoneTokens = loadZoneTokens()
        zoneTokens.removeValue(forKey: zoneID.zoneName)
        
        do {
            let allTokensData = try NSKeyedArchiver.archivedData(withRootObject: zoneTokens, requiringSecureCoding: true)
            userDefaults.set(allTokensData, forKey: zoneTokensKey)
            print("🗑️ 清除区域令牌: \(zoneID.zoneName)")
        } catch {
            print("❌ 清除区域令牌失败: \(error)")
        }
    }
    
    func clearAllZoneTokens() {
        userDefaults.removeObject(forKey: zoneTokensKey)
        print("🗑️ 清除所有区域令牌")
    }
    
    // MARK: - 私有方法
    
    private func loadZoneTokens() -> [String: Data] {
        guard let data = userDefaults.data(forKey: zoneTokensKey) else {
            return [:]
        }
        
        do {
            let tokens = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: data) as? [String: Data]
            return tokens ?? [:]
        } catch {
            print("❌ 加载区域令牌字典失败: \(error)")
            return [:]
        }
    }
    
    // MARK: - 令牌验证
    
    func validateToken(_ token: CKServerChangeToken?) -> Bool {
        guard let token = token else { return false }
        
        // 这里可以添加令牌有效性检查逻辑
        // 例如检查令牌是否过期等
        return true
    }
    
    // MARK: - 调试信息
    
    func getTokenInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        
        if let token = loadToken() {
            info["hasMainToken"] = true
            info["mainTokenDescription"] = token.description
        } else {
            info["hasMainToken"] = false
        }
        
        let zoneTokens = loadZoneTokens()
        info["zoneTokenCount"] = zoneTokens.count
        info["zoneNames"] = Array(zoneTokens.keys)
        
        return info
    }
}