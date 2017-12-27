//
//  PETableHeaderView.swift
//  PasswordElephant
//
//  Created by Zach Vonler on 12/27/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Cocoa

fileprivate extension NSMenu {
    func createOrReturnMenuItemAtIndex(_ index: Int) -> NSMenuItem {
        guard index >= numberOfItems else { return self.item(at: index)! }
        let item = NSMenuItem()
        addItem(item)
        return item
    }
}

class PETableHeaderView: NSTableHeaderView, NSMenuDelegate {

    override func awakeFromNib() {
        initMenu()
    }
    
    private func initMenu() {
        menu = NSMenu(title: "")
        menu?.delegate = self
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu == self.menu, let tableView = tableView else { return }
        
        var columnIndex = 0
        for column in tableView.tableColumns {
            let item = menu.createOrReturnMenuItemAtIndex(columnIndex)
            columnIndex += 1
            item.title = column.title
            item.target = self
            item.action = #selector(PETableHeaderView.toggleColumnForMenuItem(_:))
            item.keyEquivalent = ""
            item.representedObject = column
            item.state = column.isHidden ? .off : .on
        }
    }
    
    @objc private func toggleColumnForMenuItem(_ sender: NSMenuItem) {
        guard let column = sender.representedObject as? NSTableColumn else { return }
        column.isHidden = !column.isHidden
    }
}
