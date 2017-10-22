//
//  Entry.swift
//  PasswordElephant
//
//  Created by Zachary Vonler on 10/12/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation

// An Entry contains one or more Feature objects that represent the Entry's content.
@objcMembers
class Entry: NSObject {
    override init() {
        features = [Feature]()
        super.init()
        replaceFeature(category: .CreationTime, content: Feature.encodeDate(Date()))
    }
    
    // Used to deserialize Entry objects from the protobuf representation.
    init(fromProtoBuf protoBuf: PasswordElephant.Entry) {
        features = [Feature]()
        super.init()
        for feature in protoBuf.features {
            features.append(Feature(fromProtoBuf: feature))
        }
    }

    convenience init(from other: Entry) {
        self.init()
        updateFromFieldsIn(other)
    }
    
    // Imports a PasswordSafeRecord into an Entry.
    convenience init(from record: PasswordSafeRecord) {
        self.init()
        for field in record.fields {
            let feature = Feature(field: field)
            replaceFeature(category: feature.category, content: feature.content)
        }
    }
    
    func toProto() throws -> PasswordElephant.Entry {
        let entryBuilder = PasswordElephant.Entry.Builder()
        entryBuilder.features = try features.map({ try $0.toProto() })
        return try entryBuilder.build()
    }
    
    var features: [Feature]

    var group    : String? { return findFirst(category: .Group)?.strContent }
    var title    : String? { return findFirst(category: .Title)?.strContent }
    var username : String? { return findFirst(category: .Username)?.strContent }
    var password : String? { return findFirst(category: .Password)?.strContent }
    var notes    : String? { return findFirst(category: .Notes)?.strContent }
    var url      : String? { return findFirst(category: .URL)?.strContent }
    var created  : Date?   { return findFirst(category: .CreationTime)?.dateContent }
    var modified : Date?   { return findFirst(category: .ModificationTime)?.dateContent }
    var pwChanged: Date?   { return findFirst(category: .PasswordChangedTime)?.dateContent }
    var uuid     : String? { return findFirst(category: .UUID)?.strContent }

    func setGroup   (_ newGroup   : String) { replaceFeature(category: .Group,        content: Data(newGroup.utf8)) }
    func setTitle   (_ newTitle   : String) { replaceFeature(category: .Title,        content: Data(newTitle.utf8)) }
    func setUsername(_ newUsername: String) { replaceFeature(category: .Username,     content: Data(newUsername.utf8)) }
    func setNotes   (_ newNotes   : String) { replaceFeature(category: .Notes,        content: Data(newNotes.utf8)) }
    func setURL     (_ newURL     : String) { replaceFeature(category: .URL,          content: Data(newURL.utf8)) }
    func setPassword(_ newPassword: String) {
        replaceFeature(category: .Password, content: Data(newPassword.utf8))
        replaceFeature(category: .PasswordChangedTime, content: Feature.encodeDate(Date()))
    }

    static let FieldsUpdatedNotification = "FieldsUpdatedNotification"
    
    func updateFromFieldsIn(_ other: Entry) {
        for feature in other.features {
            replaceFeature(category: feature.category, content: feature.content)
        }
        NotificationCenter.default.post(name: Notification.Name(rawValue: Entry.FieldsUpdatedNotification), object: self)
    }
    
    fileprivate func findFirst(category: Feature.Category) -> Feature? {
        for f in features {
            if f.category == category { return f }
        }
        return nil
    }

    fileprivate func replaceFeature(category: Feature.Category, content: Data) {
        let otherFeatures = features.flatMap({ $0.category == category || $0.category == .ModificationTime ? nil : $0 })
        features = otherFeatures + [ Feature(category: category, content: content),
                                     Feature(category: .ModificationTime, content: Feature.encodeDate(Date())) ]
    }
    
}
