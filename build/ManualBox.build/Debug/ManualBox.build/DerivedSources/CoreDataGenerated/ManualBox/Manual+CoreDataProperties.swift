//
//  Manual+CoreDataProperties.swift
//  
//
//  Created by Peter‘s Mac Mini on 2025/6/8.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Manual {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Manual> {
        return NSFetchRequest<Manual>(entityName: "Manual")
    }

    @NSManaged public var content: String?
    @NSManaged public var fileData: Data?
    @NSManaged public var fileName: String?
    @NSManaged public var fileType: String?
    @NSManaged public var id: UUID?
    @NSManaged public var isOCRPending: Bool
    @NSManaged public var isOCRProcessed: Bool
    @NSManaged public var product: Product?

}

extension Manual : Identifiable {

}
