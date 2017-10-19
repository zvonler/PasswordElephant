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
    
    
    fileprivate var notificationObservers = [NSObjectProtocol]()
    
    fileprivate func startObserving(_ entry: Entry) {
        let center = NotificationCenter.default
        notificationObservers.append(
            center.addObserver(forName: NSNotification.Name(rawValue: Entry.FieldsUpdatedNotification), object: entry, queue: .main) { [weak self] (note) in
                guard let me = self else { return }
                me.entryUpdated()
            })
    }

    static let EntryUpdatedNotification = "EntryUpdatedNotification"
    static let EntryAddedNotification = "EntryAddedNotification"
    
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

    var count: Int { return entries.count }
    var isEmpty: Bool { return entries.isEmpty }
    
    var entries: [Entry]
}
