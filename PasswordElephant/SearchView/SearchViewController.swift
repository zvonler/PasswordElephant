//
//  SearchViewController.swift
//  Password Elephant
//
//  Created by Zachary Vonler on 10/3/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Cocoa


class SearchViewController: NSViewController, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, DatabasePresenter {

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.initialFirstResponder = searchField
        database = Database()
        showDatabaseStatus()
    }
    
    fileprivate let newEntrySegueID = NSStoryboardSegue.Identifier(rawValue: "NewEntry")
    fileprivate let showEntryDetailsSegueID = NSStoryboardSegue.Identifier(rawValue: "ShowEntryDetails")
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        guard let id = segue.identifier else { return }
        switch id {
        case showEntryDetailsSegueID:
            guard let selected = selectedEntry, let vc = segue.destinationController as? EntryDetailsViewController else { return }
            vc.database = database
            vc.entry = selected
        case newEntrySegueID:
            guard let vc = segue.destinationController as? EntryDetailsViewController else { return }
            vc.database = database
            vc.entry = nil
        default: break
        }
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - ArchiveHandler

    var filename: String? = nil
    var password: String? = nil
    
    func canSave() -> Bool {
        return filename != nil && password != nil
    }
    
    func openArchive(filename: String) {
        withPassword(forFilename: filename) { (password) in
            self.tryOrShowError(prefix: "Error opening \(filename)") {
                let archive = try Archive(filename: filename, password: password)
                self.filename = filename
                self.password = password
                self.databaseModified = false
                self.database = archive.database
            }
        }
    }
    
    func discardDatabase() {
        database = Database()
    }
    
    func importFile(filename: String) {
        withPassword(forFilename: filename) { (password) in
            self.tryOrShowError(prefix: "Error importing \(filename)") {
                let archive = try Archive(pwsafeDB: try PasswordSafeDB(filename: filename, password: password))

                // !@# Might be nice to merge the incoming entries with whatever is already stored
                self.database = archive.database
                
                self.databaseModified = false
            }
        }
    }
    
    func saveArchiveAs(filename: String) {
        withPassword(forFilename: filename) { (password) in
            self.tryOrShowError(prefix: "Error writing archive to \(filename)") {
                let archive = Archive(database: self.database)
                archive.filename = filename
                archive.password = password
                try archive.write()
                self.filename = filename
                self.password = password
                self.databaseModified = false
                self.showDatabaseStatus()
            }
        }
    }
    
    func saveArchive() {
        guard let filename = filename, let password = password else { __NSBeep(); return }
        self.tryOrShowError(prefix: "Error saving \(filename)") {
            let archive = Archive(database: database)
            archive.filename = filename
            archive.password = password
            try archive.write()
            self.databaseModified = false
            self.showDatabaseStatus()
        }
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - Storyboard Hookups

    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet var passwordLifetimePickerView: NSView!
    @IBOutlet weak var passwordLifetimeCountCombox: NSComboBox!
    @IBOutlet weak var passwordLifetimeUnitsCombox: NSComboBox!
    @IBOutlet var datePicker: NSDatePicker!
    
    @IBAction func newEntry(_ sender: Any) {
        selectedEntry = nil
        performSegue(withIdentifier: newEntrySegueID, sender: self)
    }
    
    private var filterPattern: String = ""
    
    @IBAction func userConfirmedChoice(_ sender: Any) {
        filterPattern = searchField.stringValue.localizedLowercase
        arrangeEntries()
    }

    @IBAction func tableWasDoubleClicked(_ sender: Any) {
        guard selectedEntries.count == 1 else { __NSBeep(); return }
        selectedEntry = selectedEntries.first
        performSegue(withIdentifier: showEntryDetailsSegueID, sender: self)
    }
    
    @IBAction func setPasswordLifetime(_ sender: Any) {
        let promptPanel = NSAlert()
        promptPanel.addButton(withTitle: "OK")
        promptPanel.addButton(withTitle: "Cancel")
        promptPanel.messageText = "Choose new password lifetime"
        promptPanel.accessoryView = passwordLifetimePickerView
        
        promptPanel.beginSheetModal(for: self.view.window!) { (response) in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                let (count, units) = self.getPasswordLifetime()
                for entry in self.selectedEntries {
                    entry.setPasswordLifetime(count: count, units: units)
                }
            }
        }
    }
    
    @IBAction func setGroup(_ sender: Any) {
        withUserInput(forPrompt: "Enter new group name", informativeText: nil, secure: false) { (group) in
            for entry in self.selectedEntries {
                entry.setGroup(group)
            }
        }
    }
    
    @IBAction func setPasswordChanged(_ sender: Any) {
        let promptPanel = NSAlert()
        promptPanel.addButton(withTitle: "OK")
        promptPanel.addButton(withTitle: "Cancel")
        promptPanel.messageText = "Choose password changed date"
        datePicker.dateValue = Date()
        promptPanel.accessoryView = datePicker
        promptPanel.window.initialFirstResponder = datePicker
        
        promptPanel.beginSheetModal(for: self.view.window!) { (response) in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                let date = self.datePicker.dateValue
                for entry in self.selectedEntries {
                    entry.setPasswordChanged(date)
                }
            }
        }
    }
    
    @IBAction func delete(_ sender: Any) {
        guard !selectedEntries.isEmpty else { __NSBeep(); return }
        guard let database = database, let window = view.window else { return }

        let targets = selectedEntries
        
        if let event = NSApp.currentEvent, event.modifierFlags.contains(.command) {
            database.delete(entries: targets)
        } else {
            let count = selectedEntries.count
            let prompt = dialogOKCancel(question: count > 1 ? "Delete \(count) entries?" : "Delete entry?")
            prompt.beginSheetModal(for: window) { (response) in
                if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                    database.delete(entries: targets)
                }
            }
        }
    }

    ////////////////////////////////////////////////////////////////////////
    // MARK: - NSSearchFieldDelegate

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline) {
            if tableEntries.count == 1 {
                selectedEntry = tableEntries[0]
                performSegue(withIdentifier: showEntryDetailsSegueID, sender: self)
            }
        }
        return false
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - NSTableViewDelegate
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let rowIndexes = tableView.selectedRowIndexes
        switch rowIndexes.count {
        case 0: fallthrough
        case 1:
            showDatabaseStatus()
        default:
            statusLabel.stringValue = "\(rowIndexes.count) entries selected"
        }
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return arrangedEntries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return arrangedEntries[row]
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        arrangeEntries()
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - Implementation details

    fileprivate var selectedEntry: Entry? = nil

    fileprivate var tableEntries = [Entry]()
    
    fileprivate var arrangedEntries = [Entry]()
    
    var database: Database? {
        didSet {
            guard let database = database else { return }
            removeObservers()
            createObservers()
            tableEntries = database.entries
            arrangeEntries()
            showDatabaseStatus()
        }
    }
    
    private func arrangeEntries() {
        let visibleEntries = tableEntries.flatMap({ shouldShow($0) ? $0 : nil })
        self.arrangedEntries = visibleEntries.sort(sortDescriptors: tableView.sortDescriptors)
        tableView.reloadData()
    }
    
    private func shouldShow(_ entry: Entry) -> Bool {
        return filterPattern.isEmpty || entry.matchesFilterPattern(filterPattern)
    }
    
    fileprivate var notificationObservers = [NSObjectProtocol]()
    
    fileprivate func createObservers() {
        guard notificationObservers.isEmpty else { return }
        let center = NotificationCenter.default
        notificationObservers = [
            center.addObserver(forName: NSNotification.Name(rawValue: Database.EntryAddedNotification), object: database, queue: .main) { [weak self] (note) in
                guard let me = self else { return }
                me.databaseUpdated()
            },
            center.addObserver(forName: NSNotification.Name(rawValue: Database.EntryUpdatedNotification), object: database, queue: .main) { [weak self] (note) in
                guard let me = self else { return }
                me.databaseUpdated()
            },
            center.addObserver(forName: NSNotification.Name(rawValue: Database.EntryDeletedNotification), object: database, queue: .main) { [weak self] (note) in
                guard let me = self else { return }
                me.databaseUpdated()
            },
        ]
    }
    
    fileprivate func removeObservers() {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
    }
    
    deinit {
        removeObservers()
    }
    
    fileprivate func databaseUpdated() {
        guard let database = database else { return }
        databaseModified = true
        showDatabaseStatus()
        tableEntries = database.entries
        arrangeEntries()
    }
    
    fileprivate func withPassword(forFilename filename: String, body: @escaping (String) -> ()) {
        withUserInput(forPrompt: "Enter password", informativeText: "\(filename)", secure: true) { (password) in
            body(password)
        }
    }
    
    fileprivate func withUserInput(forPrompt prompt: String, informativeText: String?, secure: Bool, body: @escaping (String) -> ()) {
        let promptPanel = NSAlert()
        promptPanel.addButton(withTitle: "OK")
        promptPanel.addButton(withTitle: "Cancel")
        promptPanel.messageText = prompt
        promptPanel.informativeText = informativeText ?? ""
        
        let inputField = secure ?
            NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24)) :
            NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.translatesAutoresizingMaskIntoConstraints = true
        promptPanel.accessoryView = inputField
        promptPanel.window.initialFirstResponder = inputField
        
        promptPanel.beginSheetModal(for: self.view.window!) { (response) in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                body(inputField.stringValue)
            }
        }
    }

    fileprivate func getPasswordLifetime() -> (Int, PasswordElephant_Entry.PasswordLifetimeUnit) {
        let count = passwordLifetimeCountCombox.indexOfSelectedItem == -1 ? Int(passwordLifetimeCountCombox.stringValue) ?? 0 : Int(passwordLifetimeCountCombox.itemObjectValue(at: passwordLifetimeCountCombox.indexOfSelectedItem) as? String ?? "0") ?? 0
        
        let units: PasswordElephant_Entry.PasswordLifetimeUnit = {
            switch passwordLifetimeUnitsCombox.stringValue {
            case "weeks": return .weeks
            case "months": return .months
            default: return .days
            }
        }()
        
        return (count, units)
    }
    
    fileprivate func tryOrShowError(prefix: String, body: () throws -> ()) {
        do {
            try body()
        } catch {
            self.statusLabel.stringValue = "\(prefix): \(error)"
        }
    }
    
    var databaseModified = false // Indicates if database has been modified since it was last saved to an archive
    
    fileprivate func showDatabaseStatus() {
        guard let database = database else { return }
        if let filename = filename {
            let indicator = databaseModified ? " *modified*" : ""
            statusLabel.stringValue = "\(filename): \(database.count) entries" + indicator
        } else {
            statusLabel.stringValue = "In-memory database: \(database.count) entries"
        }
    }
    
    fileprivate var selectedEntries: [Entry] {
        return tableView.selectedRowIndexes.map({ arrangedEntries[$0] })
    }
}

private extension Entry {
    func matchesFilterPattern(_ pattern: String) -> Bool {
        return (group ?? "").localizedLowercase.contains(pattern) ||
            (title ?? "").localizedLowercase.contains(pattern) ||
            (username ?? "").localizedLowercase.contains(pattern) ||
            (url ?? "").localizedLowercase.contains(pattern)
    }
}

