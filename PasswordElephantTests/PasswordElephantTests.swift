//
//  PasswordElephantTests.swift
//  PasswordElephantTests
//
//  Created by Zach Vonler on 10/10/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import XCTest
@testable import PasswordElephant

class PasswordElephantTests: XCTestCase {
    
    /**
     Creates a URL for a temporary file on disk. Registers a teardown block to
     delete a file at that URL (if one exists) during test teardown.
     https://developer.apple.com/documentation/xctest/xctestcase/2887226-addteardownblock
     */
    func temporaryFileURL() -> URL {
        // Create a URL for an unique file in the system's temporary directory.
        let directory = NSTemporaryDirectory()
        let filename = UUID().uuidString
        let fileURL = URL(fileURLWithPath: directory).appendingPathComponent(filename)
        
        // Add a teardown block to delete any file at `fileURL`.
        addTeardownBlock {
            do {
                let fileManager = FileManager.default
                // Check that the file exists before trying to delete it.
                if fileManager.fileExists(atPath: fileURL.path) {
                    // Perform the deletion.
                    try fileManager.removeItem(at: fileURL)
                    // Verify that the file no longer exists after the deletion.
                    XCTAssertFalse(fileManager.fileExists(atPath: fileURL.path))
                }
            } catch {
                // Treat any errors during file deletion as a test failure.
                XCTFail("Error while deleting temporary file: \(error)")
            }
        }
        
        // Return the temporary file URL for use in a test method.
        return fileURL
        
    }

    // Writes and reads an empty PasswordElephantDB. This test verifies that the encryption/decryption and
    // authentication steps work without any errors.
    func testEmptyDatabase() {
        let tempURL = temporaryFileURL()
        let password = "testEmptyDatabase"
        do {
            let archive = Archive()
            archive.filename = tempURL.path
            archive.password = password
            try archive.write()
            let _ = try Archive(filename: tempURL.path, password: password)
            // Success
        } catch {
            XCTFail("Error writing or reading: \(error)")
        }
    }
    
    // Tries an incorrect password to confirm that an exception is thrown.
    func testIncorrectPassword() {
        let tempURL = temporaryFileURL()
        let password = "testEmptyDatabase"
        do {
            let archive = Archive()
            archive.filename = tempURL.path
            archive.password = password
            try archive.write()
            let _ = try Archive(filename: tempURL.path, password: "Not the correct password")
            XCTFail("No exception thrown when trying to open encrypted archive with wrong password")
        } catch PasswordElephantDBError.IncorrectPassword {
            // Success
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // Writes a Database containing a single Entry with a value for each available field. The test confirms
    // that the entry's field contents match after encryption/decryption.
    func testSingleEntry() throws {
        var originalFeatures = [PasswordElephant.Feature]()

        func addFeature(category: PasswordElephant.Feature.Category, content: Data) {
            let featureBuilder = PasswordElephant.Feature.Builder()
            featureBuilder.category = category
            featureBuilder.content = content
            originalFeatures.append(try! featureBuilder.build())
        }

        func addFeature(category: PasswordElephant.Feature.Category, strContent: String) {
            addFeature(category: category, content: Data(strContent.utf8))
        }
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss x"

        let emojiStr = "▶️🆗⚜️〽️📪💾🚀"

        addFeature(category: .raw, strContent: emojiStr)
        addFeature(category: .group, strContent: "Group Stuff")
        addFeature(category: .title, strContent: "Title of the single Entry")
        addFeature(category: .username, strContent: "zaphod")
        addFeature(category: .password, strContent: "beeblebrox")
        addFeature(category: .notes, strContent: "The content of a notes field is likely to be a very long string in some cases because it " +
                                             "can be used to store the answers to secret questions and other types of freeform information " +
                                             "that do not otherwise fit into the usual feature types.")
        addFeature(category: .url, strContent: "https://www.google.com/search?q=crash+override+hackers&tbm=isch")
        let modifiedDate = df.date(from: "2017-01-23 11:22:33 -0600")!
        addFeature(category: .modified, content: Feature.encodeDate(modifiedDate))
        let passwordModifiedDate = df.date(from: "2017-04-19 04:13:45 -0600")!
        addFeature(category: .passwordModified, content: Feature.encodeDate(passwordModifiedDate))
        let passwordLifetime = 86400.0 * 30 // One month
        addFeature(category: .passwordLifetime, content: Data(from:passwordLifetime))
        let passwordPolicy = Data(from: 0xdeadbeef)
        addFeature(category: .passwordPolicy, content: passwordPolicy)
        
        let entryBuilder = PasswordElephant.Entry.Builder()
        entryBuilder.features = originalFeatures

        let tempURL = temporaryFileURL()
        let password = "testSingleEntry"

        let archive = Archive()
        archive.filename = tempURL.path
        archive.password = password
        archive.database.entries = [ Entry(fromProtoBuf: try! entryBuilder.build()) ]
        try archive.write()

        let pedb = try! Archive(filename: tempURL.path, password: password)
        let returned = pedb.database.entries.first!

        let returnedFeatures = returned.features
        XCTAssertEqual(returnedFeatures.count, originalFeatures.count)
        for i in 0 ..< originalFeatures.count {
            XCTAssertEqual(returnedFeatures[i].category, Feature.categoryForProto(category: originalFeatures[i].category))
            XCTAssertEqual(returnedFeatures[i].content, originalFeatures[i].content)
        }
        
        // Make sure we can roundtrip the important stuff
        let rawFeature = returnedFeatures[0]
        let returnedStr = String(data: rawFeature.content, encoding: .utf8)!
        XCTAssertEqual(returnedStr, emojiStr)
        
        XCTAssertEqual(returned.modified!, modifiedDate)
        XCTAssertEqual(returned.pwChanged!, passwordModifiedDate)
        XCTAssertEqual(returned.pwLifetime!, passwordLifetime)
        XCTAssertEqual(returned.pwPolicy!, passwordPolicy.toHexString())
    }
    
    // Writes a Database with two distinct but overlapping entries and makes sure they stay separate.
    func testDistinctEntries() throws {
        
        func standardEntry() -> Entry {
            let entry = Entry()
            entry.setGroup("Financial")
            entry.setTitle("Bank ABC")
            entry.setUsername("bank_login")
            return entry
        }
        
        let entry_a = standardEntry()
        entry_a.setNotes("This is Entry A")
        let entry_b = standardEntry()
        entry_b.setNotes("Entry B Reporting")

        let tempURL = temporaryFileURL()
        let password = "testDistinctEntries"
        
        let archive = Archive()
        archive.filename = tempURL.path
        archive.password = password
        archive.database.addEntry(entry_a)
        archive.database.addEntry(entry_b)
        try archive.write()

        let pedb = try! Archive(filename: tempURL.path, password: password)

        let returned_a = pedb.database.entries[0]
        for i in 0 ..< returned_a.features.count {
            XCTAssertEqual(returned_a.features[i].category, entry_a.features[i].category)
            XCTAssertEqual(returned_a.features[i].content, entry_a.features[i].content)
        }
        let returned_b = pedb.database.entries[1]
        for i in 0 ..< returned_b.features.count {
            XCTAssertEqual(returned_b.features[i].category, entry_b.features[i].category)
            XCTAssertEqual(returned_b.features[i].content, entry_b.features[i].content)
        }

        // Confirm the notes feature of each entry are not the same
        XCTAssertNotEqual(returned_a.notes, returned_b.notes)
    }
}
