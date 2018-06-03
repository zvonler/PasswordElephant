//
//  PasswordSafeDB.swift
//  Password Elephant
//
//  Created by Zach Vonler on 10/1/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation
import CryptoSwift

enum PasswordSafeDBError: Error {
    case IncorrectPassword
    case UnsupportedVersion
    case UnsupportedPreference(prefField: String)
    case UnsupportedField(rawType: UInt8)
    case FormatError(description: String)
}

// Password Safe had issues with endianess - this code swaps the endianess of each element of a [UInt8]
func swapEndian(ints: [UInt8]) -> [UInt8] {
    guard ints.count > 3 else { return ints }
    var retval = [UInt8](repeatElement(0, count: ints.count))
    for i in stride(from: 0, to: ints.count, by: 4) {
        retval[i    ] = ints[i + 3]
        retval[i + 1] = ints[i + 2]
        retval[i + 2] = ints[i + 1]
        retval[i + 3] = ints[i    ]
    }
    return retval
}

class PasswordSafeDB {
    let filename: String
    let records: [PasswordSafeRecord]
    
    init(filename: String, password: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: filename))
        // The first 8 bytes are a random value used to verify the password
        let rnd = data[0..<8]
        // The next 20 bytes are the result of the HRND process from PasswordSafe
        let hrnd = data[8..<28]
        
        let computedHrnd = try PasswordSafeDB.computeHRND(rnd: rnd, password: password)
        if computedHrnd != hrnd {
            throw PasswordSafeDBError.IncorrectPassword
        }
        
        // The next 20 bytes are a salt
        let salt = data[28..<48]
        
        // And the last 8 bytes of the header is the IV, in the wrong endianess
        let ivRaw = data[48..<56]
        let iv = swapEndian(ints: ivRaw.bytes)
        
        // The Blowfish key is SHA1(passphrase|salt)
        let key = (Data(password.utf8) + salt).sha1()
        
        let engine = try Blowfish(key: key.bytes, blockMode: CBC(iv: iv), padding: .noPadding)
        
        self.filename = filename
        self.records = try PasswordSafeDB.readAllFields(engine: engine, data: data[56...].bytes)
    }

    fileprivate class func readAllFields(engine: Blowfish, data: [UInt8]) throws -> [PasswordSafeRecord] {
        // !@# Verification checks could be performed at first Record level? i.e. in loadRecords
        let expectedMagic = "!!!Version 2 File Format!!!"
        guard let nameField = try PasswordSafeField(engine: engine, data: data, startingAt: 0) else { throw PasswordSafeDBError.UnsupportedVersion }
        let foundMagic = nameField.strContent[1...expectedMagic.count]
        guard foundMagic == expectedMagic else { throw PasswordSafeDBError.UnsupportedVersion }
        
        var curPos = nameField.cipherLength
        guard let passField = try PasswordSafeField(engine: engine, data: data, startingAt: curPos),
            passField.strContent == "2.0" else { throw PasswordSafeDBError.UnsupportedVersion }
        
        curPos += passField.cipherLength
        guard let prefField = try PasswordSafeField(engine: engine, data: data, startingAt: curPos) else { throw PasswordSafeDBError.UnsupportedVersion }
        let prefs = try GorillaPrefs(prefField: prefField.strContent)
        
        curPos += prefField.cipherLength
        return try loadRecords(engine: engine, data: Array(data[curPos...]), isUTF8: prefs.isUTF8)
    }
    
    fileprivate class func loadRecords(engine: Blowfish, data: [UInt8], isUTF8: Bool) throws -> [PasswordSafeRecord] {
        var records = [PasswordSafeRecord]()
        var curPos = 0
        while curPos < data.count {
            guard let record = try PasswordSafeRecord(engine: engine, data: data, startingAt: curPos) else { break}
            records.append(record)
            curPos += record.cipherLength
        }
        return records
    }

    class GorillaPrefs: CustomDebugStringConvertible {
        let isUTF8: Bool
        let lockOnIdleTimeout: Bool
        let idleTimeout: TimeInterval
        
        init(isUTF8: Bool = false, lockOnIdleTimeout: Bool = true, idleTimeout: Int? = nil) {
            self.isUTF8 = isUTF8
            self.lockOnIdleTimeout = lockOnIdleTimeout
            self.idleTimeout = TimeInterval(idleTimeout ?? 0)
        }
        
        convenience init(prefField: String) throws {
            switch prefField {
            case "B 24 1":       self.init(isUTF8: true)
            case "B 22 0 I 7 0": self.init(lockOnIdleTimeout: false)
            default:             throw PasswordSafeDBError.UnsupportedPreference(prefField: prefField)
            }
        }

        var debugDescription: String {
            return "{ isUTF8: " + String(describing: isUTF8) + " }"
        }
    }
    
    
    // From the Password Gorilla documentation:
    //    # (For Password Safe 2)
    //    # H(RND) is SHA1_init_state_zero(tempSalt|Cipher(RND));
    //    #   tempSalt = SHA1(RND|{0x00,0x00}|password);
    //    #   Cipher(RND) is 1000 encryptions of RND, with tempSalt as the
    //    #   encryption key. In short, a kind of HMAC dependant on the
    //    #   password. Written before the HMAC RFC came out, no good reason
    //    #   to change. (If it ain't broke...)
    //
    // The zeroInitial parameter to the sha1 method was added to support this:
    //    #
    //    # This SHA1 implementation is taken from Don Libes' version
    //    # in tcllib. The only difference is the "isz" parameter; if
    //    # set to true, the "initial H buffer" is set to all zeroes
    //    # instead of the well-defined constants. Oh, and the result
    //    # is returned in binary format, not in hex.
    //    #
    //    # pwsafe calls this SHA1_init_state_zero, and uses it to
    //    # compute a hash to validate the password with. It is almost
    //    # certainly due to a bug in an early pwsafe implementation
    //    # that later versions still want to be compatible with.
    //    #
    class func computeHRND(rnd: Data, password: String) throws -> Data {
        let tempSalt = (rnd + [0, 0] + [UInt8](password.utf8)).sha1()
        
        var cipher = swapEndian(ints: rnd.bytes)
        
        let engine = try Blowfish(key: tempSalt.bytes, blockMode: ECB(), padding: .noPadding)
        for _ in 0 ..< 1000 {
            cipher = try engine.encrypt(cipher)
        }
        
        return (Data(swapEndian(ints: cipher)) + [0, 0]).sha1(zeroInitial: true)
    }
    
    
}
