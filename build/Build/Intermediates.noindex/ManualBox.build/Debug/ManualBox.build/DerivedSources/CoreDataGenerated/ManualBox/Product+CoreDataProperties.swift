//
//  Product+CoreDataProperties.swift
//  
//
//  Created by Peter‘s Mac Mini on 2025/6/8.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Product {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Product> {
        return NSFetchRequest<Product>(entityName: "Product")
    }

    @NSManaged public var brand: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var imageData: Data?
    @NSManaged public var model: String?
    @NSManaged public var name: String?
    @NSManaged public var notes: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var category: Category?
    @NSManaged public var manuals: NSSet?
    @NSManaged public var order: Order?
    @NSManaged public var tags: NSSet?

}

// MARK: Generated accessors for manuals
extension Product {

    @objc(addManualsObject:)
    @NSManaged public func addToManuals(_ value: Manual)

    @objc(removeManualsObject:)
    @NSManaged public func removeFromManuals(_ value: Manual)

    @objc(addManuals:)
    @NSManaged public func addToManuals(_ values: NSSet)

    @objc(removeManuals:)
    @NSManaged public func removeFromManuals(_ values: NSSet)

}

// MARK: Generated accessors for tags
extension Product {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)

}

extension Product : Identifiable {

}
