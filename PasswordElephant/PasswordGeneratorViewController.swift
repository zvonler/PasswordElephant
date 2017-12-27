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

class PasswordGeneratorViewController: NSViewController, NSComboBoxDelegate {

    var delegate: PasswordGeneratorDelegate?
    var entry: Entry?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        updateTitle()
        updatePasswordLength()
    }
    
    fileprivate func updateTitle() {
        guard isViewLoaded else { return }
        titleLabel.stringValue = "Generating password for " + (delegate?.entryTitle() ?? "entry")
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - Storyboard hookups
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var passwordLengthLabel: NSTextField!
    @IBOutlet weak var lowercaseLettersAtLeastCombox: NSComboBox!
    @IBOutlet weak var uppercaseLettersAtLeastCombox: NSComboBox!
    @IBOutlet weak var numbersAtLeastCombox: NSComboBox!
    @IBOutlet weak var punctuationAtLeastCombox: NSComboBox!
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
    // MARK: - NSComboBoxDelegate
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        updatePasswordLength()
        generatedPasswordField.stringValue = ""
    }

    ////////////////////////////////////////////////////////////////////////
    // MARK: - Implementation details
    
    fileprivate let passwordGenerator = PasswordGenerator()
    
    fileprivate func updatePasswordLength() {
        var length = Int(lowercaseLettersAtLeastCombox.stringValue) ?? 0
        length += Int(uppercaseLettersAtLeastCombox.stringValue) ?? 0
        length += Int(numbersAtLeastCombox.stringValue) ?? 0
        length += Int(punctuationAtLeastCombox.stringValue) ?? 0
        length += Int(specialCharactersAtLeastCombox.stringValue) ?? 0
        passwordLengthLabel.stringValue = "Password Length: \(length)"
    }
    

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
        return String(Array(self).shuffled)
    }
}
