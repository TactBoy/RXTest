//
//  Just.swift
//  RX
//
//  Created by Gavin on 2020/6/18.
//  Copyright © 2020 LRanger. All rights reserved.
//

import Foundation

class Just<Element>: Producer<Element> {
    
    private let _element: Element
    
    init(element: Element) {
        _element = element
    }
    
    override func subscribe<Observer>(_ observer: Observer) -> Disposable where Element == Observer.Element, Observer : ObserverType {
        
        observer.onNext(element: _element)
        observer.onComplete()
        return Disposables.create()
        
    }
    
}
