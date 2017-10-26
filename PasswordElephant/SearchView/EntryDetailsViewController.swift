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
        guard let textField = notification.object as? NSTextField else { return }
        
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
        beginPendingEdit()
        switch combox {
        case expirationCountCombox: fallthrough
        case expirationUnitsCombox:
            updatePasswordLifetime()
        default: break
        }
    }

    fileprivate func updatePasswordLifetime() {
        let count = Int(expirationCountCombox.stringValue) ?? 0
        var units = PasswordElephant_Entry.PasswordLifetimeUnit.days
        switch expirationUnitsCombox.stringValue {
        case "weeks": units = .weeks
        case "months": units = .months
        default: break
        }
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
            let newEntry = Entry()
            newEntry.updateFromFieldsIn(pending)
            database?.addEntry(newEntry)
            entry = newEntry
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
                database.deleteEntry(entry)
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
    
    fileprivate func dialogOKCancel(question: String, text: String = "") -> NSAlert {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert
    }
    
    fileprivate func updatePasswordTextField() {
        if showPassword {
            passwordTextField.stringValue = entry?.password ?? pendingEntry?.password ?? ""
            showPasswordButton.title = "Hide Password"
        } else {
            if entry == nil || pendingEntry?.password == nil {
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
        } else {
            titleTextField.isEditable = true
            urlTextField.isEditable = true
            usernameTextField.isEditable = true
            passwordTextField.isEditable = true
            notesTextView.isEditable = true
        }
    }

    fileprivate var clipboardClient = ClipboardClient()
    
    fileprivate var showPassword = false
    
    fileprivate func updateFromEntry() {
        updatePasswordTextField()
        
        if let entry = entry {
            titleTextField.stringValue = entry.title ?? ""
            urlTextField.stringValue = entry.url ?? ""
            usernameTextField.stringValue = entry.username ?? ""
            notesTextView.textStorage?.setAttributedString(NSAttributedString(string: entry.notes ?? ""))
            switch entry.passwordLifetimeUnits {
            case .days: expirationUnitsCombox.stringValue = "days"
            case .weeks: expirationUnitsCombox.stringValue = "weeks"
            case .months: expirationUnitsCombox.stringValue = "months"
            default: expirationUnitsCombox.stringValue = "days"
            }
            expirationCountCombox.stringValue = String(entry.passwordLifetimeCount)
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
