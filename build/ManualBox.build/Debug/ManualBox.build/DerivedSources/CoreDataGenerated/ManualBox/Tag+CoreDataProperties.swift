//
//  Tag+CoreDataProperties.swift
//  
//
//  Created by Peter‘s Mac Mini on 2025/6/10.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Tag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }

    @NSManaged public var color: String?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var products: NSSet?

}

// MARK: Generated accessors for products
extension Tag {

    @objc(addProductsObject:)
    @NSManaged public func addToProducts(_ value: Product)

    @objc(removeProductsObject:)
    @NSManaged public func removeFromProducts(_ value: Product)

    @objc(addProducts:)
    @NSManaged public func addToProducts(_ values: NSSet)

    @objc(removeProducts:)
    @NSManaged public func removeFromProducts(_ values: NSSet)

}

extension Tag : Identifiable {

}
