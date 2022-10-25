//
//  File.swift
//
//  Created by : Tomoaki Yagishita on 2022/10/25
//  © 2022  SmallDeskSoftware
//

import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SDSNSUIBridge

extension NSUITextView {
    var nsuiSelectedRange: NSRange? {
        #if os(macOS)
        return self.selectedRanges.first?.rangeValue
        #elseif os(iOS)
        return self.selectedRange
        #endif
    }
    func nsuiInsertText(_ text: String,_ range:NSRange) {
        #if os(macOS)
        self.insertText(text, replacementRange: range)
        #elseif os(iOS)
        fatalError("not implemented")
        #endif
    }
}
