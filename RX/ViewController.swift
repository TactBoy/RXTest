//
//  ViewController.swift
//  RX
//
//  Created by Gavin on 2020/6/15.
//  Copyright © 2020 LRanger. All rights reserved.
//

import UIKit


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        
//         let oba = Observable<Int>.create { (ob) -> Disposable in
//            
////            print("in ob: \(ob.pointString): \(ob)")
//            
//            ob.onNext(element: 100)
//            
//            ob.onComplete()
//            
//            return Disposables.create()
//            
//        }
//        print(oba)

//         let ob = AnyObserver<Int>.init { (event) in
//
//            switch event {
//            case .next(let value):
//                print(value)
//            case .error(let error):
//                print(error)
//            case .complete:
//                print("comlpete")
//            }
//
//        }
//        print("\(ob.pointString), \(ob)")

//        let dispose = oba.subscribe(onNext: { (value) in
//            print(value)
//
//        }, onError: { (error) in
//            print(error)
//
//        }, onComplete: {
//            print("comlpete")
//
//        }) {
//            print("dispose")
//
//        }
//
//        oba.map { (value) -> String in
//            return "\(value + 1000)"
//        }.subscribe(onNext: { (value) in
//
//        }, onError: { (error) in
//
//        }, onComplete: {
//
//        }) {
//
//        }
    
//        let single = Single<Int>.create { (eventHandler) -> Disposable in
//
//            eventHandler(.success(100))
//
//            return Disposables.create {
//
//            }
//
//        }
        
        let o1 = Observable<Int>.create { (ob) -> Disposable in
            
            var index = 0
            
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { (t) in
                
                index += 1
                
                ob.onNext(element: index)
                
                
            }

            
            return Disposables.create {
                print("o1 dispose")
            }
            
        }
            
        let buf = o1.buffer(time: 3, count: 3).subscribe { (event) in
            print(event)
        }
        
        
        
        

//        oba.subscribe(ob)
    
//        print(dispose)
        
    }

}


