//
//  UbiquitousKeyValueStoring.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-17.
//

import Foundation

protocol UbiquitousKeyValueStoring: AnyObject {
    func object(forKey key: String) -> Any?

    func set(_ value: Any?, forKey key: String)

    func removeObject(forKey key: String)

    @discardableResult
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: UbiquitousKeyValueStoring {
    
}
