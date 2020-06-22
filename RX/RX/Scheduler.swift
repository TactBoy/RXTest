//
//  Scheduler.swift
//  RX
//
//  Created by Gavin on 2020/6/16.
//  Copyright © 2020 LRanger. All rights reserved.
//

import Foundation

protocol ImmediateSchedulerType {
    
    func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable
    
}

protocol InvocableType {
    func invoke()
}

protocol InvocableWithValueType {
    associatedtype Value
    
    func invoke(_ value: Value)
}

protocol ScheduledItemType: Cancelable, InvocableType {
    func invoke()
}

class CurrentThredSchedulerQueueKey: NSObject, NSCopying {
    
    static let instance = CurrentThredSchedulerQueueKey()
    
    override init() {
        super.init()
    }
    
    override var hash: Int {
        return 0
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
    
}

class CurrentThredScheduler: ImmediateSchedulerType {

    typealias ScheduleQueue = RxMutableBox<Queue<ScheduledItemType>>
    
    static let instance = CurrentThredScheduler()
    
    static var isScheduleRequiredKey: pthread_key_t = {
        
        let key = UnsafeMutablePointer<pthread_key_t>.allocate(capacity: 1)
        
        defer {
            key.deallocate()
        }
        
        guard pthread_key_create(key, nil) == 0 else {
            fatalError("isScheduleRequired key creation failed")
        }
        
        return key.pointee
        
    }()
    
    private static var scheduInProgressSentinel: UnsafeRawPointer = {
        
        return UnsafeRawPointer(UnsafeMutablePointer<Int>.allocate(capacity: 1))
        
    }()
    
    static var queue: ScheduleQueue? {
        get {
            return Thread.getThreadLocalStorageValueForKey(CurrentThredSchedulerQueueKey.instance)
        }
        set {
            Thread.setThredLocalStorageValue(newValue, forKey: CurrentThredSchedulerQueueKey.instance)
        }
    }
    
    static private (set) var isScheduleRequired: Bool {
        get {
            return pthread_getspecific(CurrentThredScheduler.isScheduleRequiredKey) == nil
        }
        set(isScheduleRequired) {
            if pthread_setspecific(CurrentThredScheduler.isScheduleRequiredKey, isScheduleRequired ? nil : scheduInProgressSentinel) != 0 {
                fatalError("pthread_setspecific failed")
            }
        }
    }
    
    func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
        
        if CurrentThredScheduler.isScheduleRequired {
            CurrentThredScheduler.isScheduleRequired = false
            
            let disposable = action(state)
            
            defer {
                CurrentThredScheduler.isScheduleRequired = true
                CurrentThredScheduler.queue = nil
            }
            
            guard let queue = CurrentThredScheduler.queue else {
                return disposable
            }
            
            while let latest = queue.value.dequeue() {
                if latest.isDisposed {
                    continue
                }
                latest.invoke()
            }
            
            return disposable

        }
        
        let existingQueue = CurrentThredScheduler.queue
        
        let queue: ScheduleQueue
        if let existingQueue = existingQueue {
            queue = existingQueue
        } else {
            queue = ScheduleQueue(Queue<ScheduledItemType>(capacity: 1))
            CurrentThredScheduler.queue = queue
        }
        
        let scheduleItem = Scheduledtem(action: action, state: state)
        
        queue.value.enqueue(scheduleItem)
        
        return scheduleItem
        
    }
    
}

struct Scheduledtem<T>: ScheduledItemType, InvocableType {
    
    typealias Action = (T) -> Disposable
    
    private let _action: Action
    private let _state: T
    
    private let _disposable = SingleAssignmentDisposable()
    
    var isDisposed: Bool {
        return _disposable.isDisposed
    }
    
    init(action: @escaping Action, state: T) {
        _action = action
        _state = state
    }
    
    func invoke() {
        _disposable.setDispoable(_action(_state))
    }
    
    func dispose() {
        _disposable.dispose()
    }
    
}

extension Thread {
    
    static func setThredLocalStorageValue<T: AnyObject>(_ value: T?, forKey key: NSCopying) {
        let curentThred = Thread.current
        let threadDictionary = curentThred.threadDictionary
        
        if let newValue = value {
            threadDictionary[key] = newValue
        } else {
            threadDictionary[key] = nil
        }
        
    }
    
    static func getThreadLocalStorageValueForKey<T>(_ key: NSCopying) -> T? {
        let curentThred = Thread.current
        let threadDictionary = curentThred.threadDictionary
        
        return threadDictionary[key] as? T
    }
    
    
}


class AtomicInt: NSLock {
    fileprivate var value: Int32
    init (_ value: Int32 = 0) {
        self.value = value
    }
}

@inline(__always)
func isFlagSet(_ this: AtomicInt, _ mask : Int32) -> Bool {
    return (load(this) & mask) != 0
}

@inline(__always)
func load(_ this: AtomicInt) -> Int32 {
    this.lock()
    let oldVlaue = this.value
    this.unlock()
    return oldVlaue
}

@discardableResult
@inline(__always)
func fetchOr(_ this: AtomicInt, _ mask: Int32) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.value |= mask
    this.unlock()
    return oldValue
}
