//
//  MediaItemEntity+CoreDataProperties.swift
//  photosTest
//
//  Created by 赵子源 on 2025/1/4.
//
//

import Foundation
import CoreData


extension MediaItemEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MediaItemEntity> {
        return NSFetchRequest<MediaItemEntity>(entityName: "MediaItemEntity")
    }

    @NSManaged public var id: String?
    @NSManaged public var isVideo: Bool
    @NSManaged public var markStatus: Int16
    @NSManaged public var creationDate: Date?
    @NSManaged public var thumbnailData: Data?

}

extension MediaItemEntity : Identifiable {

}
