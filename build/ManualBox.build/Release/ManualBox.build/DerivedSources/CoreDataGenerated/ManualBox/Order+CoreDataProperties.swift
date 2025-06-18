//
//  Order+CoreDataProperties.swift
//  
//
//  Created by Peter_US on 2025/6/19.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Order {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Order> {
        return NSFetchRequest<Order>(entityName: "Order")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var invoiceData: Data?
    @NSManaged public var orderDate: Date?
    @NSManaged public var orderNumber: String?
    @NSManaged public var platform: String?
    @NSManaged public var price: NSDecimalNumber?
    @NSManaged public var warrantyEndDate: Date?
    @NSManaged public var product: Product?
    @NSManaged public var repairRecords: NSSet?

}

// MARK: Generated accessors for repairRecords
extension Order {

    @objc(addRepairRecordsObject:)
    @NSManaged public func addToRepairRecords(_ value: RepairRecord)

    @objc(removeRepairRecordsObject:)
    @NSManaged public func removeFromRepairRecords(_ value: RepairRecord)

    @objc(addRepairRecords:)
    @NSManaged public func addToRepairRecords(_ values: NSSet)

    @objc(removeRepairRecords:)
    @NSManaged public func removeFromRepairRecords(_ values: NSSet)

}

extension Order : Identifiable {

}
