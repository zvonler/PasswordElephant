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
    init(fromProtoBuf protoBuf: PasswordElephant_Entry) {
        features = [Feature]()
        super.init()
        for feature in protoBuf.features {
            features.append(Feature(fromProtoBuf: feature))
        }
        passwordLifetimeUnits = protoBuf.passwordLifetimeUnits
        passwordLifetimeCount = Int(protoBuf.passwordLifetimeCount)
        inactive = protoBuf.inactive
    }

    convenience init(from other: Entry) {
        self.init()
        updateFromFieldsIn(other)
    }
    
    func updateFromFieldsIn(_ other: Entry) {
        passwordLifetimeUnits = other.passwordLifetimeUnits
        passwordLifetimeCount = other.passwordLifetimeCount
        for feature in other.features {
            replaceFeature(Feature(category: feature.category, content: feature.content))
        }
        inactive = other.inactive
    }
    
    // Imports a PasswordSafeRecord into an Entry.
    convenience init(from record: PasswordSafeRecord) {
        self.init()
        for field in record.fields {
            if field.type == PasswordSafeField.FieldType.EndOfRecord {
                // Could break on this
            } else if field.type == PasswordSafeField.FieldType.LastAccessTime ||
                field.type == PasswordSafeField.FieldType.PasswordLifetime ||
                field.type == PasswordSafeField.FieldType.PasswordPolicy ||
                field.type == PasswordSafeField.FieldType.UUID {
                // Ignore these fields as Password Elephant doesn't keep this data
            } else if field.type == PasswordSafeField.FieldType.CreationTime ||
                field.type == PasswordSafeField.FieldType.LastModificationTime ||
                field.type == PasswordSafeField.FieldType.PasswordModificationTime {
                // Ignore these fields because they seem to be random
            } else {
                replaceFeature(Feature(from: field))
            }
        }
    }
    
    func toProto() throws -> PasswordElephant_Entry {
        var entryProto = PasswordElephant_Entry()
        entryProto.features = try features.map({ try $0.toProto() })
        entryProto.passwordLifetimeUnits = passwordLifetimeUnits
        entryProto.passwordLifetimeCount = Int32(passwordLifetimeCount)
        entryProto.inactive = inactive
        return entryProto
    }
    
    var features: [Feature] {
        didSet { postFieldsUpdatedNotification() }
    }

    var passwordLifetimeUnits: PasswordElephant_Entry.PasswordLifetimeUnit = .days {
        didSet { postFieldsUpdatedNotification() }
    }
    
    var passwordLifetimeCount: Int = 0 {
        didSet { postFieldsUpdatedNotification() }
    }

    var inactive: Bool = false {
        didSet { postFieldsUpdatedNotification() }
    }
    
    var group    : String? { return findFirst(category: .Group)?.strContent }
    var title    : String? { return findFirst(category: .Title)?.strContent }
    var username : String? { return findFirst(category: .Username)?.strContent }
    var password : String? { return findFirst(category: .Password)?.strContent }
    var notes    : String? { return findFirst(category: .Notes)?.strContent }
    var url      : String? { return findFirst(category: .URL)?.strContent }
    var created  : Date?   { return findFirst(category: .CreationTime)?.dateContent }
    var modified : Date?   { return findFirst(category: .ModificationTime)?.dateContent }
    var pwChanged: Date?   { return findFirst(category: .PasswordChangedTime)?.dateContent }

    var pwExpiration: Date? {
        guard passwordLifetimeCount > 0 else { return nil }
        guard let changed = pwChanged else { return Date() }
        
        let calendar = Calendar.autoupdatingCurrent
        var lifetime = DateComponents()
        switch passwordLifetimeUnits {
        case .months: lifetime.month = passwordLifetimeCount
        case .weeks: lifetime.weekOfYear = passwordLifetimeCount
        default: lifetime.day = passwordLifetimeCount
        }
        return calendar.date(byAdding: lifetime, to: changed)
    }
    
    func setGroup   (_ newGroup   : String) { replaceFeature(Feature(category: .Group,        strContent: newGroup)) }
    func setTitle   (_ newTitle   : String) { replaceFeature(Feature(category: .Title,        strContent: newTitle)) }
    func setUsername(_ newUsername: String) { replaceFeature(Feature(category: .Username,     strContent: newUsername)) }
    func setNotes   (_ newNotes   : String) { replaceFeature(Feature(category: .Notes,        strContent: newNotes)) }
    func setURL     (_ newURL     : String) { replaceFeature(Feature(category: .URL,          strContent: newURL)) }
    func setPassword(_ newPassword: String) {
        replaceFeature(Feature(category: .Password, strContent: newPassword))
        replaceFeature(Feature(category: .PasswordChangedTime, dateContent: Date()))
    }
    func setPasswordChanged(_ when: Date) { replaceFeature(Feature(category: .PasswordChangedTime, dateContent: when)) }
    func setPasswordLifetime(count: Int, units: PasswordElephant_Entry.PasswordLifetimeUnit) {
        passwordLifetimeCount = count
        passwordLifetimeUnits = units
    }
    static let FieldsUpdatedNotification = "FieldsUpdatedNotification"
    
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
    
    fileprivate func postFieldsUpdatedNotification() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: Entry.FieldsUpdatedNotification), object: self)
    }
}

