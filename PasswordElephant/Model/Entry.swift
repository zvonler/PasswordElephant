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
        replaceFeature(Feature(category: .CreationTime, dateContent: Date()))
    }
    
    // Used to deserialize Entry objects from the protobuf representation.
    init(fromProtoBuf protoBuf: PasswordElephant.Entry) {
        features = [Feature]()
        super.init()
        for feature in protoBuf.features {
            features.append(Feature(fromProtoBuf: feature))
        }
        passwordLifetimeUnits = protoBuf.passwordLifetimeUnits
        passwordLifetimeCount = Int(protoBuf.passwordLifetimeCount)
    }

    convenience init(from other: Entry) {
        self.init()
        updateFromFieldsIn(other)
    }
    
    // Imports a PasswordSafeRecord into an Entry.
    convenience init(from record: PasswordSafeRecord) {
        self.init()
        for field in record.fields {
            if field.type == PasswordSafeField.FieldType.EndOfRecord {
                // Could break on this
            } else if field.type == PasswordSafeField.FieldType.LastAccessTime ||
                field.type == PasswordSafeField.FieldType.PasswordPolicy {
                // Ignore these fields as Password Elephant doesn't keep this data
            } else {
                replaceFeature(Feature(from: field))
            }
        }
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? Entry else { return false }
        return features == rhs.features
    }
    
    func toProto() throws -> PasswordElephant.Entry {
        let entryBuilder = PasswordElephant.Entry.Builder()
        entryBuilder.features = try features.map({ try $0.toProto() })
        entryBuilder.passwordLifetimeUnits = passwordLifetimeUnits
        entryBuilder.passwordLifetimeCount = Int32(passwordLifetimeCount)
        return try entryBuilder.build()
    }
    
    var features: [Feature]
    var passwordLifetimeUnits: PasswordElephant.Entry.PasswordLifetimeUnit = .days
    var passwordLifetimeCount: Int = 0
    
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
    var pwLifetimeCount: Int? { return findFirst(category: .PasswordLifetimeCount)?.intContent }
    var pwLifetimeUnits: String? { return findFirst(category: .PasswordLifetimeUnits)?.strContent }

    func setGroup   (_ newGroup   : String) { replaceFeature(Feature(category: .Group,        strContent: newGroup)) }
    func setTitle   (_ newTitle   : String) { replaceFeature(Feature(category: .Title,        strContent: newTitle)) }
    func setUsername(_ newUsername: String) { replaceFeature(Feature(category: .Username,     strContent: newUsername)) }
    func setNotes   (_ newNotes   : String) { replaceFeature(Feature(category: .Notes,        strContent: newNotes)) }
    func setURL     (_ newURL     : String) { replaceFeature(Feature(category: .URL,          strContent: newURL)) }
    func setPassword(_ newPassword: String) {
        replaceFeature(Feature(category: .Password, strContent: newPassword))
        replaceFeature(Feature(category: .PasswordChangedTime, dateContent: Date()))
    }
    func setPasswordLifetime(count: Int, units: PasswordElephant.Entry.PasswordLifetimeUnit) {
        passwordLifetimeCount = count
        passwordLifetimeUnits = units
    }
    static let FieldsUpdatedNotification = "FieldsUpdatedNotification"
    
    func updateFromFieldsIn(_ other: Entry) {
        for feature in other.features {
            replaceFeature(Feature(category: feature.category, content: feature.content))
        }
        NotificationCenter.default.post(name: Notification.Name(rawValue: Entry.FieldsUpdatedNotification), object: self)
    }
    
    fileprivate func findFirst(category: Feature.Category) -> Feature? {
        for f in features {
            if f.category == category { return f }
        }
        return nil
    }

    fileprivate func replaceFeature(_ feature: Feature) {
        let otherFeatures = features.flatMap({
            $0.category == feature.category || $0.category == .ModificationTime ? nil : $0
        })
        features = otherFeatures + [ feature, Feature(category: .ModificationTime, dateContent: Date()) ]
    }
    
}

