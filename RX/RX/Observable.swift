//
//  Observable.swift
//  RX
//
//  Created by Gavin on 2020/6/15.
//  Copyright © 2020 LRanger. All rights reserved.
//

import UIKit

/// Observable协议
protocol ObservableConvertibleType {
    
    associatedtype Element
    
    func asObservable() -> Observable<Element>
    
}

protocol ObservableType: ObservableConvertibleType {
    
    func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element
    
}

extension ObservableType {
    
    static func create(subscribe: @escaping (AnyObserver<Element>) -> Disposable) -> Observable<Element> {
        return AnonymousObservable.init(subscribe)
    }
    
    func asObservable() -> Observable<Element> {
        
        return Observable.create { (o) -> Disposable in
            return self.subscribe(o)
        }
        
    }
    
    func subscribe(_ on: @escaping (Event<Element>) -> Void) -> Disposable {
        let observer = AnonymousObserver { (event) in
            on(event)
        }
        return self.asObservable().subscribe(observer)
    }
    
    func subscribe(onNext: ((Element) -> Void)? = nil, onError: ((Swift.Error) -> Void)? = nil, onComplete: (() -> Void)? = nil, onDisposed: (() -> Void)? = nil) -> Disposable {
        
        let disposable: Disposable
        
        if let action = onDisposed {
            disposable = Disposables.create(with: action)
        } else {
            disposable = Disposables.create()
        }
        
        let observer = AnonymousObserver<Element> { (event) in
            
            switch event {
            case .next(let value):
                onNext?(value)
            case .error(let error):
                onError?(error)
                disposable.dispose()
            case .complete:
                onComplete?()
                disposable.dispose()
            }
            
        }
        
        return Disposables.create(self.asObservable().subscribe(observer), disposable)
        
    }
    
    func bind<Observer: ObserverType>(to observers: Observer...) -> Disposable where Observer.Element == Element {
        return self.bind(to: observers)
    }
    
    private func bind<Observer: ObserverType>(to observers: [Observer]) -> Disposable where Observer.Element == Element {
        return self.subscribe { (event) in
            observers.forEach{ $0.on(event)}
        }
    }

    func map<Result>(_ transform: @escaping (Element) throws -> Result) -> Observable<Result> {
        return Map(source: self.asObservable(), transform: transform)
    }
    
    static func just(_ element: Element) -> Observable<Element> {
        return Just(element: element)
    }
    
    func buffer(time: Int, count: Int) -> Observable<[Element]> {
        return Buffer.init(source: self.asObservable(), seconds: time, count: count)
    }
    
    
    
}


/// Observable类及子类
class Observable<Element>: ObservableType {
    
    deinit {
//        print("\(self) deinit")
    }
    
    func subscribe<Observer>(_ observer: Observer) -> Disposable where Observer : ObserverType, Element == Observer.Element {
        fatalError("Abstract method")
    }

    func asObservable() -> Observable<Element> {
        return self
    }
    
}

class Producer<Element>: Observable<Element> {
    
    override init() {
        super.init()
    }
    
    override func subscribe<Observer>(_ observer: Observer) -> Disposable where Element == Observer.Element, Observer : ObserverType {
        if !CurrentThredScheduler.isScheduleRequired {

            let disposer = SinkDisposer()
            
            let sinkAndSubscription = self.run(observer, cancel: disposer)
            
            disposer.setSinkAndSubcription(sinkObserver: sinkAndSubscription.sinkObserver, subcriptionHanderDispose: sinkAndSubscription.subscriptionHandlerDispose)

            return disposer
            
        } else {
                
            return CurrentThredScheduler.instance.schedule(()) {
                
                let disposer = SinkDisposer()
                
                let sinkAndSubscription = self.run(observer, cancel: disposer)
                
                disposer.setSinkAndSubcription(sinkObserver: sinkAndSubscription.sinkObserver, subcriptionHanderDispose: sinkAndSubscription.subscriptionHandlerDispose)
                
                return disposer
                
            }
            
        }
    }
    
    func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sinkObserver: Disposable, subscriptionHandlerDispose: Disposable) where Observer.Element == Element {
        fatalError("abstract mehod")
    }
    
}

// 普通序列
class AnonymousObservable<Element>: Producer<Element> {
    
    typealias SubscribeHandler = (AnyObserver<Element>) -> Disposable
    
    let _subscribeHandler: SubscribeHandler
    
    init(_ subscribeHandler: @escaping SubscribeHandler) {
        self._subscribeHandler = subscribeHandler
    }
    
    override func run<Observer>(_ observer: Observer, cancel: Cancelable) -> (sinkObserver: Disposable, subscriptionHandlerDispose: Disposable) where Element == Observer.Element, Observer : ObserverType {
        let sink = AnonymousObservableSink(observer: observer, cancel: cancel)
        // 发射元素
        let sub = sink.run(self)
        return (sinkObserver: sink, subscriptionHandlerDispose: sub)
    }
    
}

// map后的序列
class Map<SourceType, ResultType>: Producer<ResultType> {
    
    typealias Transform2 = (SourceType) throws -> ResultType
    
    private let _source: Observable<SourceType>
    
    private let _transform: Transform2
    
    init(source: Observable<SourceType>, transform: @escaping Transform2) {
        _source = source
        _transform = transform
    }
    
    override func run<Observer>(_ observer: Observer, cancel: Cancelable) -> (sinkObserver: Disposable, subscriptionHandlerDispose: Disposable) where Element == Observer.Element, Observer : ObserverType {
        
        // observer
        let sink = MapSink(transform: self._transform, observer: observer, cancel: cancel)
        
        // SinkDisposer
        let sub = _source.subscribe(sink)
        
        return (sinkObserver: sink, subscriptionHandlerDispose: sub)
        
    }
    
}

class Buffer<Element>: Producer<[Element]> {
    
    let _source: Observable<Element>
    let _time: Int
    let _count: Int
    
    init(source: Observable<Element>, seconds: Int, count: Int) {
        _source = source
        _time = seconds
        _count = count
        super.init()
    }
    
    override func run<Observer>(_ observer: Observer, cancel: Cancelable) -> (sinkObserver: Disposable, subscriptionHandlerDispose: Disposable) where [Element] == Observer.Element, Observer : ObserverType {
        
        let coreOB = BufferCoreObserver.init(source: self, observer: observer, cancel: cancel)
        let subscriptionHandlerDispose = coreOB.run()
        return (sinkObserver: coreOB, subscriptionHandlerDispose: subscriptionHandlerDispose)
        
        
    }
    
}
