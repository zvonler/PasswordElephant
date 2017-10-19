//
//  Entry.swift
//  PasswordElephant
//
//  Created by Zachary Vonler on 10/12/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation

// An Entry contains one or more Feature objects that represent the Entry's content.
class Entry {
    init() {
        features = [Feature]()
    }
    
    init(features: [Feature]) {
        self.features = features
    }
    
    init(fromProtoBuf protoBuf: PasswordElephant.Entry) {
        features = [Feature]()
        for feature in protoBuf.features {
            features.append(Feature(fromProtoBuf: feature))
        }
    }
    
    convenience init(from other: Entry) {
        self.init()
        updateFromFieldsIn(other)
    }
    
    var group   : String? { return findFirst(category: .Group) }
    var title   : String? { return findFirst(category: .Title) }
    var username: String? { return findFirst(category: .Username) }
    var password: String? { return findFirst(category: .Password) }
    var notes   : String? { return findFirst(category: .Notes) }
    var url     : String? { return findFirst(category: .URL) }

    func setGroup   (_ newGroup   : String) { replaceFeature(category: .Group,    content: Data(newGroup.utf8)) }
    func setTitle   (_ newTitle   : String) { replaceFeature(category: .Title,    content: Data(newTitle.utf8)) }
    func setUsername(_ newUsername: String) { replaceFeature(category: .Username, content: Data(newUsername.utf8)) }
    func setPassword(_ newPassword: String) { replaceFeature(category: .Password, content: Data(newPassword.utf8)) }
    func setNotes   (_ newNotes   : String) { replaceFeature(category: .Notes,    content: Data(newNotes.utf8)) }
    func setURL     (_ newURL     : String) { replaceFeature(category: .URL,      content: Data(newURL.utf8)) }

    static let FieldsUpdatedNotification = "FieldsUpdatedNotification"
    
    func updateFromFieldsIn(_ other: Entry) {
        for feature in other.features {
            replaceFeature(category: feature.category, content: feature.content)
        }
        NotificationCenter.default.post(name: Notification.Name(rawValue: Entry.FieldsUpdatedNotification), object: self)
    }
    
    func addFeature(_ feature: Feature) {
        features.append(feature)
    }
    
    fileprivate func findFirst(category: Feature.Category) -> String? {
        for f in features {
            if f.category == category { return f.strContent }
        }
        return nil
    }

    fileprivate func replaceFeature(category: Feature.Category, content: Data) {
        let otherFeatures = features.flatMap({ $0.category == category ? nil : $0 })
        features = otherFeatures + [ Feature(category: category, content: content) ]
    }
    
    func toProto() throws -> PasswordElephant.Entry {
        let entryBuilder = PasswordElephant.Entry.Builder()
        entryBuilder.features = try features.map({ try $0.toProto() })
        return try entryBuilder.build()
    }
    
    var features: [Feature]
}
