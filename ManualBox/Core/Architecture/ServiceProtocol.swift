import Foundation
import CoreData
import Combine
// import ManualBox.Core.Models

// MARK: - 基础服务协议
protocol ServiceProtocol {
    func initialize() async throws
    func cleanup()
}

// MARK: - 数据服务协议
protocol DataServiceProtocol: ServiceProtocol {
    associatedtype Entity
    associatedtype CreateRequest
    associatedtype UpdateRequest
    
    func fetch() async throws -> [Entity]
    func fetchBy(id: UUID) async throws -> Entity?
    func create(_ request: CreateRequest) async throws -> Entity
    func update(_ entity: Entity, with request: UpdateRequest) async throws -> Entity
    func delete(_ entity: Entity) async throws
    func search(_ query: String) async throws -> [Entity]
}

// MARK: - 产品服务协议
protocol ProductServiceProtocol: DataServiceProtocol where Entity == Product {
    func fetchByCategory(_ category: Category) async throws -> [Product]
    func fetchByTag(_ tag: Tag) async throws -> [Product]
    func fetchExpiringSoon(within days: Int) async throws -> [Product]
    func performOCR(for product: Product) async throws -> Bool
}

// MARK: - 分类服务协议
protocol CategoryServiceProtocol: DataServiceProtocol where Entity == Category {
    func createDefaultCategories() async throws
    func fetchWithProductCounts() async throws -> [Category]
}

// MARK: - 标签服务协议
protocol TagServiceProtocol: DataServiceProtocol where Entity == Tag {
    func createDefaultTags() async throws
    func fetchWithProductCounts() async throws -> [Tag]
}

// MARK: - 文件服务协议
protocol FileServiceProtocol: ServiceProtocol {
    func selectFiles(allowedTypes: [String]) async throws -> [URL]
    func importFile(from url: URL) async throws -> Data
    func exportData(_ data: Data, to url: URL) async throws
    func saveImage(_ image: PlatformImage, to directory: URL) async throws -> URL
}

// MARK: - 导出服务协议
protocol ExportServiceProtocol: ServiceProtocol {
    func exportToJSON(_ products: [Product]) async throws -> Data
    func exportToCSV(_ products: [Product]) async throws -> Data
    func exportToPDF(_ products: [Product]) async throws -> Data
}

// MARK: - 导入服务协议
protocol ImportServiceProtocol: ServiceProtocol {
    func importFromJSON(_ data: Data) async throws -> [Product]
    func importFromCSV(_ data: Data) async throws -> [Product]
}

// MARK: - 通知服务协议
protocol NotificationServiceProtocol: ServiceProtocol {
    func scheduleWarrantyReminder(for product: Product) async throws
    func cancelWarrantyReminder(for product: Product) async throws
    func updateAllWarrantyReminders() async throws
    func requestPermission() async throws -> Bool
}

// MARK: - 同步服务协议
@MainActor
protocol SyncServiceProtocol: ServiceProtocol {
    func syncToCloud() async throws
    func syncFromCloud() async throws
    func resolveConflicts() async throws
    var syncStatus: SyncStatus { get }
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case paused
    case completed
    case failed(Error)

    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.paused, .paused), (.completed, .completed):
            return true
        case (.failed(let lhsError), (.failed(let rhsError))):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - 搜索服务协议
protocol SearchServiceProtocol: ServiceProtocol {
    func searchProducts(_ query: String, filters: SearchFilters?) async throws -> [Product]
    func searchCategories(_ query: String) async throws -> [Category]
    func searchTags(_ query: String) async throws -> [Tag]
    func getSuggestions(for query: String) async throws -> [String]
}

// MARK: - 设置服务协议
protocol SettingsServiceProtocol: ServiceProtocol {
    func getSetting<T>(_ key: String, type: T.Type) -> T?
    func setSetting<T>(_ key: String, value: T)
    func removeSetting(_ key: String)
    func exportSettings() async throws -> Data
    func importSettings(_ data: Data) async throws
}