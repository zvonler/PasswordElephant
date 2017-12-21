//
//  DatabasePresenter.swift
//  PasswordElephant
//
//  Created by Zachary Vonler on 11/7/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Cocoa

protocol DatabasePresenter {
    var view: NSView { get }
    
    var databaseModified: Bool { get }

    func canSave() -> Bool
    func discardDatabase(userPrompt: String, onResponse: @escaping (Bool) -> ())
    func importFile(filename: String)
    func openArchive(filename: String)
    func saveArchive()
    func saveArchiveAs(filename: String)
}
