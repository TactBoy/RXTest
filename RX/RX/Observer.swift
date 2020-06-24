//
//  Observer.swift
//  RX
//
//  Created by Gavin on 2020/6/18.
//  Copyright © 2020 LRanger. All rights reserved.
//

import Foundation

enum Event<Element> {
    case next(Element)
    
    case error(Error)
    
    case complete
}

protocol ObserverType {
    associatedtype Element
    
    func on(_ event: Event<Element>)
}

extension ObserverType {
    
    func onNext(element: Element)  {
        self.on(.next(element))
    }
    
    func onError(error: Error) {
        self.on(.error(error))
    }
    
    func onComplete() {
        self.on(.complete)
    }
    
    func asObserver() -> AnyObserver<Element> {
        return AnyObserver.init(self)
    }
    
}

class Sink<Observer: ObserverType>: Disposable {
    
    fileprivate let _observer: Observer
    fileprivate let _cancel: Cancelable
    private let _disposed = AtomicInt(0)
    
    deinit {
//        print("\(self) deinit")
    }
    
    init(observer: Observer, cancel: Cancelable) {
        _observer = observer
        _cancel = cancel
    }
    
    public func forwardOn(_ event: Event<Observer.Element>) {
        if isFlagSet(_disposed, 1) {
            return
        }
        _observer.on(event)
    }
    
    func forwarder() -> SinkForward<Observer> {
        return SinkForward(forward: self)
    }
    
    var disposed: Bool {
        return isFlagSet(_disposed, 1)
    }
    
    func dispose() {
        fetchOr(_disposed, 1)
        _cancel.dispose()
    }
}

class MapSink<SourceType, Observer: ObserverType>: Sink<Observer>, ObserverType {
    
    typealias ResultType = Observer.Element
    
    typealias Transform = (SourceType) throws -> ResultType
    
    private let _transform: Transform
    
    init(transform: @escaping Transform, observer: Observer, cancel: Cancelable) {
        _transform = transform
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<SourceType>) {
        switch event {
        case .next(let element):
            do {
                let mappedElement = try self._transform(element)
                self.forwardOn(.next(mappedElement))
            } catch let e {
                self.forwardOn(.error(e))
                self.dispose()
            }
        case .error(let error):
            self.forwardOn(.error(error))
            self.dispose()
        case .complete:
            self.forwardOn(.complete)
            self.dispose()
        }
    }
}

class SinkForward<Observer: ObserverType>: ObserverType {
    
    typealias Element = Observer.Element
    
    private let _forward: Sink<Observer>
    
    init(forward: Sink<Observer>) {
        _forward = forward
    }
    
    func on(_ event: Event<SinkForward<Observer>.Element>) {
        switch event {
        case .next:
            _forward._observer.on(event)
        default:
            _forward._observer.on(event)
            _forward._cancel.dispose()
        }
    }
    
}

class AnonymousObservableSink<Observer: ObserverType> : Sink<Observer>, ObserverType {
    
    typealias Element = Observer.Element
    typealias Parent = AnonymousObservable<Element>
    
    private let _isStoped = AtomicInt(0)
    
    override init(observer: Observer, cancel: Cancelable) {
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<Observer.Element>) {
        switch event {
        case .next:
            if load(_isStoped) == 1 {
                return
            }
            self.forwardOn(event)
        default:
            if load(_isStoped) == 0 {
                self.forwardOn(event)
                self.dispose()
            }
        }
    }
    
    func run(_ parent: Parent) -> Disposable {
        return parent._subscribeHandler(AnyObserver(self))
    }
    
}

class ObserverBase<Element>: Disposable, ObserverType {
    private let _isStopped = AtomicInt(0)
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next:
            if load(_isStopped) == 0 {
                onCore(event)
            }
        default:
            if fetchOr(_isStopped, 1) == 0 {
                onCore(event)
            }
        }
    }
    
    func onCore(_ event: Event<Element>) {
        fatalError("abstract method")
    }
    
    func dispose() {
        fetchOr(_isStopped, 1)
    }
}

class AnonymousObserver<Element>: ObserverBase<Element> {
    
    typealias EventHandler = (Event<Element>) -> Void
    
    private let _eventhandler: EventHandler
    
    init(_ eventHandler: @escaping EventHandler) {
        _eventhandler = eventHandler
    }
    
    override func onCore(_ event: Event<Element>) {
        _eventhandler(event)
    }
    
}

class AnyObserver<Element>: ObserverType {
    
    deinit {
//        print("\(self.pointString): \(self) deinit")
    }
    
    var pointString: String {
        return "\(Unmanaged<AnyObject>.passUnretained(self as AnyObject).toOpaque())"
    }
    
    typealias EventHandler = (Event<Element>) -> Void
    
    let eventHandler: EventHandler
    
    public init(eventHandler: @escaping EventHandler) {
        self.eventHandler = eventHandler
    }
    
    public init<Observer: ObserverType>(_ observer: Observer) where Observer.Element == Element {
        self.eventHandler = observer.on
    }
    
    func on(_ event: Event<Element>) {
        self.eventHandler(event)
    }
    
    func asObserver() -> AnyObserver<Element> {
        return self
    }
}

class BufferCoreObserver<Element, Observer: ObserverType>: Sink<Observer>, ObserverType where Observer.Element == [Element] {
        
    let _source: Buffer<Element>
    var _buffer = [Element]()
    var _windowId = 0
    
    init(source: Buffer<Element>, observer: Observer, cancel: Cancelable)  {
        _source = source
        super.init(observer: observer, cancel: cancel)
    }
    
    func run() -> Disposable{
        
        self.createTime(windowId: self._windowId)
        return self._source._source.subscribe(self)
        
    }
    
    func createNextWindowAndPush() {
        self._windowId += 1
        let buf = self._buffer
        self._buffer.removeAll()
        self.createTime(windowId: self._windowId)
        self.forwardOn(.next(buf))
    }
    
    func createTime(windowId: Int) {
        
        if (windowId != self._windowId) {
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: DispatchTimeInterval.seconds(self._source._time))) {
            
            if (windowId != self._windowId) {
                return
            }
            
            self.createNextWindowAndPush()
            
        }
        
        
    }
    
    func on(_ event: Event<Element>) {
        switch event {
        case .next(let ele):
            self._buffer.append(ele)
            if (self._buffer.count == self._source._count) {
                self.createNextWindowAndPush()
            }
        default:
            break
        }
    }
    
    
}
