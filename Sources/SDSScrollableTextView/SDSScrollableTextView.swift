//
//  SDSScrollableTextView.swift
//
//  Created by : Tomoaki Yagishita on 2022/01/24
//  © 2022  SmallDeskSoftware
//

import Foundation
import SwiftUI
import Combine
import os
import SDSNSUIBridge
import SDSStringExtension

#if os(macOS)
import AppKit
public typealias NSUITextView = NSTextView
#elseif os(iOS)
import UIKit
public typealias NSUITextView = UITextView
#else
#error("unsupported platform")
#endif


public typealias MyOwnTextContentManager = NSTextContentManager & NSTextStorageObserving

public enum TextViewOperation {
    case insert(text: String, range: NSRange?)
    case setRange(range: NSRange)
    case mark(ranges: [NSRange])
    case scrollTo(range: NSRange)
    case needsLayout
    case needsDisplay
    case makeFirstResponder
}
extension SDSScrollableTextView.Coordinator {
    public func operation(_ ope: TextViewOperation) {
        guard let textView = textView else { return }
        DispatchQueue.main.async {
            switch ope {
            case .insert(let string, let range):
                guard let range = range ?? textView.nsuiSelectedRange else { return }
                textView.nsuiInsertText(string, range)
            case .setRange(let range):
                textView.setSelectedRange(range)
            case .scrollTo(let range):
                textView.scrollRangeToVisible(range)
            case .mark(let ranges):
                for range in ranges {
                    textView.textStorage?.edited(.editedAttributes, range: range, changeInLength: 0)
                }
            case .needsLayout:
                textView.needsLayout = true
            case .needsDisplay:
                textView.needsDisplay = true
            case .makeFirstResponder:
#if os(macOS)
                DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
                    textView.window?.makeFirstResponder(textView)
                }
#else
                break
#endif
            }
        }
    }
}

public protocol TextViewSource: Identifiable, ObservableObject {
    func updateText(_ str: String)
    var text: String { get }
}

public typealias KeyDownClosure = (NSUITextView, NSUIEvent) -> Bool
public typealias Configure = (NSUITextView, any TextViewSource) -> Void

public typealias MenuClosure = (NSUITextView, NSUIMenu, NSUIEvent,Int) -> NSUIMenu?

/// wrapped NSTextView/UITextView
public struct SDSPushOutScrollableTextView<DataSource: TextViewSource>: View {
    @ObservedObject var textDataSource: DataSource //MarkdownFile

    let textContentStorageDelegate: NSTextContentStorageDelegate?
    let textStorageDelegate: NSTextStorageDelegate?
    let textLayoutManagerDelegate: NSTextLayoutManagerDelegate?
    let textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate?

    let textContentManager: MyOwnTextContentManager?
    let keyDownClosure: KeyDownClosure?
    let sync: Configure?
    let commandTextView: PassthroughSubject<TextViewOperation, Never>?
    let menuClosure: MenuClosure?



    /// initializer
    /// - Parameters:
    ///   - textDataSource: text data provider (needs to conform to TextViewSource)
    ///   - textContentStorageDelegate: delegate
    ///   - textStorageDelegate: delegate
    ///   - textLayoutManagerDelegate: delegate
    ///   - textViewportLayoutControllerDelegate: delegate
    ///   - control: textview provider for external control
    ///   - textContentManager: textContentManager
    ///   - keydownClosure: keydownClosure (make sense only for macOS)
    ///   - sync: setup closure for setup/update
    ///   - menuClosure: menu closure (make sense only for macOS)
    public init(_ textDataSource: DataSource,
                textContentStorageDelegate: NSTextContentStorageDelegate? = nil,
                textStorageDelegate: NSTextStorageDelegate? = nil,
                textLayoutManagerDelegate: NSTextLayoutManagerDelegate? = nil,
                textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate? = nil,
                textContentManager: MyOwnTextContentManager? = nil,
                keydownClosure: KeyDownClosure? = nil,
                configure: Configure? = nil,
                commandTextView: PassthroughSubject<TextViewOperation, Never>? = nil,
                menuClosure: MenuClosure? = nil) {
        self.textDataSource = textDataSource
        self.textContentStorageDelegate = textContentStorageDelegate
        self.textStorageDelegate = textStorageDelegate
        self.textLayoutManagerDelegate = textLayoutManagerDelegate
        self.textViewportLayoutControllerDelegate = textViewportLayoutControllerDelegate

        self.textContentManager = textContentManager
        self.keyDownClosure = keydownClosure
        self.sync = configure
        self.commandTextView = commandTextView
        self.menuClosure = menuClosure
    }

