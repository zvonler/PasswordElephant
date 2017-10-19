//
//  ImportTests.swift
//  PasswordElephantTests
//
//  Created by Zachary Vonler on 10/10/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import XCTest
@testable import PasswordElephant

class ImportTests: XCTestCase {
    
    // Tests the import of a Password Safe 2.0 database with known records.
    func testPasswordSafe2_0Import() {
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "password_safe_2", ofType: "dat")!
        let db = try! PasswordSafeDB(filename: path, password: "masterpass")
        let record = db.records.first!
        
        XCTAssertEqual(record.title, "PasswordGorilla")
        XCTAssertEqual(record.url, "https://somewhere.secure/")
        XCTAssertEqual(record.username, "ImportUser")
        XCTAssertEqual(record.password, "Secret!")
        XCTAssertEqual(record.notes, "A few notes.")
    }
}
