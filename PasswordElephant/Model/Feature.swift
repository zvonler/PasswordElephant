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
        case CreationTime
        case ModificationTime
        case PasswordChangedTime
        case URL
        case Unknown
    }
    
    let category: Category
    
    var content: Data
    
    var strContent: String? {
        return String(data: content, encoding: String.Encoding.utf8)
    }
    
    var dateContent: Date? {
        return Feature.decodeDate(content)
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
    
    // Imports a PasswordSafeField by copying its category and content. Date fields
    // are re-encoded into a new format, other fields are represented as their
    // original bytes.
    
    init(field: PasswordSafeField) {
        category = Feature.categoryForPasswordSafe(fieldType: field.type)
        switch field.type {
        case .CreationTime:             fallthrough
        case .LastAccessTime:           fallthrough
        case .LastModificationTime:     fallthrough
        case .PasswordLifetime:         fallthrough
        case .PasswordModificationTime:
            content = Feature.reencodeDate(field)
        default:
            content = Data(field.content)
        }
    }

    fileprivate static func reencodeDate(_ field: PasswordSafeField) -> Data {
        guard let date = field.dateContent else { return Data() }
        return encodeDate(date)
    }
    
    static func encodeDate(_ date: Date) -> Data {
        let cal = Calendar(identifier: .gregorian)
        let comp = cal.dateComponents([.day,.month,.year,.hour,.minute,.second], from: date)
        let year = comp.year!
        let yearLo = UInt8(year & 0xFF) // mask to avoid overflow error on conversion to UInt8
        let yearHi = UInt8(year >> 8)
        let settingArray = [UInt8]([
            yearLo
            , yearHi
            , UInt8(comp.month!)
            , UInt8(comp.day!)
            , UInt8(comp.hour!)
            , UInt8(comp.minute!)
            , UInt8(comp.second!)
            ])
        return Data(bytes: settingArray)
    }
    
    static func decodeDate(_ content: Data) -> Date? {
        var components = DateComponents()
        let bytes = content.bytes
        components.year = (Int)(bytes[0]) + ((Int)(bytes[1]) << 8) // reassemble 2-byte value
        components.month = (Int)(bytes[2])
        components.day = (Int)(bytes[3])
        components.hour = (Int)(bytes[4])
        components.minute = (Int)(bytes[5])
        components.second = (Int)(bytes[6])
        
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: components)
    }
    
    fileprivate class func categoryForPasswordSafe(fieldType: PasswordSafeField.FieldType) -> Category {
        switch fieldType {
        case .Group                   : return .Group
        case .Title                   : return .Title
        case .Username                : return .Username
        case .Password                : return .Password
        case .URL                     : return .URL
        case .Notes                   : return .Notes
        case .CreationTime            : return .CreationTime
        case .PasswordModificationTime: return .PasswordChangedTime
        case .LastModificationTime    : return .ModificationTime
        default                       : return .Unknown
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
        case .created : return .CreationTime
        case .passwordModified: return .PasswordChangedTime
        case .modified: return .ModificationTime
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
        case .CreationTime: return .created
        case .PasswordChangedTime: return .passwordModified
        case .ModificationTime: return .modified
        default       : return .unknown
        }
    }
}
