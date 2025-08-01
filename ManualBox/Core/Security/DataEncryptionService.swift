//
//  DataEncryptionService.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  数据加密服务 - 提供敏感数据加密和解密功能
//

import Foundation
import CryptoKit
import Security

// MARK: - 加密错误类型
enum EncryptionError: Error, LocalizedError {
    case keyGenerationFailed
    case keyNotFound
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case keychainError(OSStatus)
    case biometricAuthenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "密钥生成失败"
        case .keyNotFound:
            return "未找到加密密钥"
        case .encryptionFailed:
            return "数据加密失败"
        case .decryptionFailed:
            return "数据解密失败"
        case .invalidData:
            return "无效的数据格式"
        case .keychainError(let status):
            return "钥匙串操作失败: \(status)"
        case .biometricAuthenticationFailed:
            return "生物识别验证失败"
        }
    }
}

// MARK: - 加密数据模型
struct EncryptedData: Codable {
    let encryptedContent: Data
    let nonce: Data
    let timestamp: Date
    let algorithm: String
    
    init(encryptedContent: Data, nonce: Data, algorithm: String = "AES-GCM") {
        self.encryptedContent = encryptedContent
        self.nonce = nonce
        self.timestamp = Date()
        self.algorithm = algorithm
    }
}

// MARK: - 数据加密服务
@MainActor
class DataEncryptionService: ObservableObject {
    static let shared = DataEncryptionService()
    
    // MARK: - Published Properties
    @Published private(set) var isEncryptionEnabled = false
    @Published private(set) var encryptionStatus: EncryptionStatus = .disabled
    @Published private(set) var lastEncryptionError: String?
    
    // MARK: - Private Properties
    private let keyManager = KeyManager.shared
    private let biometricManager = BiometricAuthenticationManager.shared
    
    // 加密配置
    private struct EncryptionConfig {
        static let keySize = 256 // AES-256
        static let nonceSize = 12 // 96 bits for AES-GCM
        static let tagSize = 16 // 128 bits authentication tag
    }
    
    // 需要加密的数据类型
    enum SensitiveDataType: String, CaseIterable {
        case personalInfo = "personal_info"
        case financialData = "financial_data"
        case passwords = "passwords"
        case notes = "notes"
        case documents = "documents"
        
        var keyIdentifier: String {
            return "encryption_key_\(rawValue)"
        }
        
