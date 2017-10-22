//
//  PasswordGeneratorViewController.swift
//  PasswordElephant
//
//  Created by Zachary Vonler on 10/22/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Cocoa

protocol PasswordGeneratorDelegate {
    func entryTitle() -> String
    func userChosePassword(newPassword: String)
}

class PasswordGeneratorViewController: NSViewController {

    var delegate: PasswordGeneratorDelegate?
    var entry: Entry?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        updateTitle()
    }
    
    fileprivate func updateTitle() {
        guard isViewLoaded else { return }
        titleLabel.stringValue = "Generating password for " + (delegate?.entryTitle() ?? "entry")
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - Storyboard hookups
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var passwordLengthCombox: NSComboBox!
    @IBOutlet weak var changeReminderAfterCombox: NSComboBox!
    @IBOutlet weak var changeReminderUnitsCombox: NSComboBox!
    
    @IBOutlet weak var lowercaseLettersCheckbox: NSButton!
    @IBOutlet weak var lowercaseLettersAtLeastCombox: NSComboBox!
    @IBOutlet weak var uppercaseLettersCheckbox: NSButton!
    @IBOutlet weak var uppercaseLettersAtLeastCombox: NSComboBox!
    @IBOutlet weak var numbersCheckbox: NSButton!
    @IBOutlet weak var numbersAtLeastCombox: NSComboBox!
    @IBOutlet weak var punctuationCheckbox: NSButton!
    @IBOutlet weak var punctuationAtLeastCombox: NSComboBox!
    @IBOutlet weak var specialCharactersCheckbox: NSButton!
    @IBOutlet weak var specialCharactersAtLeastCombox: NSComboBox!
    @IBOutlet weak var specialCharactersTextField: NSTextField!
    @IBOutlet weak var generatedPasswordField: NSTextField!
    
    @IBOutlet weak var generateButton: NSButton!
    @IBOutlet weak var copyToClipboardButton: NSButton!
    @IBOutlet weak var savePasswordButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    
    @IBAction func generatePassword(_ sender: Any) {
        // Use selceted rules to generate password and update generatedPasswordField
        passwordGenerator.minLowercaseLetters = Int(lowercaseLettersAtLeastCombox.stringValue) ?? 0
        passwordGenerator.minUppercaseLetters = Int(uppercaseLettersAtLeastCombox.stringValue) ?? 0
        passwordGenerator.minNumbers = Int(numbersAtLeastCombox.stringValue) ?? 0
        passwordGenerator.minPunctuaton = Int(punctuationAtLeastCombox.stringValue) ?? 0
        passwordGenerator.minSpecialCharacters = Int(specialCharactersAtLeastCombox.stringValue) ?? 0
        do {
            try generatedPasswordField.stringValue = passwordGenerator.generate()
        } catch {
            print(error)
        }
    }
    
    @IBAction func copyToClipboard(_ sender: Any) {
        guard !generatedPasswordField.stringValue.isEmpty else { return }
        clipboardClient.copyToClipboard(generatedPasswordField.stringValue)
    }
    
    @IBAction func savePassword(_ sender: Any) {
        delegate?.userChosePassword(newPassword: generatedPasswordField.stringValue)
        self.presenting?.dismissViewController(self)
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - Implementation details
    
    fileprivate let clipboardClient = ClipboardClient()
    fileprivate let passwordGenerator = PasswordGenerator()
}

extension Array {
    var shuffled: Array {
        var array = self
        indices.dropLast().forEach {
            guard case let index = Int(arc4random_uniform(UInt32(count - $0))) + $0, index != $0 else { return }
            array.swapAt($0, index)
        }
        return array
    }
    var chooseOne: Element {
        return self[Int(arc4random_uniform(UInt32(count)))]
    }
    
}

extension String {
    var jumble: String {
        return String(Array(characters).shuffled)
    }
}

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
        let allowedCharsCount = UInt32(allowedChars.characters.count)
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

