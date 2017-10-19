//
//  Record.swift
//  Password Elephant
//
//  Created by Zach Vonler on 10/1/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation
import CryptoSwift

class PasswordSafeRecord: CustomDebugStringConvertible {
    var fields = [PasswordSafeField]()

    var fieldByType = [PasswordSafeField.FieldType : PasswordSafeField]()
    
    init?(engine: Blowfish, data: [UInt8], startingAt: Int) throws {
        var curPos = startingAt
        while curPos < data.count {
            guard let field = try PasswordSafeField(engine: engine, data: data, startingAt: curPos) else { return }
            
            // EOF
            guard field.cipherLength > 0 else { return }
            
            curPos += field.cipherLength
            fields.append(field)
            fieldByType[field.type] = field
            
            if field.type == .EndOfRecord { return }
        }
    }
    
    var debugDescription: String {
        return fields.map({ $0.debugDescription }).joined(separator: "\n")
    }
    
    var cipherLength: Int {
        let length = fields.reduce(into: 0, { (result, field) in
            result += field.cipherLength
        })
        return length
    }
    
    var uuid: String? { return fieldByType[PasswordSafeField.FieldType.UUID]?.strContent }
    var group: String? { return fieldByType[PasswordSafeField.FieldType.Group]?.strContent }
    var title: String? { return fieldByType[PasswordSafeField.FieldType.Title]?.strContent }
    var username: String? { return fieldByType[PasswordSafeField.FieldType.Username]?.strContent }
    var notes: String? { return fieldByType[PasswordSafeField.FieldType.Notes]?.strContent }
    var password: String? { return fieldByType[PasswordSafeField.FieldType.Password]?.strContent }
    var url: String? { return fieldByType[PasswordSafeField.FieldType.URL]?.strContent }
}
