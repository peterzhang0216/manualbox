//
//  KeyManager.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  密钥管理器 - 负责加密密钥的生成、存储和管理
//

import Foundation
import CryptoKit
import Security
import LocalAuthentication

// MARK: - 密钥管理器
@MainActor
class KeyManager: ObservableObject {
    static let shared = KeyManager()
    
    // MARK: - Published Properties
    @Published private(set) var availableKeys: Set<String> = []
    @Published private(set) var keyGenerationInProgress = false
    @Published private(set) var lastKeyError: String?
    
    // MARK: - Private Properties
    private let keychain = KeychainManager.shared
    private let masterKeyIdentifier = "master_encryption_key"
    
    // 密钥配置
    private struct KeyConfig {
        static let keySize = 32 // 256 bits for AES-256
        static let keyTag = "com.manualbox.encryption.key"
        static let accessGroup = "com.manualbox.keychain"
    }
    
    // MARK: - Initialization
    private init() {
        loadAvailableKeys()
    }
    
    // MARK: - Public Methods
    
    /// 生成主密钥
    func generateMasterKey() async throws {
        keyGenerationInProgress = true
        lastKeyError = nil
        
        do {
            // 检查是否已存在主密钥
            if await keyExists(masterKeyIdentifier) {
                print("🔑 主密钥已存在，跳过生成")
                keyGenerationInProgress = false
                return
            }
            
            // 生成新的主密钥
            let masterKey = SymmetricKey(size: .bits256)
            
            // 存储到钥匙串
            try await keychain.storeKey(
                masterKey,
                identifier: masterKeyIdentifier,
                requiresBiometric: true,
                description: "ManualBox 主加密密钥"
            )
            
            availableKeys.insert(masterKeyIdentifier)
            keyGenerationInProgress = false
            
            print("🔑 主密钥生成成功")
            
        } catch {
            lastKeyError = error.localizedDescription
            keyGenerationInProgress = false
            throw error
        }
    }
    
    /// 为特定用途生成密钥
    func generateKey(for identifier: String, requiresBiometric: Bool = false) async throws {
        keyGenerationInProgress = true
        lastKeyError = nil
        
        do {
            // 检查是否已存在密钥
            if await keyExists(identifier) {
                print("🔑 密钥已存在: \(identifier)")
                keyGenerationInProgress = false
                return
            }
            
            // 生成新密钥
            let key = SymmetricKey(size: .bits256)
            
            // 存储到钥匙串
            try await keychain.storeKey(
                key,
                identifier: identifier,
                requiresBiometric: requiresBiometric,
                description: "ManualBox 加密密钥: \(identifier)"
            )
            
            availableKeys.insert(identifier)
            keyGenerationInProgress = false
            
            print("🔑 密钥生成成功: \(identifier)")
            
        } catch {
            lastKeyError = error.localizedDescription
            keyGenerationInProgress = false
            throw error
        }
    }
    
    /// 获取密钥
    func getKey(for identifier: String) async throws -> SymmetricKey {
        do {
            let key = try await keychain.retrieveKey(identifier: identifier)
            print("🔑 密钥获取成功: \(identifier)")
            return key
            
        } catch {
            lastKeyError = error.localizedDescription
            throw error
        }
    }
    
    /// 删除密钥
    func deleteKey(for identifier: String) async throws {
        do {
            try await keychain.deleteKey(identifier: identifier)
            availableKeys.remove(identifier)
            
            print("🔑 密钥删除成功: \(identifier)")
            
        } catch {
            lastKeyError = error.localizedDescription
            throw error
        }
    }
    
    /// 删除所有密钥
    func deleteAllKeys() async throws {
        do {
            for identifier in availableKeys {
                try await keychain.deleteKey(identifier: identifier)
            }
            
            availableKeys.removeAll()
            print("🔑 所有密钥已删除")
            
        } catch {
            lastKeyError = error.localizedDescription
            throw error
        }
    }
    
    /// 检查密钥是否存在
    func keyExists(_ identifier: String) async -> Bool {
        do {
            _ = try await keychain.retrieveKey(identifier: identifier)
            return true
        } catch {
            return false
        }
    }
    
    /// 获取主密钥
    func getMasterKey() async throws -> SymmetricKey {
        return try await getKey(for: masterKeyIdentifier)
    }
    
