//
//  String-extension.swift
//  PasswordElephant
//
//  Created by Zachary Vonler on 10/10/17.
//  Copyright © 2017 Relnova Software. All rights reserved.
//

import Foundation

extension String {
    subscript (r: CountableClosedRange<Int>) -> String? {
        get {
            guard r.lowerBound >= 0, let startIndex = self.index(self.startIndex, offsetBy: r.lowerBound, limitedBy: self.endIndex),
                let endIndex = self.index(startIndex, offsetBy: r.upperBound - r.lowerBound, limitedBy: self.endIndex) else { return nil }
            return String(self[startIndex...endIndex])
        }
    }
}