    public var body: some View {
        GeometryReader { geom in
            SDSScrollableTextView(textDataSource,
                                  rect: geom.frame(in: .local),
                                  textContentStorageDelegate: textContentStorageDelegate,
                                  textStorageDelegate: textStorageDelegate,
                                  textLayoutManagerDelegate: textLayoutManagerDelegate,
                                  textViewportLayoutControllerDelegate: textViewportLayoutControllerDelegate,
                                  textContentManager: textContentManager,
                                  keydownClosure: keyDownClosure,
                                  configure: sync,
                                  commandTextView: commandTextView,
                                  menuClosure: menuClosure)
        }
    }
}
#if os(macOS)
public struct SDSScrollableTextView<DataSource: TextViewSource>: NSViewRepresentable {
    public typealias NSViewType = NSScrollView
    let logger = Logger(subsystem: "com.smalldesksoftware.SDSScrollableTextView", category: "SDSScrollableTextView")

    @ObservedObject var textDataSource: DataSource
    let rect: CGRect

    let textContentStorageDelegate: NSTextContentStorageDelegate?
    let textStorageDelegate: NSTextStorageDelegate?
    let textLayoutManagerDelegate: NSTextLayoutManagerDelegate?
    let textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate?

    let textContentManager: MyOwnTextContentManager? // not used yet
    let keyDownClosure: KeyDownClosure?
    let configure: Configure?
    let commandTextView: PassthroughSubject<TextViewOperation, Never>?
    let menuClosure: MenuClosure?

    let accessibilityIdentifier: String?

    var textView: NSUITextView? = nil

    var textKit1Check: AnyCancellable?

    public init(_ textDataSource: DataSource,
                rect: CGRect,
                textContentStorageDelegate: NSTextContentStorageDelegate? = nil,
                textStorageDelegate: NSTextStorageDelegate? = nil,
                textLayoutManagerDelegate: NSTextLayoutManagerDelegate? = nil,
                textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate? = nil,
                textContentManager: MyOwnTextContentManager? = nil,
                keydownClosure: KeyDownClosure? = nil,
                configure: Configure? = nil,
                commandTextView: PassthroughSubject<TextViewOperation, Never>? = nil,
                menuClosure: MenuClosure? = nil,
                accessibilityIdentifier: String? = nil) {
        self.textDataSource = textDataSource
        self.rect = rect

        self.textContentStorageDelegate = textContentStorageDelegate
        self.textStorageDelegate = textStorageDelegate
        self.textLayoutManagerDelegate = textLayoutManagerDelegate
        self.textViewportLayoutControllerDelegate = textViewportLayoutControllerDelegate

        self.textContentManager = textContentManager
        self.keyDownClosure = keydownClosure
        self.configure = configure
        self.commandTextView = commandTextView
        self.menuClosure = menuClosure

        self.accessibilityIdentifier = accessibilityIdentifier

        textKit1Check = NotificationCenter.default.publisher(for: NSTextView.willSwitchToNSLayoutManagerNotification)
            .sink { value in
                print("==================== Switched to TextKit1 ====================")
                print("receive willSwitchToNSLayoutManagerNotification with \(value)")
            }
    }

    public func makeNSView(context: Context) -> NSScrollView {
//        logger.info("----------------------------------------")
//        logger.info("SDSScrollableTextView#makeNSView")
//        logger.info("----------------------------------------")
        // scrollview setup
        let scrollView = NSScrollView(frame: rect)
        scrollView.borderType = .lineBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]

        // setup TextlayoutManager
        let textLayoutManager = NSTextLayoutManager()
        textLayoutManager.delegate = textLayoutManagerDelegate
        if let textViewportLayoutControllerDelegate = textViewportLayoutControllerDelegate {
            textLayoutManager.textViewportLayoutController.delegate = textViewportLayoutControllerDelegate
        }

