//
//  PrimitveSqeuence.swift
//  RX
//
//  Created by Gavin on 2020/6/18.
//  Copyright © 2020 LRanger. All rights reserved.
//

import Foundation

struct PrimitiveSequence<Trait, Element> {
    let source: Observable<Element>
    
    init(raw: Observable<Element>) {
        self.source = raw
    }
    
}

protocol PrimitiveSequenceType {
    associatedtype Trait
    associatedtype Element
    
    var primitiveSequence: PrimitiveSequence<Trait, Element> { get }
}

extension PrimitiveSequence: PrimitiveSequenceType {
    var primitiveSequence: PrimitiveSequence<Trait, Element> {
        return self
    }
}

extension PrimitiveSequence: ObservableConvertibleType {
    func asObservable() -> Observable<Element> {
        return self.source
    }
}


