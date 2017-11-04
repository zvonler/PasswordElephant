//
//  SearchViewController.swift
//  Password Elephant
//
//  Created by Zachary Vonler on 10/3/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Cocoa

protocol ArchiveHandler {
    var view: NSView { get }
    
    func canSave() -> Bool
    func closeArchive()
    func importFile(filename: String)
    func openArchive(filename: String)
    func saveArchive()
    func saveArchiveAs(filename: String)
}

extension Sequence where Iterator.Element : AnyObject {
    /// Return an `Array` containing the sorted elements of `source`
    /// using criteria stored in a NSSortDescriptors array.
    public func sort(sortDescriptors theSortDescs: [NSSortDescriptor]) -> [Self.Iterator.Element] {
        return sorted {
            for sortDesc in theSortDescs {
                switch sortDesc.compare($0, to: $1) {
                case .orderedAscending: return true
                case .orderedDescending: return false
                case .orderedSame: continue
                }
            }
            return false
        }
    }
}

class SearchViewController: NSViewController, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, ArchiveHandler {

    override func viewDidLoad() {
        groupColumn.sortDescriptorPrototype = NSSortDescriptor(key: "group", ascending: true)
        titleColumn.sortDescriptorPrototype = NSSortDescriptor(key: "title", ascending: true)
        usernameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "username", ascending: true)
        createdColumn.sortDescriptorPrototype = NSSortDescriptor(key: "created", ascending: true)
        modifiedColumn.sortDescriptorPrototype = NSSortDescriptor(key: "modified", ascending: true)
        passwordChangeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "pwChanged", ascending: true)
        passwordExpirationColumn.sortDescriptorPrototype = NSSortDescriptor(key: "pwExpiration", ascending: true)
        urlColumn.sortDescriptorPrototype = NSSortDescriptor(key: "url", ascending: true)
    }
    
    override func viewWillAppear() {
        archive = Archive()
        view.window?.initialFirstResponder = searchField
        updateStatusLabel()
    }
    
    fileprivate let newEntrySegueID = NSStoryboardSegue.Identifier(rawValue: "NewEntry")
    fileprivate let showEntryDetailsSegueID = NSStoryboardSegue.Identifier(rawValue: "ShowEntryDetails")
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        guard let id = segue.identifier else { return }
        switch id {
        case showEntryDetailsSegueID:
            guard let selected = selectedEntry, let vc = segue.destinationController as? EntryDetailsViewController else { return }
            vc.database = archive?.database
            vc.entry = selected
        case newEntrySegueID:
            guard let vc = segue.destinationController as? EntryDetailsViewController else { return }
            vc.database = archive?.database
            vc.entry = nil
        default: break
        }
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - ArchiveHandler

    func canSave() -> Bool {
        return archive?.canSave() ?? false
    }
    
    func openArchive(filename: String) {
        withPassword(forFilename: filename) { (password) in
            self.tryOrShowError(prefix: "Error opening \(filename)") {
                self.archive = try Archive(filename: filename, password: password)
            }
        }
    }
    
    func closeArchive() {
        archive = Archive()
    }
    
    func importFile(filename: String) {
        withPassword(forFilename: filename) { (password) in
            self.tryOrShowError(prefix: "Error importing \(filename)") {

                // !@# Might be nice to merge the incoming entries with whatever is already stored

                self.archive = try Archive(pwsafeDB: try PasswordSafeDB(filename: filename, password: password))
            }
        }
    }
    
    func saveArchiveAs(filename: String) {
        guard let archive = archive else { return }
        withPassword(forFilename: filename) { (password) in
            self.tryOrShowError(prefix: "Error writing archive to \(filename)") {
                archive.filename = filename
                archive.password = password
                try archive.write()
                self.updateStatusLabel()
            }
        }
    }
    
    func saveArchive() {
        guard let archive = archive else { return }
        self.tryOrShowError(prefix: "Error saving \(archive.filename ?? "nil")") {
            try archive.write()
        }
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - Storyboard Hookups

    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var groupColumn: NSTableColumn!
    @IBOutlet weak var titleColumn: NSTableColumn!
    @IBOutlet weak var usernameColumn: NSTableColumn!
    @IBOutlet weak var createdColumn: NSTableColumn!
    @IBOutlet weak var modifiedColumn: NSTableColumn!
    @IBOutlet weak var passwordChangeColumn: NSTableColumn!
    @IBOutlet weak var passwordExpirationColumn: NSTableColumn!
    @IBOutlet weak var urlColumn: NSTableColumn!
    @IBOutlet var passwordLifetimePickerView: NSView!
    @IBOutlet weak var passwordLifetimeCountCombox: NSComboBox!
    @IBOutlet weak var passwordLifetimeUnitsCombox: NSComboBox!
    @IBOutlet var datePicker: NSDatePicker!
    
    @IBAction func newEntry(_ sender: Any) {
        selectedEntry = nil
        performSegue(withIdentifier: newEntrySegueID, sender: self)
    }
    
    @IBAction func userConfirmedChoice(_ sender: Any) {
        tableEntries = filteredEntries()

        if searchField.stringValue.isEmpty {
            updateStatusLabel()
        } else {
            switch tableEntries.count {
            case 0:
                statusLabel.stringValue = "No matching records"
            case 1:
                showEntryInfo(entry: tableEntries.first!)
            default:
                statusLabel.stringValue = "Non-unique input: \(tableEntries.count) matching entries"
            }
        }
        
        tableView.reloadData()
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
                for rowIndex in self.tableView.selectedRowIndexes {
                    self.tableEntries[rowIndex].setPasswordChanged(date)
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
        case 0:
            updateStatusLabel()
        case 1:
            let entry = tableEntries[rowIndexes.first!]
            showEntryInfo(entry: entry)
        default:
            statusLabel.stringValue = "\(rowIndexes.count) entries selected"
        }
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tableEntries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return tableEntries[row]
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else {
            return
        }
        tableEntries = tableEntries.sort(sortDescriptors: [sortDescriptor])
        tableView.reloadData()
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - Implementation details

    fileprivate var selectedEntry: Entry? = nil

    fileprivate var tableEntries = [Entry]()
    
    fileprivate var archive: Archive? {
        didSet {
            removeObservers()
            updateStatusLabel()
            tableEntries = filteredEntries()
            tableView.reloadData()
            createObservers()
        }
    }
    
    fileprivate var notificationObservers = [NSObjectProtocol]()
    
    fileprivate func createObservers() {
        guard let archive = archive else { return }
        if notificationObservers.isEmpty {
            let center = NotificationCenter.default
            notificationObservers = [
                center.addObserver(forName: NSNotification.Name(rawValue: Database.EntryAddedNotification), object: archive.database, queue: .main) { [weak self] (note) in
                    guard let me = self else { return }
                    me.databaseUpdated()
                },
                center.addObserver(forName: NSNotification.Name(rawValue: Database.EntryUpdatedNotification), object: archive.database, queue: .main) { [weak self] (note) in
                    guard let me = self else { return }
                    me.databaseUpdated()
                },
                center.addObserver(forName: NSNotification.Name(rawValue: Database.EntryDeletedNotification), object: archive.database, queue: .main) { [weak self] (note) in
                    guard let me = self else { return }
                    me.databaseUpdated()
                },
            ]
        }
    }
    
    fileprivate func removeObservers() {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
    }
    
    deinit {
        removeObservers()
    }
    
    fileprivate func databaseUpdated() {
        updateStatusLabel()
        tableEntries = filteredEntries()
        tableView.reloadData()
    }
    
    fileprivate func withPassword(forFilename filename: String, body: @escaping (String) -> ()) {
        withUserInput(forPrompt: "Emter password", informativeText: "\(filename)", secure: true) { (password) in
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
    
    fileprivate func updateStatusLabel() {
        guard let archive = archive else { return }
        if let filename = archive.filename {
            statusLabel.stringValue = "\(filename): \(archive.database.count) entries"
        } else {
            statusLabel.stringValue = "In-memory database: \(archive.database.count) entries"
        }
    }
    
    fileprivate func filteredEntries() -> [Entry] {
        guard let archive = archive, !archive.database.isEmpty else { return [] }
        
        let pattern = searchField.stringValue
        
        if pattern.isEmpty { return archive.database.entries }
        
        var matches = [Entry]()
        for entry in archive.database.entries {
            if let title = entry.title, title.uppercased().starts(with: pattern.uppercased()) {
                matches.append(entry)
            } else if let username = entry.username, username.uppercased().starts(with: pattern.uppercased()) {
                matches.append(entry)
            } else if let group = entry.group, group.uppercased().starts(with: pattern.uppercased()) {
                matches.append(entry)
            } else if let url = entry.url, url.uppercased().starts(with: pattern.uppercased()) {
                matches.append(entry)
            }
        }
        return matches
    }

    fileprivate var selectedEntries: [Entry] {
        return tableView.selectedRowIndexes.map({ tableEntries[$0] })
    }
    
    fileprivate func showEntryInfo(entry: Entry) {
        statusLabel.stringValue = "\(entry.title ?? "N/A") -- \(entry.username ?? "N/A") @ \(entry.url ?? "N/A")"
    }
}

