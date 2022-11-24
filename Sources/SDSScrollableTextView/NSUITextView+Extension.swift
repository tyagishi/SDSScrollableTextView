//
//  File.swift
//
//  Created by : Tomoaki Yagishita on 2022/11/24
//  © 2022  SmallDeskSoftware
//

import Foundation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

#if os(macOS)
public typealias NSUITextViewDelegate = NSTextViewDelegate
#elseif os(iOS)
public typealias NSUITextViewDelegate = UITextViewDelegate
#endif


//extension NSUITextView {
//#if os(iOS)
//    public var string: String {
//        get {
//            return self.text
//        }
//        set(newValue) {
//            self.text = newValue
//        }
//    }
//#endif
//}
