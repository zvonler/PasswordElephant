//
//  ClipboardClient.swift
//  PasswordElephant
//
//  Created by Zachary Vonler on 10/22/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Cocoa

let clipboardClient = ClipboardClient()

protocol ClipboardClientObserver {
    func clipboardClientWillClearClipboardAfter(seconds: Int)
    func clipboardClientDidClearClipboard()
}

class ClipboardClient {
    
    // Interested observers should add themselves to this collection
    var observers = ObserverCollection<ClipboardClientObserver>()

    func copyToClipboard(_ text: String) {
        scheduleClipboardClear()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        pasteboard.setString(text, forType: NSPasteboard.PasteboardType.string)
    }
    
    func clearClipboard() {
        NSPasteboard.general.clearContents()
        clearTimer?.invalidate()
        observers.forEach({ $0.clipboardClientDidClearClipboard() })
    }
    
    
    private var clearTimer: Timer?
    private var clearTime: Date?
    
    private func scheduleClipboardClear() {
        // In case it was already scheduled
        clearTimer?.invalidate()
        let lifetime = UserDefaults.clearClipboardSeconds.value
        clearTime = Date() + lifetime
        clearTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { (timer) in
            self.checkClearTime()
        }
        observers.forEach({ $0.clipboardClientWillClearClipboardAfter(seconds: Int(lifetime)) })
    }
    
    private func checkClearTime() {
        guard let clearTime = clearTime else { return }
        let remaining = clearTime.timeIntervalSinceNow
        if remaining >= 1.0 {
            observers.forEach({ $0.clipboardClientWillClearClipboardAfter(seconds: Int(remaining)) })
        } else {
            clearClipboard()
            clearTimer?.invalidate()
        }
    }
    
}
