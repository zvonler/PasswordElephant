//
//  Data-extension.swift
//  PasswordElephant
//
//  Created by Zachary Vonler on 10/10/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation

extension Data {
    public static func randomBytes(count: Int) throws -> Data {
        var keyData = Data(count: count)
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, keyData.count, $0)
        }
        guard result == errSecSuccess else {
            throw PasswordElephantDBError.SystemError(description: "Failed generating random bytes")
        }
        return keyData
    }
}
