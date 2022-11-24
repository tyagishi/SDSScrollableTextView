//
//  NSUITextViewBaseCoordinator.swift
//
//  Created by : Tomoaki Yagishita on 2022/11/21
//  © 2022  SmallDeskSoftware
//

import Foundation
import SwiftUI
import Combine
import os
import SDSNSUIBridge

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#else
#error("unsupported platform")
#endif

public typealias LinkClickClosure = (NSUITextView, Any, Int) -> Bool
public typealias MenuClosure = (NSUITextView, NSUIMenu, NSUIEvent,Int) -> NSUIMenu?

open class NSUITextViewBaseCoordinator<T: TextViewSource>: NSObject, NSUITextViewDelegate {
    public var parent: SDSScrollableTextView<T>
    let menuClosure: MenuClosure?
    let linkClickClosure: LinkClickClosure?

    public init(_ parent: SDSScrollableTextView<T>,
                _ menuClosure: MenuClosure? = nil,
                _ linkClickClosure: LinkClickClosure? = nil) {
        self.parent = parent
        self.menuClosure = menuClosure
        self.linkClickClosure = linkClickClosure
    }

    // for iOS
    #if os(iOS)
    public func textViewDidChange(_ textView: UITextView) {
        guard textView.markedTextRange == nil else { return }
        Task { @MainActor in
            await self.parent.textDataSource.updateText(textView.text)
        }
    }
    #endif

    // for macOS
    #if os(macOS)
    public func textDidChange(_ notification: Notification) {
        // MARK: --NOTE--
        // sometime textDidChange will not called for each change in NSTextView
        // however NSTextView.updateNSView might be called. because of some other reason.
        // That will make inconsisitencies.
        guard let textView = notification.object as? NSUITextView,
              !textView.hasMarkedText() else { return }
        Task { @MainActor in
            await self.parent.textDataSource.updateText(textView.string)
        }
    }
    #endif
    #if os(macOS)
    public func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
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
#endif
}