        var requiresBiometric: Bool {
            switch self {
            case .personalInfo, .financialData, .passwords:
                return true
            case .notes, .documents:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        loadEncryptionSettings()
        setupEncryptionStatus()
    }
    
    // MARK: - Public Methods
    
    /// 启用数据加密
    func enableEncryption() async throws {
        do {
            // 生成主密钥
            try await keyManager.generateMasterKey()
            
            // 为每种数据类型生成专用密钥
            for dataType in SensitiveDataType.allCases {
                try await keyManager.generateKey(for: dataType.keyIdentifier)
            }
            
            isEncryptionEnabled = true
            encryptionStatus = .enabled
            saveEncryptionSettings()
            
            print("🔐 数据加密已启用")
            
        } catch {
            lastEncryptionError = error.localizedDescription
            encryptionStatus = .error
            throw error
        }
    }
    
    /// 禁用数据加密
    func disableEncryption() async throws {
        do {
            // 删除所有加密密钥
            try await keyManager.deleteAllKeys()
            
            isEncryptionEnabled = false
            encryptionStatus = .disabled
            saveEncryptionSettings()
            
            print("🔐 数据加密已禁用")
            
        } catch {
            lastEncryptionError = error.localizedDescription
            throw error
        }
    }
    
    /// 加密敏感数据
    func encryptSensitiveData<T: Codable>(_ data: T, type: SensitiveDataType) async throws -> EncryptedData {
        guard isEncryptionEnabled else {
            throw EncryptionError.keyNotFound
        }
        
        do {
            // 如果需要生物识别验证
            if type.requiresBiometric {
                let isAuthenticated = await biometricManager.authenticateUser(reason: "访问加密数据需要验证身份")
                guard isAuthenticated else {
                    throw EncryptionError.biometricAuthenticationFailed
                }
            }
            
            // 获取加密密钥
            let key = try await keyManager.getKey(for: type.keyIdentifier)
            
            // 序列化数据
            let jsonData = try JSONEncoder().encode(data)
            
            // 生成随机nonce
            let nonce = try generateNonce()
            
            // 使用AES-GCM加密
            let sealedBox = try AES.GCM.seal(jsonData, using: key, nonce: AES.GCM.Nonce(data: nonce))
            
            let encryptedContent = sealedBox.ciphertext
            
            let encryptedData = EncryptedData(
                encryptedContent: encryptedContent + sealedBox.tag,
                nonce: nonce
            )
            
            print("🔐 数据已加密: \(type.rawValue)")
            return encryptedData
            
        } catch {
            lastEncryptionError = error.localizedDescription
            throw error
        }
    }
    
    /// 解密敏感数据
    func decryptSensitiveData<T: Codable>(_ encryptedData: EncryptedData, type: SensitiveDataType, as dataType: T.Type) async throws -> T {
        guard isEncryptionEnabled else {
            throw EncryptionError.keyNotFound
        }
        
        do {
            // 如果需要生物识别验证
            if type.requiresBiometric {
                let isAuthenticated = await biometricManager.authenticateUser(reason: "访问加密数据需要验证身份")
                guard isAuthenticated else {
                    throw EncryptionError.biometricAuthenticationFailed
                }
            }
            
            // 获取解密密钥
            let key = try await keyManager.getKey(for: type.keyIdentifier)
            
            // 分离密文和认证标签
            let tagSize = EncryptionConfig.tagSize
            guard encryptedData.encryptedContent.count >= tagSize else {
                throw EncryptionError.invalidData
            }
            
            let ciphertext = encryptedData.encryptedContent.dropLast(tagSize)
            let tag = encryptedData.encryptedContent.suffix(tagSize)
            
            // 创建AES.GCM.Nonce
            guard let nonce = try? AES.GCM.Nonce(data: encryptedData.nonce) else {
                throw EncryptionError.invalidData
            }
            
            // 创建SealedBox
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            
            // 解密数据
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            
            // 反序列化数据
            let result = try JSONDecoder().decode(dataType, from: decryptedData)
            
            print("🔐 数据已解密: \(type.rawValue)")
            return result
            
        } catch {
            lastEncryptionError = error.localizedDescription
            throw error
        }
    }
    
    /// 加密字符串数据
    func encryptString(_ string: String, type: SensitiveDataType) async throws -> EncryptedData {
        return try await encryptSensitiveData(string, type: type)
    }
    
    /// 解密字符串数据
    func decryptString(_ encryptedData: EncryptedData, type: SensitiveDataType) async throws -> String {
        return try await decryptSensitiveData(encryptedData, type: type, as: String.self)
    }
    
    /// 加密文件数据
    func encryptFileData(_ data: Data, type: SensitiveDataType) async throws -> EncryptedData {
        guard isEncryptionEnabled else {
            throw EncryptionError.keyNotFound
        }
        
        do {
            // 获取加密密钥
            let key = try await keyManager.getKey(for: type.keyIdentifier)
            
            // 生成随机nonce
            let nonce = try generateNonce()
            
            // 使用AES-GCM加密
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: AES.GCM.Nonce(data: nonce))
            
            let encryptedContent = sealedBox.ciphertext
            
            let encryptedData = EncryptedData(
                encryptedContent: encryptedContent + sealedBox.tag,
                nonce: nonce
            )
            
            print("🔐 文件数据已加密: \(data.count) bytes")
            return encryptedData
            
        } catch {
            lastEncryptionError = error.localizedDescription
            throw error
        }
    }
    
