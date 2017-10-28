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
    
    @IBAction func tableWasClicked(_ sender: Any) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < tableEntries.count else {
            updateStatusLabel()
            return
        }
        let entry = tableEntries[selectedRow]
        showEntryInfo(entry: entry)
    }
    
    @IBAction func tableWasDoubleClicked(_ sender: Any) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < tableEntries.count else { return }
        selectedEntry = tableEntries[selectedRow]
        performSegue(withIdentifier: showEntryDetailsSegueID, sender: self)
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

    fileprivate let titleCellID = "TitleCellID"
    fileprivate let usernameCellID = "UsernameCellID"
    fileprivate let groupCellID = "GroupCellID"
    fileprivate let urlCellID = "URLCellID"
    fileprivate let modifiedCellID = "ModifiedCellID"
    fileprivate let passwordAgeCellID = "PasswordAgeCellID"
    fileprivate let passwordExpirationCellID = "PasswordExpirationCellID"
    fileprivate let createdCellID = "CreatedCellID"
    
    fileprivate let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let sign = interval > 0 ? "-" : ""
        let absInterval = abs(interval)
        let ti = Int(absInterval)
        
        let minutes = (ti / 60) % 60
        let hours = (ti / 3600) % 3600
        let days = (ti / 86400)

        return String(format: "%@%0.2dd %0.2dh:%0.2dm", sign, days, hours, minutes)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        
        let entry = tableEntries[row]
        
        var cellIdentifier: String = ""
        var text: String = ""
        
        switch tableColumn {
        case titleColumn:
            cellIdentifier = titleCellID
            text = entry.title ?? ""
        case usernameColumn:
            cellIdentifier = usernameCellID
            text = entry.username ?? ""
        case groupColumn:
            cellIdentifier = groupCellID
            text = entry.group ?? ""
        case createdColumn:
            cellIdentifier = createdCellID
            text = entry.created != nil ? dateFormatter.string(from: entry.created!) : ""
        case modifiedColumn:
            cellIdentifier = modifiedCellID
            text = entry.modified != nil ? dateFormatter.string(from: entry.modified!) : ""
        case passwordChangeColumn:
            cellIdentifier = passwordAgeCellID
            text = entry.pwChanged != nil ? dateFormatter.string(from: entry.pwChanged!) :
                (entry.password == nil ? "" : "Never")
        case passwordExpirationColumn:
            cellIdentifier = passwordExpirationCellID
            if let expiration = entry.pwExpiration {
                text = dateFormatter.string(from: expiration)
            } else {
                text = ""
            }
        case urlColumn:
            cellIdentifier = urlCellID
            text = entry.url ?? ""
        default: return nil
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < tableEntries.count else {
            updateStatusLabel()
            return
        }
        let entry = tableEntries[selectedRow]
        showEntryInfo(entry: entry)
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tableEntries.count
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
            removeObservers()
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
        let passwordPanel = NSAlert()
        passwordPanel.addButton(withTitle: "OK")
        passwordPanel.addButton(withTitle: "Cancel")
        passwordPanel.messageText = "Enter password"
        passwordPanel.informativeText = "\(filename)"
        let inputField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.translatesAutoresizingMaskIntoConstraints = true
        passwordPanel.accessoryView = inputField
        passwordPanel.window.initialFirstResponder = inputField
        
        passwordPanel.beginSheetModal(for: self.view.window!) { (response) in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                let password = inputField.stringValue
                body(password)
            }
        }
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
    
    fileprivate func showEntryInfo(entry: Entry) {
        statusLabel.stringValue = "\(entry.title ?? "N/A") -- \(entry.username ?? "N/A") @ \(entry.url ?? "N/A")"
    }
}

