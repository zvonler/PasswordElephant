//
//  ClipboardClient.swift
//  PasswordElephant
//
//  Created by Zachary Vonler on 10/22/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Cocoa

class ClipboardClient {
    func copyToClipboard(_ text: String) {
        scheduleClipboardClear()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        pasteboard.setString(text, forType: NSPasteboard.PasteboardType.string)
    }
    
    fileprivate var clearTimer: Timer?
    
    fileprivate func scheduleClipboardClear() {
        // In case it was already scheduled
        clearTimer?.invalidate()
        
        let period = UserDefaults.clearClipboardSeconds.value
        clearTimer = Timer.scheduledTimer(withTimeInterval: period, repeats: false) { (timer) in
            NSPasteboard.general.clearContents()
        }
    }
}