    /// 解密文件数据
    func decryptFileData(_ encryptedData: EncryptedData, type: SensitiveDataType) async throws -> Data {
        guard isEncryptionEnabled else {
            throw EncryptionError.keyNotFound
        }
        
        do {
            // 获取解密密钥
            let key = try await keyManager.getKey(for: type.keyIdentifier)
            
            // 分离密文和认证标签
            let tagSize = EncryptionConfig.tagSize
            guard encryptedData.encryptedContent.count >= tagSize else {
                throw EncryptionError.invalidData
            }
            
            let ciphertext = encryptedData.encryptedContent.dropLast(tagSize)
            let tag = encryptedData.encryptedContent.suffix(tagSize)
            
            // 创建AES.GCM.Nonce
            guard let nonce = try? AES.GCM.Nonce(data: encryptedData.nonce) else {
                throw EncryptionError.invalidData
            }
            
            // 创建SealedBox
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            
            // 解密数据
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            
            print("🔐 文件数据已解密: \(decryptedData.count) bytes")
            return decryptedData
            
        } catch {
            lastEncryptionError = error.localizedDescription
            throw error
        }
    }
    
    /// 重新生成加密密钥
    func regenerateKeys() async throws {
        do {
            // 删除现有密钥
            try await keyManager.deleteAllKeys()
            
            // 重新生成密钥
            try await enableEncryption()
            
            print("🔐 加密密钥已重新生成")
            
        } catch {
            lastEncryptionError = error.localizedDescription
            throw error
        }
    }
    
    /// 验证加密完整性
    func verifyEncryptionIntegrity() async -> Bool {
        do {
            // 测试数据
            let testData = "encryption_test_\(UUID().uuidString)"
            
            // 加密测试
            let encrypted = try await encryptString(testData, type: .notes)
            
            // 解密测试
            let decrypted = try await decryptString(encrypted, type: .notes)
            
            return testData == decrypted
            
        } catch {
            lastEncryptionError = error.localizedDescription
            return false
        }
    }
    
    /// 获取加密统计信息
    func getEncryptionStatistics() -> EncryptionStatistics {
        return EncryptionStatistics(
            isEnabled: isEncryptionEnabled,
            status: encryptionStatus,
            supportedDataTypes: SensitiveDataType.allCases.map { $0.rawValue },
            lastError: lastEncryptionError
        )
    }
    
    // MARK: - Private Methods
    
    private func generateNonce() throws -> Data {
        var nonce = Data(count: EncryptionConfig.nonceSize)
        let result = nonce.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, EncryptionConfig.nonceSize, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw EncryptionError.keyGenerationFailed
        }
        
        return nonce
    }
    
    private func loadEncryptionSettings() {
        isEncryptionEnabled = UserDefaults.standard.bool(forKey: "DataEncryptionEnabled")
    }
    
    private func saveEncryptionSettings() {
        UserDefaults.standard.set(isEncryptionEnabled, forKey: "DataEncryptionEnabled")
    }
    
    private func setupEncryptionStatus() {
        if isEncryptionEnabled {
            Task {
                let isValid = await verifyEncryptionIntegrity()
                encryptionStatus = isValid ? .enabled : .error
            }
        } else {
            encryptionStatus = .disabled
        }
    }
}

// MARK: - 加密状态枚举
enum EncryptionStatus {
    case disabled
    case enabled
    case error
    
    var description: String {
        switch self {
        case .disabled: return "已禁用"
        case .enabled: return "已启用"
        case .error: return "错误"
        }
    }
    
    var color: String {
        switch self {
        case .disabled: return "gray"
        case .enabled: return "green"
        case .error: return "red"
        }
    }
}

// MARK: - 加密统计信息
struct EncryptionStatistics {
    let isEnabled: Bool
    let status: EncryptionStatus
    let supportedDataTypes: [String]
    let lastError: String?
}