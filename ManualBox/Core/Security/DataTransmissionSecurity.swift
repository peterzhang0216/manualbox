//
//  DataTransmissionSecurity.swift
//  ManualBox
//
//  Created by Assistant on 2024/12/19.
//  数据传输安全 - 处理网络传输数据的加密和验证
//

import Foundation
import CryptoKit
import Network

// MARK: - 传输安全错误
enum TransmissionSecurityError: Error, LocalizedError {
    case certificateValidationFailed
    case tlsHandshakeFailed
    case dataIntegrityCheckFailed
    case encryptionKeyExchangeFailed
    case unsupportedProtocolVersion
    case networkSecurityError(Error)
    
    var errorDescription: String? {
        switch self {
        case .certificateValidationFailed:
            return "证书验证失败"
        case .tlsHandshakeFailed:
            return "TLS握手失败"
        case .dataIntegrityCheckFailed:
            return "数据完整性检查失败"
        case .encryptionKeyExchangeFailed:
            return "加密密钥交换失败"
        case .unsupportedProtocolVersion:
            return "不支持的协议版本"
        case .networkSecurityError(let error):
            return "网络安全错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - 传输数据模型
struct SecureTransmissionData: Codable {
    let encryptedPayload: Data
    let signature: Data
    let timestamp: Date
    let nonce: Data
    let version: String
    
    init(encryptedPayload: Data, signature: Data, nonce: Data, version: String = "1.0") {
        self.encryptedPayload = encryptedPayload
        self.signature = signature
        self.timestamp = Date()
        self.nonce = nonce
        self.version = version
    }
}

// MARK: - 数据传输安全管理器
@MainActor
class DataTransmissionSecurityManager: ObservableObject {
    static let shared = DataTransmissionSecurityManager()
    
    // MARK: - Published Properties
    @Published private(set) var isSecureTransmissionEnabled = true
    @Published private(set) var certificateValidationEnabled = true
    @Published private(set) var lastTransmissionError: String?
    @Published private(set) var transmissionStatistics = TransmissionStatistics()
    
    // MARK: - Private Properties
    private let keyManager = KeyManager.shared
    private let encryptionService = DataEncryptionService.shared
    
    // 传输安全配置
    private struct SecurityConfig {
        static let supportedTLSVersions: [tls_protocol_version_t] = [.TLSv12, .TLSv13]
        static let requiredCipherSuites: [String] = [
            "TLS_AES_256_GCM_SHA384",
            "TLS_CHACHA20_POLY1305_SHA256",
            "TLS_AES_128_GCM_SHA256"
        ]
        static let certificatePinning = true
        static let maxRetryAttempts = 3
    }
    
    // MARK: - Initialization
    private init() {
        loadSecuritySettings()
    }
    
    // MARK: - Public Methods
    
    /// 配置安全传输设置
    func configureSecureTransmission(
        enableSecureTransmission: Bool = true,
        enableCertificateValidation: Bool = true
    ) {
        isSecureTransmissionEnabled = enableSecureTransmission
        certificateValidationEnabled = enableCertificateValidation
        saveSecuritySettings()
        
        print("🔒 传输安全配置已更新")
    }
    
    /// 加密传输数据
    func encryptTransmissionData<T: Codable>(_ data: T) async throws -> SecureTransmissionData {
        guard isSecureTransmissionEnabled else {
            throw TransmissionSecurityError.unsupportedProtocolVersion
        }
        
        do {
            // 序列化数据
            let jsonData = try JSONEncoder().encode(data)
            
            // 生成传输密钥
            let transmissionKey = SymmetricKey(size: .bits256)
            
            // 生成随机nonce
            let nonce = try generateSecureNonce()
            
            // 使用AES-GCM加密数据
            let sealedBox = try AES.GCM.seal(jsonData, using: transmissionKey, nonce: AES.GCM.Nonce(data: nonce))
            
            let encryptedPayload = sealedBox.ciphertext
            
            // 创建数字签名
            let signature = try createDigitalSignature(for: encryptedPayload + nonce)
            
            let secureData = SecureTransmissionData(
                encryptedPayload: encryptedPayload + sealedBox.tag,
                signature: signature,
                nonce: nonce
            )
            
            // 更新统计信息
            transmissionStatistics.encryptedTransmissions += 1
            transmissionStatistics.totalDataEncrypted += Int64(encryptedPayload.count)
            
            print("🔒 传输数据已加密: \(jsonData.count) -> \(encryptedPayload.count) bytes")
            return secureData
            
        } catch {
            lastTransmissionError = error.localizedDescription
            transmissionStatistics.failedTransmissions += 1
            throw error
        }
    }
    
    /// 解密传输数据
    func decryptTransmissionData<T: Codable>(_ secureData: SecureTransmissionData, as type: T.Type) async throws -> T {
        guard isSecureTransmissionEnabled else {
            throw TransmissionSecurityError.unsupportedProtocolVersion
        }
        
        do {
            // 验证数字签名
            let isSignatureValid = try verifyDigitalSignature(
                signature: secureData.signature,
                data: secureData.encryptedPayload + secureData.nonce
            )
            
            guard isSignatureValid else {
                throw TransmissionSecurityError.dataIntegrityCheckFailed
            }
            
            // 分离密文和认证标签
            let tagSize = 16 // AES-GCM tag size
            guard secureData.encryptedPayload.count >= tagSize else {
                throw TransmissionSecurityError.dataIntegrityCheckFailed
            }
            
            let ciphertext = secureData.encryptedPayload.dropLast(tagSize)
            let tag = secureData.encryptedPayload.suffix(tagSize)
            
            // 重建传输密钥（在实际应用中，这应该通过安全的密钥交换协议获得）
            let transmissionKey = SymmetricKey(size: .bits256)
            
            // 创建AES.GCM.Nonce
            let nonce = try AES.GCM.Nonce(data: secureData.nonce)
            
            // 创建SealedBox
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            
            // 解密数据
            let decryptedData = try AES.GCM.open(sealedBox, using: transmissionKey)
            
            // 反序列化数据
            let result = try JSONDecoder().decode(type, from: decryptedData)
            
            // 更新统计信息
            transmissionStatistics.decryptedTransmissions += 1
            transmissionStatistics.totalDataDecrypted += Int64(decryptedData.count)
            
            print("🔒 传输数据已解密: \(secureData.encryptedPayload.count) -> \(decryptedData.count) bytes")
            return result
            
        } catch {
            lastTransmissionError = error.localizedDescription
            transmissionStatistics.failedTransmissions += 1
            throw error
        }
    }
    
    /// 创建安全的网络会话配置
    func createSecureURLSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        
        // 启用TLS 1.2+
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        
        // 配置安全策略
        configuration.httpShouldUsePipelining = false
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        
        // 设置超时
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        
        // 禁用缓存敏感数据
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        return configuration
    }
    
    /// 验证服务器证书
    func validateServerCertificate(_ trust: SecTrust, for host: String) async -> Bool {
        guard certificateValidationEnabled else {
            return true
        }
        
        do {
            // 设置验证策略
            let policy = SecPolicyCreateSSL(true, host as CFString)
            SecTrustSetPolicies(trust, policy)
            
            // 执行证书验证
            var result: SecTrustResultType = .invalid
            let status = SecTrustEvaluate(trust, &result)
            
            guard status == errSecSuccess else {
                throw TransmissionSecurityError.certificateValidationFailed
            }
            
            // 检查验证结果
            let isValid = result == .unspecified || result == .proceed
            
            if isValid {
                transmissionStatistics.successfulCertificateValidations += 1
                print("🔒 证书验证成功: \(host)")
            } else {
                transmissionStatistics.failedCertificateValidations += 1
                print("🔒 证书验证失败: \(host)")
            }
            
            return isValid
            
        } catch {
            lastTransmissionError = error.localizedDescription
            transmissionStatistics.failedCertificateValidations += 1
            return false
        }
    }
    
    /// 创建安全的网络连接
    func createSecureConnection(to endpoint: NWEndpoint) -> NWConnection {
        let tlsOptions = NWProtocolTLS.Options()
        
        // 配置TLS版本
        sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv13)
        
        // 配置证书验证
        if certificateValidationEnabled {
            sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { _, trust, verify_complete in
                Task {
                    let isValid = await self.validateServerCertificate(trust as! SecTrust, for: "")
                    verify_complete(isValid)
                }
            }, .main)
        }
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 30
        
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        parameters.requiredInterfaceType = .wifi // 或 .cellular，根据需要
        
        return NWConnection(to: endpoint, using: parameters)
    }
    
