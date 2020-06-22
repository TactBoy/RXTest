//
//  Queue.swift
//  RX
//
//  Created by Gavin on 2020/6/16.
//  Copyright © 2020 LRanger. All rights reserved.
//

import Foundation

struct Queue<T>: Sequence, CustomDebugStringConvertible {
    typealias Generator = AnyIterator<T>
    
    private let _resizeFactor = 2
    private var _storage: ContiguousArray<T?>
    private var _count = 0
    private var _pushNextIndex = 0
    private let _initialCapacity: Int
    
    init(capacity: Int) {
        _initialCapacity = capacity
        _storage = ContiguousArray<T?>(repeating: nil, count: capacity)
    }
    
    private var dequeueIndex: Int {
        //_pushNextIndex 为什么会小于 _count
        let index = _pushNextIndex - _count
        return index < 0 ? index + _storage.count : index
    }
    
    var isEmpty: Bool {
        return _count == 0
    }
    
    var count: Int {
        return _count
    }
    
    func peek() -> T {
        precondition(count > 0)
        
        return _storage[dequeueIndex]!
    }
    
    mutating private func resizeTo(_ size: Int) {
        
        var newStorage = ContiguousArray<T?>(repeating: nil, count: size)
        
        let count = _count
        
        let dequeueIndex = self.dequeueIndex
        let spaceToEndOfQueue = _storage.count - dequeueIndex
        
        let countElementsInFirstBatch = Swift.min(count, spaceToEndOfQueue)
        let numberOfelementsInSecondBatch = count - countElementsInFirstBatch
        
        newStorage[0 ..< countElementsInFirstBatch] = _storage[dequeueIndex ..< (dequeueIndex + countElementsInFirstBatch)]
        newStorage[countElementsInFirstBatch ..< (countElementsInFirstBatch + numberOfelementsInSecondBatch)] = _storage[0 ..< numberOfelementsInSecondBatch]
        
        _count = count
        _pushNextIndex = count
        _storage = newStorage
        
    }
    
    mutating func enqueue(_ element: T) {
        if count == _storage.count {
            resizeTo(Swift.max(_storage.count, 1) * _resizeFactor)
        }
        
        _storage[_pushNextIndex] = element
        _pushNextIndex += 1
        _count += 1
        
        if _pushNextIndex >= _storage.count {
            _pushNextIndex -= _storage.count
        }
                
    }
    
    private mutating func dequeueElementOnly() -> T {
        precondition(count > 0)
        
        let index = dequeueIndex
        
        defer {
            _storage[index] = nil
            _count -= 1
        }
        
        return _storage[index]!
    }
    
    mutating func dequeue() -> T? {
        if count == 0 {
            return nil
        }
        
        defer {
            let downsizeLimit = _storage.count / (_resizeFactor * _resizeFactor)
            if _count < downsizeLimit && downsizeLimit >= _initialCapacity {
                resizeTo(_storage.count / _resizeFactor)
            }
        }
        
        return dequeueElementOnly()
    }
    
    func makeIterator() -> AnyIterator<T> {
        var i = dequeueIndex
        var count = _count
        
        return AnyIterator { () -> T? in
            if count == 0 {
                return nil
            }
            
            defer {
                count -= 1
                i += 1
            }
            
            if i >= self._storage.count {
                i -= self._storage.count
            }
            
            return self._storage[i]
        }
    }
    
    
    var debugDescription: String {
        return "count: \(count), dequeueIndex: \(dequeueIndex) _pushNextIndex: \(_pushNextIndex) _storage: \(_storage.count)"
    }
    
    func debugP() {
        print(debugDescription)
    }
    
}
