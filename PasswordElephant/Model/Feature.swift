//
//  Feature.swift
//  PasswordElephant
//
//  Created by Zachary Vonler on 10/12/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation

// A Feature is the smallest unit of data in a Password Elephant database.
class Feature {
    
    enum Category {
        case Raw
        case Group
        case Title
        case Username
        case Password
        case Notes
        case URL
        case Unknown
    }
    
    let category: Category
    
    var content: Data
    
    var strContent: String? {
        return String(data: content, encoding: String.Encoding.utf8)
    }
    
    init(category: Category, content: Data) {
        self.category = category
        self.content = content
    }
    
    convenience init(category: Category, strContent: String) {
        self.init(category: category, content: Data(strContent.utf8))
    }
    
    init(fromProtoBuf proto: PasswordElephant.Feature) {
        category = Feature.categoryForProto(category: proto.category)
        content = proto.content
    }
    
    init(field: PasswordSafeField) {
        category = Feature.categoryForPasswordSafe(fieldType: field.type)
        content = Data(field.content)
    }

    fileprivate class func categoryForPasswordSafe(fieldType: PasswordSafeField.FieldType) -> Category {
        switch fieldType {
        case .Group   : return .Group
        case .Title   : return .Title
        case .Username: return .Username
        case .Password: return .Password
        case .URL     : return .URL
        case .Notes   : return .Notes
        default       : return .Unknown
        }
    }
    
    func toProto() throws -> PasswordElephant.Feature {
        let featureBuilder = PasswordElephant.Feature.Builder()
        featureBuilder.setCategory(Feature.protoCategoryForCategory(category))
        featureBuilder.setContent(content)
        return try featureBuilder.build()
    }
    
    class func categoryForProto(category protoCategory: PasswordElephant.Feature.Category) -> Category {
        switch protoCategory {
        case .raw     : return .Raw
        case .group   : return .Group
        case .title   : return .Title
        case .username: return .Username
        case .password: return .Password
        case .notes   : return .Notes
        case .url     : return .URL
        default       : return .Unknown
        }
    }
    
    class func protoCategoryForCategory(_ category: Category) -> PasswordElephant.Feature.Category {
        switch category {
        case .Raw     : return .raw
        case .Group   : return .group
        case .Title   : return .title
        case .Username: return .username
        case .Password: return .password
        case .Notes   : return .notes
        case .URL     : return .url
        default       : return .unknown
        }
    }
}