    /// 获取传输安全统计信息
    func getTransmissionStatistics() -> TransmissionStatistics {
        return transmissionStatistics
    }
    
    /// 重置传输统计信息
    func resetTransmissionStatistics() {
        transmissionStatistics = TransmissionStatistics()
        print("🔒 传输统计信息已重置")
    }
    
    // MARK: - Private Methods
    
    private func generateSecureNonce() throws -> Data {
        var nonce = Data(count: 12) // 96 bits for AES-GCM
        let result = nonce.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 12, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw TransmissionSecurityError.encryptionKeyExchangeFailed
        }
        
        return nonce
    }
    
    private func createDigitalSignature(for data: Data) throws -> Data {
        // 使用HMAC-SHA256创建签名
        let signingKey = SymmetricKey(size: .bits256)
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: signingKey)
        return Data(signature)
    }
    
    private func verifyDigitalSignature(signature: Data, data: Data) throws -> Bool {
        // 重建签名密钥（在实际应用中，这应该是预共享的密钥）
        let signingKey = SymmetricKey(size: .bits256)
        let expectedSignature = HMAC<SHA256>.authenticationCode(for: data, using: signingKey)
        
        return signature == Data(expectedSignature)
    }
    
    private func loadSecuritySettings() {
        isSecureTransmissionEnabled = UserDefaults.standard.bool(forKey: "SecureTransmissionEnabled")
        certificateValidationEnabled = UserDefaults.standard.bool(forKey: "CertificateValidationEnabled")
        
        // 如果是首次运行，设置默认值
        if !UserDefaults.standard.bool(forKey: "SecuritySettingsInitialized") {
            isSecureTransmissionEnabled = true
            certificateValidationEnabled = true
            saveSecuritySettings()
            UserDefaults.standard.set(true, forKey: "SecuritySettingsInitialized")
        }
    }
    
    private func saveSecuritySettings() {
        UserDefaults.standard.set(isSecureTransmissionEnabled, forKey: "SecureTransmissionEnabled")
        UserDefaults.standard.set(certificateValidationEnabled, forKey: "CertificateValidationEnabled")
    }
}

