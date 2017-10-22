//
//  Field.swift
//  Password Elephant
//
//  Created by Zach Vonler on 10/1/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation
import CryptoSwift

class PasswordSafeField: CustomDebugStringConvertible {
    
    convenience init?(engine: Blowfish, data: [UInt8], startingAt: Int) throws {
        guard (startingAt + 8 <= data.endIndex) else { return nil }
        
        // Read 8 bytes
        let cipherLength = swapEndian(ints: Array(data[startingAt..<startingAt+8]))
        
        let plainLength = try engine.decrypt(cipherLength)
        let length = swapEndian(ints: plainLength)
        
        let count = Int(length[1]) << 8 + Int(length[0])
        let type = length[4]
//        print("Got a count " + String(describing: count) + " and type " + String(describing: type))
        
        if count + startingAt + 8 > data.count {
            throw PasswordSafeDBError.FormatError(description: "Got count \(count) startingAt \(startingAt) with data count \(data.count)")
        }
        
        // Fields are padded to 8-byte boundaries
        let numBlocks = max(1, (count + 7) / 8)
        let numBytes = Int(numBlocks * 8)
        let dataStart = startingAt + 8
        let cipherContent = swapEndian(ints: Array(data[dataStart..<dataStart+numBytes]))
        let plainContent = try engine.decrypt(cipherContent)
        let content = swapEndian(ints: plainContent)
        let trimmedContent = Array(content[content.startIndex..<count])
        
        self.init(content: trimmedContent, rawType: type, cipherLength: numBytes + 8)
    }
    
    init(content: [UInt8], rawType: UInt8, cipherLength: Int) {
        self.content = content
        self.cipherLength = cipherLength
        
        func typeForRawType(rawType: UInt8) -> FieldType {
            switch rawType {
            case 0: return .Magic
            case 1: return .UUID
            case 2: return .Group
            case 3: return .Title
            case 4: return .Username
            case 5: return .Notes
            case 6: return .Password
            case 7: return .CreationTime
            case 8: return .PasswordModificationTime
            case 9: return .LastAccessTime
            case 10: return .PasswordLifetime
            case 11: return .PasswordPolicy
            case 12: return .LastModificationTime
            case 13: return .URL
            case 254: return .EndOfDatabase
            case 255: return .EndOfRecord
                
            default:
                print("Encountered unknown type " + String(describing: rawType))
                return .Unknown
            }
        }
        
        self.type = typeForRawType(rawType: rawType)
    }
    
    init() {
        content = []
        type = .Unknown
        cipherLength = 8
    }
    
    let content: [UInt8]
    let type: FieldType
    let cipherLength: Int
    
    enum FieldType: String {
        case Unknown
        case Magic
        case Version
        case UUID
        case Group
        case Title
        case Username
        case Notes
        case Password
        case CreationTime
        case PasswordModificationTime
        case LastAccessTime
        case PasswordLifetime
        case PasswordPolicy
        case LastModificationTime
        case URL
        case Autotype
        case EndOfDatabase
        case EndOfRecord
        
        var intValue: Int {
            switch self {
            case .Magic: return 0
            case .UUID: return 1
            case .Group: return 2
            case .Title: return 3
            case .EndOfDatabase: return 254
            default: return 0
            }
        }
    }
    
    var strContent: String {
        switch type {
        case .UUID: return formatUUID()
            
        case .CreationTime:             fallthrough
        case .LastAccessTime:           fallthrough
        case .LastModificationTime:     fallthrough
        case .PasswordLifetime:         fallthrough
        case .PasswordModificationTime:
            return formatTime()
            
        default: return content.map({ String(format: "%c", $0) }).joined()
        }
    }
    
    var dateContent: Date? {
        switch type {
        case .CreationTime:             fallthrough
        case .LastAccessTime:           fallthrough
        case .LastModificationTime:     fallthrough
        case .PasswordLifetime:         fallthrough
        case .PasswordModificationTime:
            return Date(timeIntervalSince1970: timeIntervalContent())
        
        default: return Date()
        }
    }
    
    var debugDescription: String {
        switch type {
        case .Password:    return "\(type.rawValue): **********************"
        case .EndOfRecord: return "-------- END OF RECORD --------"
        default:           return "\(type.rawValue): \(strContent)"
        }
    }
    
    static func formatUUID(content: Data) -> String {
        let p0 = content[0..<4].map({ String(format: "%02hhx", $0) }).joined()
        let p1 = content[4..<6].map({ String(format: "%02hhx", $0) }).joined()
        let p2 = content[6..<8].map({ String(format: "%02hhx", $0) }).joined()
        let p3 = content[8..<10].map({ String(format: "%02hhx", $0) }).joined()
        let p4 = content[10..<16].map({ String(format: "%02hhx", $0) }).joined()
        return [ p0, p1, p2, p3, p4].joined(separator: "-")
    }
    
    fileprivate func formatUUID() -> String {
        return PasswordSafeField.formatUUID(content: Data(content))
    }
    
    fileprivate func timeIntervalContent() -> TimeInterval {
        var epochSeconds = (Int(content[3]) << 24)
        epochSeconds += (Int(content[2]) << 16)
        epochSeconds += (Int(content[1]) << 8)
        epochSeconds += Int(content[0])
        
        return TimeInterval(epochSeconds)
    }
    
    fileprivate func formatTime() -> String {
        return Date(timeIntervalSince1970: timeIntervalContent()).description
    }
}

