//
//  NSViewController-extension.swift
//  PasswordElephant
//
//  Created by Zach Vonler on 11/4/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Cocoa

extension NSViewController {
    func dialogOKCancel(question: String, text: String = "") -> NSAlert {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert
    }
}