        // setup TextContainer (at WWDC21 Video, height is specified with 0.0)
        let textContainer = NSTextContainer(size: CGSize( width: rect.size.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true // adjust width according to textView
        textContainer.heightTracksTextView = true
        textLayoutManager.textContainer = textContainer

        //let textContentStorage = context.coordinator.textContentManager
        let textContentStorage = textContentManager ?? NSTextContentStorage()
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContentStorage.delegate = textContentStorageDelegate

        // textview
        let localTextView = MyNSTextView(frame: rect, textContainer: textContainer, keyDown: keyDownClosure)//NSTextView(frame: rect, textContainer: textContainer)
        //let textView = NSTextView(frame: rect, textContainer: textContainer)
        if let textStorageDelegate = textStorageDelegate {
            localTextView.textStorage?.delegate = textStorageDelegate
        }
        localTextView.delegate = context.coordinator
        localTextView.isEditable = true
        localTextView.allowsUndo = true
        localTextView.usesRuler = false
        localTextView.usesInspectorBar = false
        localTextView.setAccessibilityIdentifier(accessibilityIdentifier)

        //textView.backgroundColor = .blue
        localTextView.minSize = CGSize(width: 0, height: rect.height)
        localTextView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        localTextView.isVerticallyResizable = true
        localTextView.isHorizontallyResizable = false // does not need to expand/shrink without view size change

        // NSTextView のサイズを自動で広げてくれる(TextContainer は広げてくれない)
        // .height は、新しい行が追加された時に TextView が広がるために必要
        localTextView.autoresizingMask = [.height]
        //textView.textContainer?.heightTracksTextView = true

        localTextView.textContainer?.containerSize = CGSize(width: rect.size.width, height: CGFloat.greatestFiniteMagnitude)
        //textView.textContainer?.widthTracksTextView = true

        // assemble
        scrollView.documentView = localTextView
        context.coordinator.textView = localTextView

        self.configure?(localTextView, textDataSource)
        return scrollView
    }


    public func makeCoordinator() -> Coordinator {
        return Coordinator(self, commandTextView)
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
//        logger.info("----------------------------------------")
//        logger.info("SDSScrollableTextView#updateNSView")
//        logger.info("----------------------------------------")
        //logger.info("SDSScrollableTextView#updateNSView <start>")
        //printSizes(scrollView)
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // MARK: most probably makeCoordinator will NOT called for every makeNSView
        context.coordinator.parent = self

        // update textView size
        textView.minSize = rect.size
        textView.frame.size.width = rect.size.width
        //textView.frame.size.height = rect.size.height
        //textView.frame.size.height = 20000
        if let container = textView.textLayoutManager?.textContainer {
            container.size = rect.size
            container.size.height = CGFloat.greatestFiniteMagnitude
        }

        if let textStorage = textView.textStorage {
            if textStorage.string != textDataSource.text {
                textView.textContentStorage?.performEditingTransaction({
                    textStorage.setAttributedString(NSAttributedString(string: textDataSource.text))
                })
            }
        }
        self.configure?(textView, textDataSource)
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SDSScrollableTextView
        var textView: NSTextView? = nil
        let commandTextView: PassthroughSubject<TextViewOperation, Never>?
        var anyCancellable: AnyCancellable? = nil

        init(_ parent: SDSScrollableTextView,_ commandTextView: PassthroughSubject<TextViewOperation, Never>? ) {
            self.parent = parent
            self.commandTextView = commandTextView
            super.init()
            anyCancellable = commandTextView?
                .sink(receiveValue: {ope in
                    self.operation(ope)
                })
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let textStorage = textView.textStorage else { return }
            self.parent.textDataSource.updateText(textStorage.string)
        }

        public func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
            // iff necessary, need to insert my own menus into passed menu
            //let myMenuItem = NSMenuItem(title: "MyMenu", action: nil, keyEquivalent: "")
            //menu.addItem(myMenuItem)
            if let menuClose = parent.menuClosure {
                return menuClose(view, menu, event, charIndex)
            }
            return menu
        }

//        // MARK: for debug
//        public func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange, toCharacterRange newSelectedCharRange: NSRange) -> NSRange {
//            print(#function)
//            return newSelectedCharRange
//        }
    }

    // utility for debug
    func printSizes(_ scrollView: NSScrollView) {
        if let textView = scrollView.documentView as? NSTextView {
            print("textView frame: \(textView.frame)")
            if let container = textView.textLayoutManager?.textContainer {
                print("container Size: \(container.size)")
            }
        }
    }
}

open class MyNSTextView: NSTextView {
    let keyDownClosure: KeyDownClosure?

    init(frame: CGRect, textContainer: NSTextContainer, keyDown: KeyDownClosure? = nil ) {
        self.keyDownClosure = keyDown
        super.init(frame: frame, textContainer: textContainer)
    }

    open override var acceptsFirstResponder: Bool { return true }

    required public init?(coder: NSCoder) {
        fatalError("not implemented")
    }

    override open func keyDown(with event: NSEvent) {
        if let closure = keyDownClosure {
            if closure(self, event) {
                return
            }
        }
        super.keyDown(with: event)
    }

//    open override func mouseDown(with event: NSEvent) {
//        //self.setSelectedRange(NSRange.init(location: 0, length: self.textStorage?.string.count ?? 0))
//        print(#function)
//        super.mouseDown(with: event)
//    }
}
#elseif os(iOS)
// NOTE: contex menu is not implemented for iOS version
public struct SDSScrollableTextView<DataSource: TextViewSource>: UIViewRepresentable {
    public typealias UIViewType = UITextView
    let logger = Logger(subsystem: "com.smalldesksoftware.SDSScrollableTextView", category: "SDSScrollableTextView")