// MARK: - 传输统计信息
struct TransmissionStatistics: Codable {
    var encryptedTransmissions: Int64 = 0
    var decryptedTransmissions: Int64 = 0
    var failedTransmissions: Int64 = 0
    var totalDataEncrypted: Int64 = 0
    var totalDataDecrypted: Int64 = 0
    var successfulCertificateValidations: Int64 = 0
    var failedCertificateValidations: Int64 = 0
    var lastResetDate: Date = Date()
    
    var successRate: Double {
        let total = encryptedTransmissions + decryptedTransmissions + failedTransmissions
        guard total > 0 else { return 0.0 }
        return Double(encryptedTransmissions + decryptedTransmissions) / Double(total)
    }
    
    var certificateValidationSuccessRate: Double {
        let total = successfulCertificateValidations + failedCertificateValidations
        guard total > 0 else { return 0.0 }
        return Double(successfulCertificateValidations) / Double(total)
    }
}

// MARK: - 安全传输协议
protocol SecureTransmissionProtocol {
    func encryptForTransmission<T: Codable>(_ data: T) async throws -> SecureTransmissionData
    func decryptFromTransmission<T: Codable>(_ secureData: SecureTransmissionData, as type: T.Type) async throws -> T
    func validateTransmissionIntegrity(_ secureData: SecureTransmissionData) async -> Bool
}

// MARK: - 扩展实现安全传输协议
extension DataTransmissionSecurityManager: SecureTransmissionProtocol {
    func encryptForTransmission<T: Codable>(_ data: T) async throws -> SecureTransmissionData {
        return try await encryptTransmissionData(data)
    }
    
    func decryptFromTransmission<T: Codable>(_ secureData: SecureTransmissionData, as type: T.Type) async throws -> T {
        return try await decryptTransmissionData(secureData, as: type)
    }
    
    func validateTransmissionIntegrity(_ secureData: SecureTransmissionData) async -> Bool {
        do {
            let isSignatureValid = try verifyDigitalSignature(
                signature: secureData.signature,
                data: secureData.encryptedPayload + secureData.nonce
            )
            return isSignatureValid
        } catch {
            return false
        }
    }
}