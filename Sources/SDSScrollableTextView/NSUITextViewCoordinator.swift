//
//  File.swift
//
//  Created by : Tomoaki Yagishita on 2022/11/14
//  © 2022  SmallDeskSoftware
//

import SwiftUI
import Combine
import os
import SDSNSUIBridge
import SDSStringExtension

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#else
#error("unsupported platform")
#endif

public typealias LinkClickClosure = (NSUITextView, Any, Int) -> Bool
public typealias MenuClosure = (NSUITextView, NSUIMenu, NSUIEvent,Int) -> NSUIMenu?

#if os(macOS)
public class NSUITextViewCoordinator<TDS: TextViewSource>: NSUITextViewBaseCoordinator<TDS> {
    public var textView: NSTextView? = nil
    let commandTextView: PassthroughSubject<TextViewOperation, Never>?


    var anyCancellable: AnyCancellable? = nil

    public init(_ parent: SDSScrollableTextView<TDS>,
                _ commandTextView: PassthroughSubject<TextViewOperation, Never>?,
                _ menuClosure: MenuClosure? = nil,
                _ linkClickClosure: LinkClickClosure? = nil) {
        self.commandTextView = commandTextView
        super.init(parent, menuClosure, linkClickClosure)
        anyCancellable = commandTextView?
            .sink(receiveValue: {ope in
                self.operation(ope)
            })
    }



//        // MARK: for debug
//        public func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange, toCharacterRange newSelectedCharRange: NSRange) -> NSRange {
//            print(#function)
//            return newSelectedCharRange
//        }
}
#endif

public enum TextViewOperation {
    case loadTextSource
    case insert(text: String, range: NSRange?)
    case setRange(range: NSRange)
    case markEditeds(ranges: [NSRange])
    case markEdited(range: NSRange?)
    case scrollTo(range: NSRange)
    case addAttribute(key: NSAttributedString.Key, value: Any, range: NSRange)
    case needsLayout
    case needsDisplay
    case makeFirstResponder
}
extension NSUITextViewCoordinator {
    public func operation(_ ope: TextViewOperation) {
        guard let textView = textView else { return }
        DispatchQueue.main.async {
            switch ope {
            case .loadTextSource:
                if let textStorage = textView.textStorage {
                    Task {
                        let text = await self.parent.textDataSource.text
                        textStorage.setAttributedString(NSAttributedString(string: text))
                    }
                    //textStorage.setAttributedString(NSAttributedString(string: self.parent.textDataSource.text))
                }
            case .insert(let string, let range):
                guard let range = range ?? textView.nsuiSelectedRange else { return }
                textView.nsuiInsertText(string, range)
            case .setRange(let range):
                DispatchQueue.main.asyncAfter(deadline: .now()+0.01) {
                    textView.setSelectedRange(range)
                }
            case .scrollTo(let range):
                DispatchQueue.main.asyncAfter(deadline: .now()+0.01) {
                    textView.scrollRangeToVisible(range)
                }
            case .addAttribute(let key, let value, let range):
                textView.textStorage?.addAttribute(key, value: value, range: range)
            case .markEditeds(let ranges):
                guard let text = textView.textStorage?.string else { break }
                for range in ranges {
                    if !text.isValid(nsRange: range) { print("invalid range?"); break }
                    textView.textStorage?.edited(.editedAttributes, range: range, changeInLength: 0)
                }
            case .markEdited(let range):
                guard let text = textView.textStorage?.string else { break }
                if let range = range,
                   !text.isValid(nsRange: range) {
                    print("invalid range?")
                    break
                }
                let markRange = range ?? text.fullNSRange
                textView.textStorage?.edited(.editedAttributes, range: markRange, changeInLength: 0)
            case .needsLayout:
                textView.needsLayout = true
            case .needsDisplay:
                textView.needsDisplay = true
            case .makeFirstResponder:
#if os(macOS)
                DispatchQueue.main.asyncAfter(deadline: .now()+0.01) {
                    textView.window?.makeFirstResponder(textView)
                }
#else
                break
#endif
            }
        }
    }
}
