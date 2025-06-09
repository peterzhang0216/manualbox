//
//  ViewModelFactory.swift
//  ManualBox
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import CoreData

// MARK: - ViewModelFactory Protocol
@MainActor
protocol ViewModelFactory {
    func makeProductListViewModel(viewContext: NSManagedObjectContext) -> ProductListViewModel
    func makeAddProductViewModel() -> AddProductViewModel
    func makeProductDetailViewModel(product: Product, viewContext: NSManagedObjectContext) -> ProductDetailViewModel
    func makeCategoriesViewModel(viewContext: NSManagedObjectContext) -> CategoriesViewModel
    func makeTagsViewModel(viewContext: NSManagedObjectContext) -> TagsViewModel
    func makeSettingsViewModel(viewContext: NSManagedObjectContext) -> SettingsViewModel
}

// MARK: - Default ViewModelFactory Implementation
@MainActor
class DefaultViewModelFactory: ViewModelFactory {
    
    func makeProductListViewModel(viewContext: NSManagedObjectContext) -> ProductListViewModel {
        return ProductListViewModel(viewContext: viewContext)
    }
    
    func makeAddProductViewModel() -> AddProductViewModel {
        return AddProductViewModel()
    }
    
    func makeProductDetailViewModel(product: Product, viewContext: NSManagedObjectContext) -> ProductDetailViewModel {
        return ProductDetailViewModel(product: product, viewContext: viewContext)
    }
    
    func makeCategoriesViewModel(viewContext: NSManagedObjectContext) -> CategoriesViewModel {
        return CategoriesViewModel(viewContext: viewContext)
    }
    
    func makeTagsViewModel(viewContext: NSManagedObjectContext) -> TagsViewModel {
        return TagsViewModel(viewContext: viewContext)
    }
    
    func makeSettingsViewModel(viewContext: NSManagedObjectContext) -> SettingsViewModel {
        return SettingsViewModel(viewContext: viewContext)
    }
}

// MARK: - ViewModelFactory Extension for Dependency Injection
extension DefaultViewModelFactory {
    /// 单例实例，用于全局访问
    static let shared = DefaultViewModelFactory()
    
    /// 便利方法：创建带有默认viewContext的ViewModel
    func makeProductListViewModel() -> ProductListViewModel {
        let viewContext = PersistenceController.shared.container.viewContext
        return makeProductListViewModel(viewContext: viewContext)
    }
    
    func makeCategoriesViewModel() -> CategoriesViewModel {
        let viewContext = PersistenceController.shared.container.viewContext
        return makeCategoriesViewModel(viewContext: viewContext)
    }
    
    func makeTagsViewModel() -> TagsViewModel {
        let viewContext = PersistenceController.shared.container.viewContext
        return makeTagsViewModel(viewContext: viewContext)
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        let viewContext = PersistenceController.shared.container.viewContext
        return makeSettingsViewModel(viewContext: viewContext)
    }
    
    func makeProductDetailViewModel(product: Product) -> ProductDetailViewModel {
        let viewContext = PersistenceController.shared.container.viewContext
        return makeProductDetailViewModel(product: product, viewContext: viewContext)
    }
}