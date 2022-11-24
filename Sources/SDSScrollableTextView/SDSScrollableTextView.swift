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

public protocol TextViewSource: Identifiable, ObservableObject {
    func updateText(_ str: String) async
    var text: String { get async }
}



public typealias CoordinatorProducer<T: TextViewSource> = ((SDSScrollableTextView<T>) -> NSUITextViewBaseCoordinator<T>)

public typealias KeyDownClosure = (NSUITextView, NSUIEvent) -> Bool
public typealias UpdateTextView<T: TextViewSource> = (NSUITextView, T, NSUITextViewBaseCoordinator<T>?) -> Void


/// wrapped NSTextView/UITextView
public struct SDSPushOutScrollableTextView<DataSource: TextViewSource>: View {
    @ObservedObject public var textDataSource: DataSource //MarkdownFile

    let textContentStorageDelegate: NSTextContentStorageDelegate?
    let textStorageDelegate: NSTextStorageDelegate?
    let textLayoutManagerDelegate: NSTextLayoutManagerDelegate?
    let textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate?

    let textContentManager: MyOwnTextContentManager?

    let coordinatorProducer: CoordinatorProducer<DataSource>

    let keyDownClosure: KeyDownClosure?
    let updateTextView: UpdateTextView<DataSource>?

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
                coordinatorProducer: @escaping CoordinatorProducer<DataSource>,
                keydownClosure: KeyDownClosure? = nil,
                updateTextView: UpdateTextView<DataSource>? = nil) {
        self.textDataSource = textDataSource
        self.textContentStorageDelegate = textContentStorageDelegate
        self.textStorageDelegate = textStorageDelegate
        self.textLayoutManagerDelegate = textLayoutManagerDelegate
        self.textViewportLayoutControllerDelegate = textViewportLayoutControllerDelegate

        self.textContentManager = textContentManager

        self.coordinatorProducer = coordinatorProducer

        self.keyDownClosure = keydownClosure
        self.updateTextView = updateTextView
    }

    public var body: some View {
        GeometryReader { geom in
            SDSScrollableTextView<DataSource>(textDataSource,
                                              rect: geom.frame(in: .local),
                                              textContentStorageDelegate: textContentStorageDelegate,
                                              textStorageDelegate: textStorageDelegate,
                                              textLayoutManagerDelegate: textLayoutManagerDelegate,
                                              textViewportLayoutControllerDelegate: textViewportLayoutControllerDelegate,
                                              textContentManager: textContentManager,
                                              coordinatorProducer: coordinatorProducer,
                                              keydownClosure: keyDownClosure,
                                              updateTextView: updateTextView)
        }
    }
}
#if os(macOS)
public struct SDSScrollableTextView<DataSource: TextViewSource>: NSViewRepresentable {
    public typealias NSViewType = NSScrollView
    let logger = Logger(subsystem: "com.smalldesksoftware.SDSScrollableTextView", category: "SDSScrollableTextView")

    @ObservedObject public var textDataSource: DataSource
    let rect: CGRect

    let textContentStorageDelegate: NSTextContentStorageDelegate?
    let textStorageDelegate: NSTextStorageDelegate?
    let textLayoutManagerDelegate: NSTextLayoutManagerDelegate?
    let textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate?

    let textContentManager: MyOwnTextContentManager? // not used yet
    let keyDownClosure: KeyDownClosure?
    let updateTextView: UpdateTextView<DataSource>?

    let coordinatorProducer: CoordinatorProducer<DataSource>

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
                coordinatorProducer: @escaping CoordinatorProducer<DataSource>,
                keydownClosure: KeyDownClosure? = nil,
                updateTextView: UpdateTextView<DataSource>? = nil,
                accessibilityIdentifier: String? = nil) {
        self.textDataSource = textDataSource
        self.rect = rect

        self.textContentStorageDelegate = textContentStorageDelegate
        self.textStorageDelegate = textStorageDelegate
        self.textLayoutManagerDelegate = textLayoutManagerDelegate
        self.textViewportLayoutControllerDelegate = textViewportLayoutControllerDelegate

        self.textContentManager = textContentManager

        self.coordinatorProducer = coordinatorProducer

        self.keyDownClosure = keydownClosure
        self.updateTextView = updateTextView

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
        //context.coordinator.textView = localTextView

        self.updateTextView?(localTextView, textDataSource, context.coordinator)
        return scrollView
    }


    public func makeCoordinator() -> NSUITextViewBaseCoordinator<DataSource> {
        //return NSUITextViewCoordinator(self, commandTextView)
        return coordinatorProducer(self)
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
//        logger.info("----------------------------------------")
//        logger.info("SDSScrollableTextView#updateNSView")
//        logger.info("----------------------------------------")
        //logger.info("SDSScrollableTextView#updateNSView <start>")
        //printSizes(scrollView)
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // MARK: most probably makeCoordinator will NOT be called for every makeNSView
        context.coordinator.parent = self
        //context.coordinator.textView = textView

        self.updateTextView?(textView, textDataSource, context.coordinator)

        // update textView size
        textView.minSize = rect.size
        textView.frame.size.width = rect.size.width
        //textView.frame.size.height = rect.size.height
        //textView.frame.size.height = 20000
        if let container = textView.textLayoutManager?.textContainer {
            container.size = rect.size
            container.size.height = CGFloat.greatestFiniteMagnitude
        }

        // now explicit command "loadTextSource" is necessary to load data from outside
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
    let updateTextView: UpdateTextView<DataSource>?

    let coordinatorProducer: CoordinatorProducer<DataSource>

    let accessibilityIdentifier: String?

    public init(_ textDataSource: DataSource,
                rect: CGRect,
                textContentStorageDelegate: NSTextContentStorageDelegate? = nil,
                textStorageDelegate: NSTextStorageDelegate? = nil,
                textLayoutManagerDelegate: NSTextLayoutManagerDelegate? = nil,
                textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate? = nil,
                textContentManager: MyOwnTextContentManager? = nil,
                coordinatorProducer: @escaping CoordinatorProducer<DataSource>,
                keydownClosure: KeyDownClosure? = nil,
                updateTextView: UpdateTextView<DataSource>? = nil,
                accessibilityIdentifier: String? = nil) {
        self.textDataSource = textDataSource
        self.rect = rect

        self.textContentStorageDelegate = textContentStorageDelegate
        self.textStorageDelegate = textStorageDelegate
        self.textLayoutManagerDelegate = textLayoutManagerDelegate
        self.textViewportLayoutControllerDelegate = textViewportLayoutControllerDelegate

        self.textContentManager = textContentManager

        self.coordinatorProducer = coordinatorProducer

        self.keyDownClosure = keydownClosure
        self.updateTextView = updateTextView

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

        self.updateTextView?(textView, textDataSource, context.coordinator)

        return textView
    }

    public func makeCoordinator() -> NSUITextViewBaseCoordinator<DataSource> {
        //return NSUITextViewCoordinator(self, commandTextView)
        return coordinatorProducer(self)
    }

    public func updateUIView(_ textView: UITextView, context: Context) {
//        logger.info("----------------------------------------")
//        logger.info("SDSScrollableTextView#updateNSView")
//        logger.info("----------------------------------------")
        //logger.info("SDSScrollableTextView#updateNSView <start>")
        //printSizes(scrollView)

        context.coordinator.parent = self

        self.updateTextView?(textView, textDataSource, context.coordinator)
    }
}
#endif

