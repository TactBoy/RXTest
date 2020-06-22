//
//  Single.swift
//  RX
//
//  Created by Gavin on 2020/6/18.
//  Copyright © 2020 LRanger. All rights reserved.
//

import Foundation

enum SingleEvent<Element> {
    case success(Element)
    case error(Swift.Error)
}

enum Singletrait {}

typealias Single<Element> = PrimitiveSequence<Singletrait, Element>

extension PrimitiveSequence where Trait == Singletrait {
    
    typealias SingleSubscribeHandler = (SingleEvent<Element>) -> Void
    
    static func create(subscribe: @escaping (@escaping SingleSubscribeHandler) -> Disposable) -> Single<Element> {
        let source = Observable<Element>.create { (ob) -> Disposable in
            return subscribe( { event in
                
                switch event {
                case .success(let ele):
                    ob.on(.next(ele))
                    ob.on(.complete)
                case .error(let error):
                    ob.on(.error(error))
                }
                
            })
        }
        return PrimitiveSequence.init(raw: source)
    }
    
    func subscribe(_ observer: @escaping (SingleEvent<Element>) -> Void) -> Disposable {
        
        var stopped = false
        
        return self.primitiveSequence.asObservable().subscribe { (event) in
            
            if stopped { return }
            stopped = true
            
            switch event {
            case .next(let ele):
                observer(.success(ele))
            case .error(let error):
                observer(.error(error))
            case .complete:
                print("Singles can't emit a completion event")
            }
            
        }
        
    }
    
    
}



