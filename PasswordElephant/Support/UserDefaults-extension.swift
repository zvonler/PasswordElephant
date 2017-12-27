//
//  UserDefaults-extension.swift
//  PasswordElephant
//
//  Created by Zachary Vonler on 10/13/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation

extension UserDefaults {
    static let clearClipboardSeconds = ObservableUserDefault<DoubleAdapter>(key: "clearClipboardSeconds")
    static let rememberRecentFiles = ObservableUserDefault<BoolAdapter>(key: "rememberRecentFiles")
    static let recentFiles = ObservableUserDefault<StringArrayAdapter>(key: "recentFiles")
    static let showInactiveEntries = ObservableUserDefault<BoolAdapter>(key: "showInactiveEntries")
}

protocol UserDefaultAdapter {
    associatedtype ValueType
    init()
    func store(_ value: ValueType, forKey key: String)
    func valueForKey(_ key: String) -> ValueType
    func value(_ lhs: ValueType, differsFrom rhs: ValueType) -> Bool
}

struct StringArrayAdapter: UserDefaultAdapter {
    typealias ValueType = [String]
    init() { }
    func store(_ value: [String], forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    func valueForKey(_ key: String) -> [String] {
        return (UserDefaults.standard.object(forKey: key) as? [String]) ?? []
    }
    func value(_ lhs: [String], differsFrom rhs: [String]) -> Bool {
        return lhs != rhs
    }
}

struct DoubleAdapter: UserDefaultAdapter {
    typealias ValueType = Double
    init() { }
    func store(_ value: ValueType, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    func valueForKey(_ key: String) -> ValueType {
        return UserDefaults.standard.double(forKey: key)
    }
    func value(_ lhs: ValueType, differsFrom rhs: ValueType) -> Bool {
        return lhs != rhs
    }
}

struct BoolAdapter: UserDefaultAdapter {
    typealias ValueType = Bool
    init() { }
    func store(_ value: ValueType, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    func valueForKey(_ key: String) -> ValueType {
        return UserDefaults.standard.bool(forKey: key)
    }
    func value(_ lhs: ValueType, differsFrom rhs: ValueType) -> Bool {
        return lhs != rhs
    }
}

class ObservableUserDefault<Adapter: UserDefaultAdapter> {
    typealias ValueType = Adapter.ValueType
    
    let key: String
    
    init(key: String) {
        self.key = key
    }
    
    var value: ValueType {
        set {
            guard adapter.value(value, differsFrom: newValue) else { return }
            adapter.store(newValue, forKey: key)
            notifyObserversOfNewValue()
        }
        get {
            return adapter.valueForKey(key)
        }
    }
    
    func addObserver<ObserverType: AnyObject>(_ observer: ObserverType, body: @escaping (ObserverType, ValueType) -> ()) {
        let wrapper = { (observer: AnyObject, newValue: ValueType) -> () in
            body(observer as! ObserverType, newValue)
        }
        records.append(ObservableUserDefaultRecord(observer: observer, body: wrapper))
    }
    
    fileprivate let adapter = Adapter()
    fileprivate var records = [ObservableUserDefaultRecord<ValueType>]()
    
    fileprivate func notifyObserversOfNewValue() {
        var foundNilObserver = false
        for record in records {
            guard let observer = record.observer else {
                foundNilObserver = true
                continue
            }
            record.body(observer, value)
        }
        
        if foundNilObserver {
            records = records.filter { $0.observer != nil }
        }
    }
}

private struct ObservableUserDefaultRecord<ValueType> {
    var observer: AnyObject?
    let body: (AnyObject, ValueType) -> ()
}
