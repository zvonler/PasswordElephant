//
//  AppDelegate.swift
//  PasswordElephant
//
//  Created by Zach Vonler on 10/10/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserInterfaceValidations {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        installDefaultSettings()
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        guard let archiveHandler = archiveHandler else { return false }
        archiveHandler.openArchive(filename: filename)
        return true
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - NSUserInterfaceValidations

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case .some(#selector(AppDelegate.newDocument(_:))): return true
        case .some(#selector(AppDelegate.importFrom(_:))): return true
        case .some(#selector(AppDelegate.openDocument(_:))): return true
        case .some(#selector(AppDelegate.performClose(_:))): return true
        case .some(#selector(AppDelegate.saveDocumentAs(_:))): return true
            
        case .some(#selector(AppDelegate.saveDocument(_:))):
            return archiveHandler?.canSave() ?? false
            
        case .some(#selector(AppDelegate.openRecent(_:))):
            updateFromRecentFiles()
            fallthrough
        case .some(#selector(AppDelegate.clearRecentDocuments(_:))):
            return !UserDefaults.recentFiles.value.isEmpty
            
        default:
            print("Unrecognized UserInterfaceItem action: \(String(describing: item.action))")
            return false
        }
    }
    
    ////////////////////////////////////////////////////////////////////////
    // MARK: - Storyboard Hookups

    // This IBAction exists only so that the Open Recent menu item can have an action and
    // thus be identified when validating the menu.
    @IBAction func openRecent(_ sender: Any) { }
    
    @IBAction func clearRecentDocuments(_ sender: Any) {
        UserDefaults.recentFiles.value.removeAll()
    }
    
    @IBAction func newDocument(_ sender: Any) {
        archiveHandler?.closeArchive()
    }
    
    @IBAction func performClose(_ sender: Any) {
        archiveHandler?.closeArchive()
    }

    @IBAction func openDocument(_ sender: Any) {
        guard let searchVC = archiveHandler,
            let window = searchVC.view.window else { return }
        
        let dialog = NSOpenPanel()
        
        dialog.title                   = "Choose database file"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = true
        dialog.canChooseDirectories    = false
        dialog.canCreateDirectories    = false
        dialog.allowsMultipleSelection = false
        
        dialog.beginSheetModal(for: window) { (response) in
            guard response == NSApplication.ModalResponse.OK else { return }
            let path = dialog.urls.first!.path
            self.addToRecentFiles(path)
            searchVC.openArchive(filename: path)
        }
    }
    
    @IBAction func importFrom(_ sender: Any) {
        guard let archiveHandler = archiveHandler,
            let window = archiveHandler.view.window else { return }

        let dialog = NSOpenPanel()
        
        dialog.title                   = "Choose PasswordSafe 2.0 file"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = true
        dialog.canChooseDirectories    = false
        dialog.canCreateDirectories    = false
        dialog.allowsMultipleSelection = false
        
        dialog.beginSheetModal(for: window) { (response) in
            guard response == NSApplication.ModalResponse.OK else { return }
            let path = dialog.urls.first!.path
            archiveHandler.importFile(filename: path)
        }
    }

    @IBAction func saveDocumentAs(_ sender: Any) {
        guard let archiveHandler = archiveHandler,
            let window = archiveHandler.view.window else { return }

        let savePanel = NSSavePanel()
        savePanel.beginSheetModal(for: window) { (response) in
            guard response == NSApplication.ModalResponse.OK else { return }
            guard let path = savePanel.url?.path else { return }
            self.addToRecentFiles(path)
            archiveHandler.saveArchiveAs(filename: path)
        }
    }
    
    @IBAction func saveDocument(_ sender: Any) {
        archiveHandler?.saveArchive()
    }

    fileprivate func updateFromRecentFiles() {
        NSDocumentController.shared.clearRecentDocuments(self)
        let fm = FileManager.default
        for file in UserDefaults.recentFiles.value {
            if fm.fileExists(atPath: file) {
                let url = URL(fileURLWithPath: file)
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
            }
        }
    }
    
    fileprivate var archiveHandler: ArchiveHandler? {
        return NSApplication.shared.keyWindow?.contentViewController as? ArchiveHandler
    }

    fileprivate func addToRecentFiles(_ path: String) {
        guard UserDefaults.rememberRecentFiles.value else { return }
        if !UserDefaults.recentFiles.value.contains(path) {
            UserDefaults.recentFiles.value.append(path)
        }
    }
    
    fileprivate func installDefaultSettings() {
        do {
            let url = Bundle(for: AppDelegate.self).url(forResource: "DefaultSettings", withExtension: "json")!
            let data = try Data(contentsOf: url)
            let defaults = try JSONSerialization.jsonObject(with: data, options: []) as! [String : AnyObject]
            UserDefaults.standard.register(defaults: defaults)
        } catch {
            print("Failed to install default settings: \(error)")
        }
    }
}