    @ObservedObject var textDataSource: DataSource
    let rect: CGRect

    let textContentStorageDelegate: NSTextContentStorageDelegate?
    let textStorageDelegate: NSTextStorageDelegate?
    let textLayoutManagerDelegate: NSTextLayoutManagerDelegate?
    let textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate?

    let textContentManager: MyOwnTextContentManager? // not used yet
    let keyDownClosure: KeyDownClosure?
    let configure: Configure?
    let commandTextView: PassthroughSubject<TextViewOperation, Never>?

    let accessibilityIdentifier: String?

    public init(_ textDataSource: DataSource,
                rect: CGRect,
                textContentStorageDelegate: NSTextContentStorageDelegate? = nil,
                textStorageDelegate: NSTextStorageDelegate? = nil,
                textLayoutManagerDelegate: NSTextLayoutManagerDelegate? = nil,
                textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate? = nil,
                textContentManager: MyOwnTextContentManager? = nil,
                keydownClosure: KeyDownClosure? = nil,
                configure: Configure? = nil,
                commandTextView: PassthroughSubject<TextViewOperation, Never>? = nil,
                menuClosure: MenuClosure? = nil,
                accessibilityIdentifier: String? = nil) {
        self.textDataSource = textDataSource
        self.rect = rect

        self.textContentStorageDelegate = textContentStorageDelegate
        self.textStorageDelegate = textStorageDelegate
        self.textLayoutManagerDelegate = textLayoutManagerDelegate
        self.textViewportLayoutControllerDelegate = textViewportLayoutControllerDelegate

        self.textContentManager = textContentManager
        self.keyDownClosure = keydownClosure
        self.configure = configure
        self.commandTextView = commandTextView
        self.accessibilityIdentifier = accessibilityIdentifier

        // NOTE: detect switch to TextKit1?
        // set breakpoint at _UITextViewEnablingCompatibilityMode
    }

    public func makeUIView(context: Context) -> UITextView {
//        logger.info("----------------------------------------")
//        logger.info("SDSScrollableTextView#makeNSView")
//        logger.info("----------------------------------------")
        // scrollview setup


        // setup TextlayoutManager
        let textLayoutManager = NSTextLayoutManager()
        textLayoutManager.delegate = textLayoutManagerDelegate
        if let textViewportLayoutControllerDelegate = textViewportLayoutControllerDelegate {
            textLayoutManager.textViewportLayoutController.delegate = textViewportLayoutControllerDelegate
        }

        // setup TextContainer (at WWDC21 Video, height is specified with 0.0)
        let textContainer = NSTextContainer(size: CGSize( width: rect.size.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true // adjust width according to textView
        textContainer.heightTracksTextView = true
        textLayoutManager.textContainer = textContainer

        //let textContentStorage = context.coordinator.textContentManager
        let textContentStorage = NSTextContentStorage()
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContentStorage.delegate = textContentStorageDelegate

        let textView = UITextView(frame: rect, textContainer: textContainer)
        textView.textStorage.delegate = textStorageDelegate
        textView.delegate = context.coordinator

        context.coordinator.textView = textView

        self.configure?(textView, textDataSource)

        return textView
    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    public func updateUIView(_ textView: UITextView, context: Context) {
//        logger.info("----------------------------------------")
//        logger.info("SDSScrollableTextView#updateNSView")
//        logger.info("----------------------------------------")
        //logger.info("SDSScrollableTextView#updateNSView <start>")
        //printSizes(scrollView)

        // update delegate
        textView.textStorage.delegate = textStorageDelegate
        textView.textLayoutManager?.delegate = textLayoutManagerDelegate
        // TODO: no textContentStorage in UITextView??
        // textView.textContentStorage.delegate = textContentStorageDelegate

        // update view content
        if textView.textStorage.string != textDataSource.text {
            textView.textStorage.beginEditing()
            textView.textStorage.setAttributedString(NSAttributedString(string: textDataSource.text))
            textView.textStorage.endEditing()
        }
        self.configure?(textView, textDataSource)
    }

    public class Coordinator: NSObject, UITextViewDelegate {
        var parent: SDSScrollableTextView
        var textView: UITextView? = nil
        let commandTextView: PassthroughSubject<TextViewOperation, Never>?
        var anyCancellable: AnyCancellable? = nil

        init(_ parent: SDSScrollableTextView) {
            self.parent = parent
        }

        public func textViewDidChange(_ textView: UITextView) {
            self.parent.textDataSource.updateText(textView.text)
        }
    }
}
#endif