    /// 重新生成所有密钥
    func regenerateAllKeys() async throws {
        keyGenerationInProgress = true
        
        do {
            // 备份现有密钥标识符
            let existingKeys = availableKeys
            
            // 删除所有现有密钥
            try await deleteAllKeys()
            
            // 重新生成主密钥
            try await generateMasterKey()
            
            // 重新生成其他密钥
            for identifier in existingKeys {
                if identifier != masterKeyIdentifier {
                    try await generateKey(for: identifier)
                }
            }
            
            keyGenerationInProgress = false
            print("🔑 所有密钥重新生成完成")
            
        } catch {
            lastKeyError = error.localizedDescription
            keyGenerationInProgress = false
            throw error
        }
    }
    
    /// 验证密钥完整性
    func verifyKeyIntegrity() async -> Bool {
        do {
            // 检查主密钥
            _ = try await getMasterKey()
            
            // 检查其他密钥
            for identifier in availableKeys {
                _ = try await getKey(for: identifier)
            }
            
            return true
            
        } catch {
            lastKeyError = error.localizedDescription
            return false
        }
    }
    
    /// 获取密钥统计信息
    func getKeyStatistics() -> KeyStatistics {
        return KeyStatistics(
            totalKeys: availableKeys.count,
            hasMasterKey: availableKeys.contains(masterKeyIdentifier),
            keyIdentifiers: Array(availableKeys),
            lastError: lastKeyError
        )
    }
    
    // MARK: - Private Methods
    
    private func loadAvailableKeys() {
        Task {
            // 检查主密钥
            if await keyExists(masterKeyIdentifier) {
                availableKeys.insert(masterKeyIdentifier)
            }
            
            // 检查其他已知密钥
            let knownKeys = [
                "encryption_key_personal_info",
                "encryption_key_financial_data",
                "encryption_key_passwords",
                "encryption_key_notes",
                "encryption_key_documents"
            ]
            
            for keyId in knownKeys {
                if await keyExists(keyId) {
                    availableKeys.insert(keyId)
                }
            }
        }
    }
}

// MARK: - 钥匙串管理器
@MainActor
class KeychainManager: ObservableObject {
    static let shared = KeychainManager()
    
    private init() {}
    
    /// 存储密钥到钥匙串
    func storeKey(
        _ key: SymmetricKey,
        identifier: String,
        requiresBiometric: Bool = false,
        description: String
    ) async throws {
        
        // 将密钥转换为Data
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // 构建钥匙串查询
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "ManualBox-Encryption",
            kSecValueData as String: keyData,
            kSecAttrDescription as String: description,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 如果需要生物识别验证
        if requiresBiometric {
            let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryAny,
                nil
            )
            
            if let access = access {
                query[kSecAttrAccessControl as String] = access
            }
        }
        
        // 删除现有项目（如果存在）
        SecItemDelete(query as CFDictionary)
        
        // 添加新项目
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw EncryptionError.keychainError(status)
        }
        
        print("🔑 密钥已存储到钥匙串: \(identifier)")
    }
    
    /// 从钥匙串检索密钥
    func retrieveKey(identifier: String) async throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "ManualBox-Encryption",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw EncryptionError.keychainError(status)
        }
        
        guard let keyData = result as? Data else {
            throw EncryptionError.invalidData
        }
        
        let key = SymmetricKey(data: keyData)
        print("🔑 密钥已从钥匙串检索: \(identifier)")
        
        return key
    }
    
    /// 从钥匙串删除密钥
    func deleteKey(identifier: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "ManualBox-Encryption"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EncryptionError.keychainError(status)
        }
        
        print("🔑 密钥已从钥匙串删除: \(identifier)")
    }
}

// MARK: - 生物识别认证管理器
@MainActor
class BiometricAuthenticationManager: ObservableObject {
    static let shared = BiometricAuthenticationManager()
    
    @Published private(set) var biometricType: LABiometryType = .none
    @Published private(set) var isBiometricAvailable = false
    
    private let context = LAContext()
    
    private init() {
        checkBiometricAvailability()
    }
    
    /// 检查生物识别可用性
    func checkBiometricAvailability() {
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isBiometricAvailable = true
            biometricType = context.biometryType
        } else {
            isBiometricAvailable = false
            biometricType = .none
        }
    }
    
    /// 执行生物识别认证
    func authenticateUser(reason: String) async -> Bool {
        guard isBiometricAvailable else {
            return false
        }
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            print("🔐 生物识别认证: \(result ? "成功" : "失败")")
            return result
            
        } catch {
            print("🔐 生物识别认证错误: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 获取生物识别类型描述
    var biometricTypeDescription: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "无"
        @unknown default:
            return "未知"
        }
    }
}

// MARK: - 密钥统计信息
struct KeyStatistics {
    let totalKeys: Int
    let hasMasterKey: Bool
    let keyIdentifiers: [String]
    let lastError: String?
}