//
//  PasswordGenerator.swift
//  PasswordElephant
//
//  Created by Zachary Vonler on 10/24/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation

class PasswordGenerator {
    var length: Int = 16
    var minLowercaseLetters: Int = 6
    var minUppercaseLetters: Int = 6
    var minNumbers: Int = 4
    var minPunctuaton: Int = 0
    var minSpecialCharacters: Int = 0
    
    func generate() throws -> String {
        var randomChars: String = ""
        if minLowercaseLetters > 0 {
            randomChars.append(randomAlphaNumericString(allowedChars: lowercaseLetters, length: minLowercaseLetters))
        }
        if minUppercaseLetters > 0 {
            randomChars.append(randomAlphaNumericString(allowedChars: uppercaseLetters, length: minUppercaseLetters))
        }
        if minNumbers > 0 {
            randomChars.append(randomAlphaNumericString(allowedChars: numbers, length: minNumbers))
        }
        if minPunctuaton > 0 {
            randomChars.append(randomAlphaNumericString(allowedChars: punctuation, length: minPunctuaton))
        }
        if minSpecialCharacters > 0 {
            randomChars.append(randomAlphaNumericString(allowedChars: specialCharacters, length: minSpecialCharacters))
        }
        return randomChars.jumble
    }
    
    fileprivate func randomAlphaNumericString(allowedChars: String, length: Int) -> String {
        let allowedCharsCount = UInt32(allowedChars.count)
        var randomString = ""
        
        for _ in 0..<length {
            let randomNum = Int(arc4random_uniform(allowedCharsCount))
            let randomIndex = allowedChars.index(allowedChars.startIndex, offsetBy: randomNum)
            let newCharacter = allowedChars[randomIndex]
            randomString += String(newCharacter)
        }
        
        return randomString
    }
    
    fileprivate let lowercaseLetters = "abcdefghijklmnopqrstuvwxyz"
    fileprivate let uppercaseLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    fileprivate let numbers = "0123456789"
    fileprivate let punctuation = ".,!?;:"
    fileprivate let specialCharacters = "`~@#$%^&*+=[]{}'\"/\\|<>()"
}
