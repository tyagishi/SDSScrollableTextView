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
    let menuClosure: MenuClosure?
    let linkClickClosure: LinkClickClosure?


    var anyCancellable: AnyCancellable? = nil

    public init(_ parent: SDSScrollableTextView<TDS>,
                _ commandTextView: PassthroughSubject<TextViewOperation, Never>?,
                _ menuClosure: MenuClosure? = nil,
                _ linkClickClosure: LinkClickClosure? = nil) {
        self.commandTextView = commandTextView
        self.menuClosure = menuClosure
        self.linkClickClosure = linkClickClosure
        super.init(parent)
        anyCancellable = commandTextView?
            .sink(receiveValue: {ope in
                self.operation(ope)
            })
    }

    public func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
        // iff necessary, need to insert my own menus into passed menu
        //let myMenuItem = NSMenuItem(title: "MyMenu", action: nil, keyEquivalent: "")
        //menu.addItem(myMenuItem)
        if let menuClose = self.menuClosure {
            return menuClose(view, menu, event, charIndex)
        }
        return menu
    }
    public func textView(_ textView: NSUITextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let linkClickClosure = self.linkClickClosure {
            return linkClickClosure(textView, link, charIndex)
        }
        return false
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
    case mark(ranges: [NSRange])
    case scrollTo(range: NSRange)
    case addAttribute(key: NSAttributedString.Key, value: Any, range: NSRange)
    case needsLayout
    case needsDisplay
    case makeFirstResponder
    case markEdited(range: NSRange?)
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
            case .mark(let ranges):
                for range in ranges {
                    textView.textStorage?.edited(.editedAttributes, range: range, changeInLength: 0)
                }
            case .markEdited(let range):
                let range = range ?? textView.string.fullNSRange
                textView.textStorage?.edited(.editedAttributes, range: range, changeInLength: 0)
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
