//
//  Database.swift
//  PasswordElephant
//
//  Created by Zachary Vonler on 10/12/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation

// A Database object manages a collection of Entry objects.
class Database {
    init() {
        entries = [Entry]()
    }
    
    init(entries: [Entry]) {
        self.entries = entries
        entries.forEach({ startObserving($0) })
    }

    deinit {
        removeObservers()
    }
    
    
    fileprivate var notificationObservers = [Entry : NSObjectProtocol]()
    
    fileprivate func startObserving(_ entry: Entry) {
        guard notificationObservers.index(forKey: entry) == nil else { return }
        
        let center = NotificationCenter.default
        notificationObservers[entry] =
            center.addObserver(forName: NSNotification.Name(rawValue: Entry.FieldsUpdatedNotification), object: entry, queue: .main) { [weak self] (note) in
                guard let me = self else { return }
                me.entryUpdated()
        }
    }

    fileprivate func stopObserving(_ entry: Entry) {
        guard let index = notificationObservers.index(forKey: entry) else { return }
        
        let center = NotificationCenter.default
        center.removeObserver(self, name: NSNotification.Name(rawValue: Entry.FieldsUpdatedNotification), object: entry)
        notificationObservers.remove(at: index)
    }
    
    static let EntryUpdatedNotification = "EntryUpdatedNotification"
    static let EntryAddedNotification = "EntryAddedNotification"
    static let EntryDeletedNotification = "EntryDeletedNotification"
    
    fileprivate func entryUpdated() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: Database.EntryUpdatedNotification), object: self)
    }
    
    fileprivate func removeObservers() {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func addEntry(_ entry: Entry) {
        entries.append(entry)
        startObserving(entry)

        NotificationCenter.default.post(name: Notification.Name(rawValue: Database.EntryAddedNotification), object: self)
    }

    func deleteEntry(_ entry: Entry) {
        if let index = entries.index(of: entry) {
            entries.remove(at: index)
            stopObserving(entry)
            NotificationCenter.default.post(name: Notification.Name(rawValue: Database.EntryDeletedNotification), object: self)
        }
    }
    
    var count: Int { return entries.count }
    var isEmpty: Bool { return entries.isEmpty }
    
    var entries: [Entry]
}
