//
//  RxMutableBox.swift
//  RX
//
//  Created by Gavin on 2020/6/16.
//  Copyright © 2020 LRanger. All rights reserved.
//

import Foundation

class RxMutableBox<T>: CustomDebugStringConvertible {
    var value: T
    
    init(_ value: T) {
        self.value = value
    }
    
    var debugDescription: String {
        return "RxMutableBox(\(self.value))"
    }
    
}
