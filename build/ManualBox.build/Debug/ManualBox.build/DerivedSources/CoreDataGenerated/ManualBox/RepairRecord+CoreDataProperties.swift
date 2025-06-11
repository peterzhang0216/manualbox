//
//  RepairRecord+CoreDataProperties.swift
//  
//
//  Created by Peter‘s Mac Mini on 2025/6/10.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension RepairRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RepairRecord> {
        return NSFetchRequest<RepairRecord>(entityName: "RepairRecord")
    }

    @NSManaged public var cost: NSDecimalNumber?
    @NSManaged public var date: Date?
    @NSManaged public var details: String?
    @NSManaged public var id: UUID?
    @NSManaged public var order: Order?

}

extension RepairRecord : Identifiable {

}
