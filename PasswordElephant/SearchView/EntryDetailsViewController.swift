//
//  EntryDetailsViewController.swift
//  Password Elephant
//
//  Created by Zachary Vonler on 10/7/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Cocoa

class EntryDetailsViewController: NSViewController, NSTextViewDelegate, NSComboBoxDelegate, PasswordGeneratorDelegate {

    var database: Database?
    
    var entry: Entry?
    
    fileprivate var pendingEntry: Entry?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

        locked = entry != nil        
        updateForLockedState()
        updateFromEntry()
        updateButtons()
    }

    fileprivate let generatePasswordSegue = "GeneratePasswordSegue"
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        switch segue.identifier?.rawValue ?? "" {
        case generatePasswordSegue:
            if let vc = segue.destinationController as? PasswordGeneratorViewController {
                vc.entry = entry ?? pendingEntry
                vc.delegate = self
            }
        default: break
        }
    }
    
    override func controlTextDidChange(_ notification: Notification) {
        if let textField = notification.object as? NSTextField {
            beginPendingEdit()
            guard let pending = pendingEntry else { return }
            
            switch textField {
            case titleTextField:
                pending.setTitle(titleTextField.stringValue)
            case urlTextField:
                pending.setURL(urlTextField.stringValue)
            case usernameTextField:
                pending.setUsername(usernameTextField.stringValue)
            case passwordTextField:
                pending.setPassword(passwordTextField.stringValue)
                
            default: break
            }
        } else {
            print("whaaat")
        }
    }

    ////////////////////////////////////////////////////////////////////////
    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        beginPendingEdit()
        guard let pending = pendingEntry, let notes = notesTextView.textStorage?.string else { return }
        pending.setNotes(notes)
    }

    ////////////////////////////////////////////////////////////////////////
    // MARK: - NSComboBoxDelegate
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        guard let combox = notification.object as? NSComboBox else { return }
        switch combox {
        case expirationCountCombox: fallthrough
        case expirationUnitsCombox:
            beginPendingEdit()
            updatePasswordLifetime()
        default: break
        }
    }

    fileprivate func updatePasswordLifetime() {
        // When called because a comboBox has changed, the stringValue property at this point provides the old value - possibly an Apple bug
        // https://stackoverflow.com/questions/5265260/comboboxselectiondidchange-gives-me-previously-selected-value
        let count: Int = {
            guard expirationCountCombox.indexOfSelectedItem != -1,
                let countStr = expirationCountCombox.itemObjectValue(at: expirationCountCombox.indexOfSelectedItem) as? String,
                let count = Int(countStr)
                else { return 0 }
            return count
        }()
        
        let units: PasswordElephant_Entry.PasswordLifetimeUnit = {
            guard expirationUnitsCombox.indexOfSelectedItem != -1,
                let unitsStr = expirationUnitsCombox.itemObjectValue(at: expirationUnitsCombox.indexOfSelectedItem) as? String
                else { return .days }
            switch unitsStr {
            case "weeks": return .weeks
            case "months": return .months
            default: return .days
            }
        }()
        pendingEntry?.setPasswordLifetime(count: count, units: units)
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - PasswordGeneratorDelegate
    
    func entryTitle() -> String {
        let workingTitleEntry = pendingEntry ?? entry
        return workingTitleEntry?.title ?? workingTitleEntry?.username ?? workingTitleEntry?.url ?? "entry"
    }
    
    func userChosePassword(newPassword: String) {
        beginPendingEdit()
        pendingEntry?.setPassword(newPassword)
        updatePasswordTextField()
        updateButtons()
    }

    ////////////////////////////////////////////////////////////////////////
    // MARK: - Storyboard hookups

    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var urlTextField: NSTextField!
    @IBOutlet weak var usernameTextField: NSTextField!
    @IBOutlet weak var passwordTextField: NSTextField!
    @IBOutlet weak var showPasswordButton: NSButton!
    @IBOutlet weak var notesTextView: NSTextView!
    @IBOutlet weak var lockButton: NSButton!
    @IBOutlet weak var updateButton: NSButton!
    @IBOutlet weak var copyPasswordButton: NSButton!
    @IBOutlet weak var revertButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var expirationCountCombox: NSComboBox!
    @IBOutlet weak var expirationUnitsCombox: NSComboBox!
    @IBOutlet weak var generatePasswordButton: NSButton!
    
    @IBAction func toggleShowPassword(_ sender: Any) {
        showPassword = !showPassword
        updatePasswordTextField()
    }
    
    @IBAction func close(_ sender: Any) {
        if pendingEntry == nil { presenting?.dismissViewController(self) }

        guard let window = view.window else { return }

        let prompt = dialogOKCancel(question: "Discard changes to entry?")
        prompt.beginSheetModal(for: window) { (response) in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                self.pendingEntry = nil
                self.presenting?.dismissViewController(self)
            }
        }
    }
    
    @IBAction func toggleLock(_ sender: Any) {
        locked = !locked
        updateForLockedState()
    }
    
    @IBAction func copyPasswordToClipboard(_ sender: Any) {
        guard let entry = entry else { return }

        clipboardClient.copyToClipboard(entry.password ?? "")
        
        self.presenting?.dismissViewController(self)
    }
    
    @IBAction func updateEntry(_ sender: Any) {
        guard let pending = pendingEntry else { return }
        if let entry = entry {
            entry.updateFromFieldsIn(pending)
        } else {
            database?.addEntry(pending)
            entry = pending
        }
        finishPendingEdit()
        updateFromEntry()
        locked = true
        updateForLockedState()
    }
    
    @IBAction func revert(_ sender: Any) {
        finishPendingEdit()
        updateFromEntry()
    }
    
    @IBAction func delete(_ sender: Any) {
        guard let database = database,
            let entry = entry,
            let window = view.window
            else { return }
        
        let prompt = dialogOKCancel(question: "Delete entry?")
        prompt.beginSheetModal(for: window) { (response) in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                database.delete(entries: [entry])
                self.pendingEntry = nil
                self.entry = nil
                self.presenting?.dismissViewController(self)
            }
        }
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - Implementation details

    fileprivate func updateButtons() {
        if pendingEntry != nil {
            // User has edited one or more features
            copyPasswordButton.isEnabled = !passwordTextField.stringValue.isEmpty
            showPasswordButton.isEnabled = true
            lockButton.isEnabled = false
            updateButton.isEnabled = true
            revertButton.isEnabled = entry != nil
            deleteButton.isEnabled = entry != nil
        } else if entry != nil {
            // User is only viewing
            copyPasswordButton.isEnabled = true
            showPasswordButton.isEnabled = true
            lockButton.isEnabled = true
            updateButton.isEnabled = false
            revertButton.isEnabled = false
            deleteButton.isEnabled = true
        } else {
            // User is adding an entry and hasn't started
            copyPasswordButton.isEnabled = false
            showPasswordButton.isEnabled = false
            lockButton.isEnabled = false
            updateButton.isEnabled = false
            revertButton.isEnabled = false
            deleteButton.isEnabled = false
        }
    }
    
    fileprivate func beginPendingEdit() {
        if pendingEntry == nil {
            if let entry = entry {
                pendingEntry = Entry(from: entry)
            } else {
                pendingEntry = Entry()
            }
        }
        
        updateButtons()
    }
    
    fileprivate func finishPendingEdit() {
        pendingEntry = nil

        updateButtons()
    }
    
    fileprivate func updatePasswordTextField() {
        if showPassword {
            passwordTextField.stringValue = pendingEntry?.password ?? entry?.password ?? ""
            showPasswordButton.title = "Hide Password"
        } else {
            if entry == nil && (pendingEntry != nil && pendingEntry?.password == nil) {
                passwordTextField.stringValue = ""
            } else {
                passwordTextField.stringValue = "****************"
            }
            showPasswordButton.title = "Show Password"
        }
    }
    
    fileprivate var locked: Bool = false
        
    fileprivate func updateForLockedState() {
        lockButton.title = locked ? "Unlock" : "Lock"
        if locked {
            titleTextField.isEditable = false
            urlTextField.isEditable = false
            usernameTextField.isEditable = false
            passwordTextField.isEditable = false
            notesTextView.isEditable = false
            expirationCountCombox.isEnabled = false
            expirationUnitsCombox.isEnabled = false
            generatePasswordButton.isEnabled = false
        } else {
            titleTextField.isEditable = true
            urlTextField.isEditable = true
            usernameTextField.isEditable = true
            passwordTextField.isEditable = true
            notesTextView.isEditable = true
            expirationCountCombox.isEnabled = true
            expirationUnitsCombox.isEnabled = true
            generatePasswordButton.isEnabled = true
        }
    }
    
    fileprivate var showPassword = false
    
    fileprivate func updateFromEntry() {
        updatePasswordTextField()
        
        if let entry = entry {
            titleTextField.stringValue = entry.title ?? ""
            urlTextField.stringValue = entry.url ?? ""
            usernameTextField.stringValue = entry.username ?? ""
            notesTextView.textStorage?.setAttributedString(NSAttributedString(string: entry.notes ?? ""))
            expirationUnitsCombox.stringValue = {
                switch entry.passwordLifetimeUnits {
                case .months: return "months"
                case .weeks: return "weeks"
                default: return "days"
                }
            }()
            let count = entry.passwordLifetimeCount
            expirationCountCombox.stringValue = String(count)
        } else {
            titleTextField.stringValue = ""
            urlTextField.stringValue = ""
            usernameTextField.stringValue = ""
            notesTextView.textStorage?.setAttributedString(NSAttributedString())
            expirationUnitsCombox.stringValue = "days"
            expirationCountCombox.stringValue = "0"
        }
    }    
}
