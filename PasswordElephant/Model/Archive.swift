//
//  PasswordElephantDB.swift
//  Password Elephant
//
//  Created by Zachary Vonler on 10/7/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation
import CryptoSwift

enum PasswordElephantDBError: Error {
    case IncorrectPassword
    case UnsupportedVersion(found: Int, expected: Int)
    case FormatError(description: String)
    case SystemError(description: String)
    case HMACFailure
}

// The Archive object manages reading and writing a Database object to or from a file.
public class Archive {
    var filename: String?
    var password: String?
    var database: Database
    
    private static let FILE_MAGIC = "PEDB"
    private static let FILE_VERSION = 1

    func canSave() -> Bool {
        return filename != nil && password != nil
    }
    
    // Verify against http://www.schneier.com/paper-low-entropy.pdf
    fileprivate class func stretchPassword(salt: [UInt8], count: Int, password: String) throws -> [UInt8] {
        var sha2 = SHA2.init(variant: .sha256)
        let _ = try sha2.update(withBytes: [UInt8](password.utf8))
        var hash = try sha2.update(withBytes: salt, isLast: true)
        for _ in 0 ..< count {
            hash = try sha2.update(withBytes: hash)
        }
        return hash
    }
 
    init(database: Database? = nil) {
        self.database = database != nil ? database! : Database()
    }
    
    // Opens an archive on disk using the provided password.
    init(filename: String, password: String) throws {
        self.filename = filename
        self.password = password
        
        let data = try Data(contentsOf: URL(fileURLWithPath: filename))

        let archive = try PasswordElephant_Archive(serializedData: data)
        
        // The first 4 bytes are a magic value used to recognize the file format
        if archive.magic != Archive.FILE_MAGIC {
            throw PasswordElephantDBError.FormatError(description: "File does not start with correct magic string")
        }

        if archive.version != Archive.FILE_VERSION {
            throw PasswordElephantDBError.UnsupportedVersion(found: Int(archive.version), expected: Archive.FILE_VERSION)
        }
        
        let stretchedPass = try Archive.stretchPassword(salt: archive.salt.bytes, count: Int(archive.count), password: password)
        let computedHash = stretchedPass.sha2(.sha256)
        if computedHash != archive.passHash.bytes {
            throw PasswordElephantDBError.IncorrectPassword
        }

        let ecbEngine = try AES(key: stretchedPass, blockMode: ECB(), padding: .noPadding)
        
        var innerKey = try ecbEngine.decrypt(archive.innerKeyCipher.bytes[0..<16])
        innerKey += try ecbEngine.decrypt(archive.innerKeyCipher.bytes[16...])
        
        var outerKey = try ecbEngine.decrypt(archive.outerKeyCipher.bytes[0..<16])
        outerKey += try ecbEngine.decrypt(archive.outerKeyCipher.bytes[16...])
        
        let engine = try AES(key: innerKey, blockMode: CBC(iv: archive.iv.bytes), padding: .pkcs7)

        var hmacData = Data()
        self.database = try Archive.readDatabase(engine: engine, hmacData: &hmacData, data: archive.cipherText)
        
        let hmacEngine = HMAC(key: outerKey, variant: .sha256)
        let computedHmac = try hmacEngine.authenticate(hmacData.bytes)
        
        if computedHmac != archive.hmac.bytes {
            throw PasswordElephantDBError.HMACFailure
        }
    }
    
    // Imports the records of a Password Safe database
    convenience init(pwsafeDB: PasswordSafeDB) throws {
        self.init()
        
        for record in pwsafeDB.records {
            database.addEntry(Entry(from: record))
        }
    }
    
    fileprivate class func readDatabase(engine: AES, hmacData: inout Data, data: Data) throws -> Database {
        let plainText = Data(try engine.decrypt(data.bytes))
        let protoDB = try PasswordElephant_Database(serializedData: plainText)
        
        let database = Database()
        
        for protoEntry in protoDB.entries {
            let entry = Entry(fromProtoBuf: protoEntry)
            for feature in entry.features {
                hmacData.append(feature.content)
            }
            database.addEntry(entry)
        }
        
        return database
    }

    func write() throws {
        guard let filename = filename,
            let password = password
            else { throw PasswordElephantDBError.SystemError(description: "Filename and password must be set") }
        
        var archiveProto = PasswordElephant_Archive()
        
        archiveProto.magic = Archive.FILE_MAGIC
        archiveProto.version = Int32(Archive.FILE_VERSION)
        let count = 10000
        archiveProto.count = Int32(count)
        
        let salt = try Data.randomBytes(count: 32)
        archiveProto.salt = Data(salt)
        
        let stretchedPass = try Archive.stretchPassword(salt: salt.bytes, count: count, password: password)
        let hashedPass = stretchedPass.sha2(.sha256)
        archiveProto.passHash = Data(hashedPass)
        
        let ecbEngine = try AES(key: stretchedPass, blockMode: ECB(), padding: .noPadding)
        
        let innerKey = try Data.randomBytes(count: 32)
        
        var innerKeyCipher = try ecbEngine.encrypt(innerKey.bytes[0..<16])
        innerKeyCipher += try ecbEngine.encrypt(innerKey.bytes[16...])
        archiveProto.innerKeyCipher = Data(innerKeyCipher)
        
        let outerKey = try Data.randomBytes(count: 32)
        var outerKeyCipher = try ecbEngine.encrypt(outerKey.bytes[0..<16])
        outerKeyCipher += try ecbEngine.encrypt(outerKey.bytes[16...])
        archiveProto.outerKeyCipher = Data(outerKeyCipher)
        
        let iv = try Data.randomBytes(count: 16)
        archiveProto.iv = Data(iv)
        
        var hmacData = Data()
        let cipherText = try encryptEntries(innerKey: innerKey, iv: iv, hmacData: &hmacData)
        archiveProto.cipherText = Data(cipherText)
        
        let hmacEngine = HMAC(key: outerKey.bytes, variant: .sha256)
        let hmac = try hmacEngine.authenticate(hmacData.bytes)
        archiveProto.hmac = Data(hmac)
        
        try archiveProto.serializedData().write(to: URL(fileURLWithPath: filename))
    }
    
    fileprivate func encryptEntries(innerKey: Data, iv: Data, hmacData: inout Data) throws -> [UInt8] {
        var dbProto = PasswordElephant_Database()
        
        for entry in database.entries {
            let entryProto = try entry.toProto()

            for featureProto in entryProto.features {
                // The HMAC uses only the content of each Feature
                hmacData.append(contentsOf: featureProto.content)
            }

            dbProto.entries.append(entryProto)
        }
        
        let engine = try AES(key: innerKey.bytes, blockMode: CBC(iv: iv.bytes), padding: .pkcs7)
        return try engine.encrypt(dbProto.serializedData().bytes)
    }
    

}
