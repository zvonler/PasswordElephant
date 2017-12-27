//
//  ObserverCollection.swift
//  PasswordElephant
//
//  Created by Zach Vonler on 12/26/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation

protocol Invalidatable {
    func invalidate()
}

class ObserverCollection<Observer> {
    func add(_ observer: Observer) -> Invalidatable {
        let registration = Registration(observer)
        registrations.append(registration)
        return registration
    }
    
    // Calls `body` on each valid Observer. Nil references are removed.
    func forEach(_ body: (Observer) -> ()) {
        var foundNil = false
        for registration in registrations {
            if let observer = registration.observer as? Observer { body(observer) }
            else { foundNil = true }
        }
        if !foundNil { return }
        registrations = registrations.filter({ $0.observer != nil })
    }
    
    private var registrations = [Registration]()
    
    private class Registration: Invalidatable {
        weak var observer: AnyObject?
        init(_ observer: Observer) { self.observer = observer as AnyObject }
        func invalidate() { observer = nil }
    }
}
