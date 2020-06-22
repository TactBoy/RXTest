//
//  Disposables.swift
//  RX
//
//  Created by Gavin on 2020/6/16.
//  Copyright © 2020 LRanger. All rights reserved.
//

import Foundation

protocol Disposable {
    func dispose()
}

protocol Cancelable: Disposable {
    var isDisposed: Bool { get }
}

struct Disposables {
    init() {
        
    }
    
}
extension Disposables {
    
    static func create() -> Disposable {
        return NopDisposable.noOp
    }
    
    static func create(with dispose: @escaping () -> Void) -> Cancelable {
        return AnonymousDisposable(dispose)
    }
    
    static func create(_ disposable1: Disposable, _ disposable2: Disposable) -> Cancelable {
        return BinaryDisposable(disposable1, disposable2)
    }
}
    
class NopDisposable: Disposable {
    
    static let noOp = NopDisposable()
    
    deinit {
//        print("\(self) deinit")
    }
    
    init() {
        
    }
    
    func dispose() {
        
    }
}

class DisposeBase {
    init() {
        
    }
}

class SingleAssignmentDisposable: DisposeBase, Cancelable {
    
    private enum DisposeState: Int32 {
        case disposed = 1
        case disposableSet = 2
    }
    
    private let _state = AtomicInt(0)
    private var _dispoable: Disposable?
    
    var isDisposed: Bool {
        return isFlagSet(self._state, DisposeState.disposed.rawValue)
    }
    
    override init() {
        super.init()
    }
    
    func setDispoable(_ disposable: Disposable) {
        self._dispoable = disposable
        
        let previousState = fetchOr(self._state, DisposeState.disposableSet.rawValue)
        
        if previousState & DisposeState.disposableSet.rawValue != 0 {
            fatalError("oldState.disposable != nil")
        }
        
        if previousState & DisposeState.disposed.rawValue != 0 {
            disposable.dispose()
            self._dispoable = nil
        }
    }
    
    func dispose() {
        let previousState = fetchOr(_state, DisposeState.disposed.rawValue)
        
        if previousState & DisposeState.disposed.rawValue != 0 {
            return
        }
        
        if previousState & DisposeState.disposableSet.rawValue != 0 {
            guard let dispoable = _dispoable else {
                fatalError("Disposable not set")
            }
            
            dispoable.dispose()
            _dispoable = nil
        }
        
    }
    
}


class SinkDisposer: Cancelable {
    
    deinit {
//        print("\(self) deinit")
    }
    
    private enum DisposeState: Int32 {
        case disposed = 1
        case sinkAndSubscriptionSet = 2
    }
    
    private let _state = AtomicInt(0)
    private var _sinkObserver: Disposable?
    private var _subcriptionHanderDispose: Disposable?
    
    var isDisposed: Bool {
        return isFlagSet(_state, DisposeState.disposed.rawValue)
    }
    
    func setSinkAndSubcription(sinkObserver: Disposable, subcriptionHanderDispose: Disposable) {
        _sinkObserver = sinkObserver
        _subcriptionHanderDispose = subcriptionHanderDispose
        
        let previousState = fetchOr(_state, DisposeState.sinkAndSubscriptionSet.rawValue)
        
        if previousState & DisposeState.sinkAndSubscriptionSet.rawValue != 0 {
            fatalError("Sink and subscription were already set")
        }
        
        if previousState & DisposeState.disposed.rawValue != 0 {
            _sinkObserver?.dispose()
            _subcriptionHanderDispose?.dispose()
            _sinkObserver = nil
            _subcriptionHanderDispose = nil
        }
    }
    
    func dispose() {
        let previousState = fetchOr(self._state, DisposeState.disposed.rawValue)

        if (previousState & DisposeState.disposed.rawValue) != 0 {
            return
        }

        if (previousState & DisposeState.sinkAndSubscriptionSet.rawValue) != 0 {
            guard let sink = self._sinkObserver else {
                fatalError("Sink not set")
            }
            guard let subscription = self._subcriptionHanderDispose else {
                fatalError("Subscription not set")
            }

            sink.dispose()
            subscription.dispose()

            self._sinkObserver = nil
            self._subcriptionHanderDispose = nil
        }
    }
    
}

class AnonymousDisposable: DisposeBase, Cancelable {
    
    typealias DisposeAction = () -> Void
    
    private let _isDisposed = AtomicInt(0)
    private var _disposeAction: DisposeAction?
    
    var isDisposed: Bool {
        return isFlagSet(_isDisposed, 1)
    }
    
    init(_ disposeAction: @escaping DisposeAction) {
        _disposeAction = disposeAction
        super.init()
    }
    
    func dispose() {
        if fetchOr(_isDisposed, 1) == 0 {
            if let action = _disposeAction {
                self._disposeAction = nil
                action()
            }
        }
    }
    
    
    
}


class BinaryDisposable: DisposeBase, Cancelable {
    
    private let _isDisposed = AtomicInt(0)

    private var _disposable1: Disposable?
    private var _disposable2: Disposable?
    
    var isDisposed: Bool {
        return isFlagSet(self._isDisposed, 1)
    }
    
    init(_ disposable1: Disposable, _ disposable2: Disposable) {
        self._disposable1 = disposable1
        self._disposable2 = disposable2
        super.init()
    }
    
    func dispose() {
        if fetchOr(self._isDisposed, 1) == 0 {
            self._disposable1?.dispose()
            self._disposable2?.dispose()
            self._disposable1 = nil
            self._disposable2 = nil
        }
    }
    
}

