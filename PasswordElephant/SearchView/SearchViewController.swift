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

class SearchViewController: NSViewController, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, ArchiveHandler {

    override func viewWillAppear() {
        archive = Archive()
        view.window?.initialFirstResponder = searchField
        updateStatusLabel()
    }
    
    var selectedEntry: Entry? = nil
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        guard let id = segue.identifier else { return }
        switch id {
        case showEntryDetailsSegueID:
            guard let selected = selectedEntry, let vc = segue.destinationController as? EntryDetailsViewController else { return }
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
    
    @IBAction func newEntry(_ sender: Any) {
        selectedEntry = nil
        performSegue(withIdentifier: newEntrySegueID, sender: self)
    }
    
    fileprivate var tableEntries = [Entry]()
    
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

    fileprivate let titleColumnTitle = "Title"
    fileprivate let usernameColumnTitle = "Username"
    fileprivate let groupColumnTitle = "Group"
    fileprivate let urlColumnTitle = "URL"
    
    fileprivate let titleCellID = "TitleCellID"
    fileprivate let usernameCellID = "UsernameCellID"
    fileprivate let groupCellID = "GroupCellID"
    fileprivate let urlCellID = "URLCellID"
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = tableEntries[row]
        
        var cellIdentifier: String = ""
        var text: String = ""
        
        switch tableColumn?.title ?? "" {
        case titleColumnTitle:
            cellIdentifier = titleCellID
            text = entry.title ?? ""
        case usernameColumnTitle:
            cellIdentifier = usernameCellID
            text = entry.username ?? ""
        case groupColumnTitle:
            cellIdentifier = groupCellID
            text = entry.group ?? ""
        case urlColumnTitle:
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

    ////////////////////////////////////////////////////////////////////////
    // MARK: - Implementation details

    fileprivate var archive: Archive? {
        didSet {
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
        tableView.reloadData()
    }
    
    fileprivate let newEntrySegueID = NSStoryboardSegue.Identifier(rawValue: "NewEntry")
    fileprivate let showEntryDetailsSegueID = NSStoryboardSegue.Identifier(rawValue: "ShowEntryDetails")
    
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

