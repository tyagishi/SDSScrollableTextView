//
//  SDSScrollableTextView.swift
//
//  Created by : Tomoaki Yagishita on 2022/01/24
//  © 2022  SmallDeskSoftware
//

import Foundation
import SwiftUI
import AppKit
import Combine
import os

public typealias MyOwnTextContentManager = NSTextContentManager & NSTextStorageObserving

//public struct TextEditorControlEnvironmentKey: EnvironmentKey {//}  FocusedValueKey {
//    public typealias Value = TextEditorControl?
//
//    static public var defaultValue: TextEditorControl? = nil
//}
//
////extension FocusedValues {
//extension EnvironmentValues {
//    public var currentEditorControl: TextEditorControlEnvironmentKey.Value {
//        get { self[TextEditorControlEnvironmentKey.self] }
//        set { self[TextEditorControlEnvironmentKey.self] = newValue }
//    }
//}

public class TextEditorControl: NSObject {
    public var textView: NSTextView? = nil
//    public var firstResponder: Bool = false
//    @Published public var selectionRange: NSRange? = nil
//    @Published public var insertText: String? = nil
//    @Published public var insertRange: NSRange? = nil
//    @Published public var cursors: NSRange? = nil
//    var textContentManager: NSTextContentManager
//    public init(_ contentManager: NSTextContentManager) {
//        textContentManager = contentManager
//    }
//    public init() {}
    public func focusRange(_ nsRange: NSRange) {
        textView?.scrollRangeToVisible(nsRange)
    }

}
public typealias KeyDownClosure = (NSTextView, NSEvent) -> Bool

public struct SDSPushOutScrollableTextView: View {
    @Binding var text: String

    let textContentStorageDelegate: NSTextContentStorageDelegate?
    let textStorageDelegate: NSTextStorageDelegate?
    let textLayoutManagerDelegate: NSTextLayoutManagerDelegate?
    let textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate?

    let control: TextEditorControl?

    let textContentManager: MyOwnTextContentManager?
    let keyDownClosure: KeyDownClosure?

    public init(_ text: Binding<String>,
                textContentStorageDelegate: NSTextContentStorageDelegate? = nil,
                textStorageDelegate: NSTextStorageDelegate? = nil,
                textLayoutManagerDelegate: NSTextLayoutManagerDelegate? = nil,
                textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate? = nil,
                control: TextEditorControl? = nil,
                textContentManager: MyOwnTextContentManager? = nil,
                keydownClosure: KeyDownClosure? = nil ) {
        self._text = text

        self.textContentStorageDelegate = textContentStorageDelegate
        self.textStorageDelegate = textStorageDelegate
        self.textLayoutManagerDelegate = textLayoutManagerDelegate
        self.textViewportLayoutControllerDelegate = textViewportLayoutControllerDelegate

        self.control = control

        self.textContentManager = textContentManager
        self.keyDownClosure = keydownClosure
    }

    public var body: some View {
        GeometryReader { geom in
            SDSScrollableTextView($text,
                                  rect: geom.frame(in: .local),
                                  textContentStorageDelegate: textContentStorageDelegate,
                                  textStorageDelegate: textStorageDelegate,
                                  textLayoutManagerDelegate: textLayoutManagerDelegate,
                                  textViewportLayoutControllerDelegate: textViewportLayoutControllerDelegate,
                                  control: control,
                                  textContentManager: textContentManager,
                                  keydownClosure: keyDownClosure)
        }
    }
}

public struct SDSScrollableTextView: NSViewRepresentable {
    public typealias NSViewType = NSScrollView
    let logger = Logger(subsystem: "com.smalldesksoftware.SDSScrollableTextView", category: "SDSScrollableTextView")

    @Binding var text: String
    let rect: CGRect

    let textContentStorageDelegate: NSTextContentStorageDelegate?
    let textStorageDelegate: NSTextStorageDelegate?
    let textLayoutManagerDelegate: NSTextLayoutManagerDelegate?
    let textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate?

    let control: TextEditorControl?

    let textContentManager: MyOwnTextContentManager? // not used yet
    let keyDownClosure: KeyDownClosure?

    var textKit1Check: AnyCancellable?

    public init(_ text: Binding<String>,
                rect: CGRect,
                textContentStorageDelegate: NSTextContentStorageDelegate? = nil,
                textStorageDelegate: NSTextStorageDelegate? = nil,
                textLayoutManagerDelegate: NSTextLayoutManagerDelegate? = nil,
                textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate? = nil,
                control: TextEditorControl? = nil,
                textContentManager: MyOwnTextContentManager? = nil,
                keydownClosure: KeyDownClosure? = nil ) {
        self._text = text
        self.rect = rect

        self.textContentStorageDelegate = textContentStorageDelegate
        self.textStorageDelegate = textStorageDelegate
        self.textLayoutManagerDelegate = textLayoutManagerDelegate
        self.textViewportLayoutControllerDelegate = textViewportLayoutControllerDelegate

        self.control = control

        self.textContentManager = textContentManager
        self.keyDownClosure = keydownClosure

        textKit1Check = NotificationCenter.default.publisher(for: NSTextView.willSwitchToNSLayoutManagerNotification)
            .sink { value in
                print("==================== Switched to TextKit1 ====================")
                print("receive willSwitchToNSLayoutManagerNotification with \(value)")
            }
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        //logger.info("SDSScrollableTextView#makeNSView")
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
        let textContentStorage = NSTextContentStorage()
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContentStorage.delegate = textContentStorageDelegate

        // textview
        let textView = MyNSTextView(frame: rect, textContainer: textContainer, keyDown: keyDownClosure)//NSTextView(frame: rect, textContainer: textContainer)
        //let textView = NSTextView(frame: rect, textContainer: textContainer)
        if let textStorageDelegate = textStorageDelegate {
            textView.textStorage?.delegate = textStorageDelegate
        }
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.allowsUndo = true
        textView.usesRuler = false
        textView.usesInspectorBar = false
        
        //textView.backgroundColor = .blue
        textView.minSize = CGSize(width: 0, height: rect.height)
        textView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false // does not need to expand/shrink without view size change

        textContentStorage.textStorage?.setAttributedString(NSAttributedString(string: text))

        // NSTextView のサイズを自動で広げてくれる(TextContainer は広げてくれない)
        // .height は、新しい行が追加された時に TextView が広がるために必要
        textView.autoresizingMask = [.height]
        //textView.textContainer?.heightTracksTextView = true
        
        textView.textContainer?.containerSize = CGSize(width: rect.size.width, height: CGFloat.greatestFiniteMagnitude)
        //textView.textContainer?.widthTracksTextView = true
        
        // assemble
        scrollView.documentView = textView

        control?.textView = textView

        return scrollView
    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        logger.info("SDSScrollableTextView#updateNSView")
        //printSizes(scrollView)
        guard let textView = scrollView.documentView as? NSTextView else { return }
        control?.textView = textView

        // update delegate
        textView.textStorage?.delegate = textStorageDelegate
        textView.textLayoutManager?.delegate = textLayoutManagerDelegate
        textView.textContentStorage?.delegate = textContentStorageDelegate

        // update textView size
        textView.minSize = rect.size
        textView.frame.size.width = rect.size.width
        //textView.frame.size.height = rect.size.height
        //textView.frame.size.height = 20000
        if let container = textView.textLayoutManager?.textContainer {
            container.size = rect.size
            container.size.height = CGFloat.greatestFiniteMagnitude
        }
        // update view content
        if let textStorage = textView.textStorage {
            if textStorage.string != text {
                textStorage.beginEditing()
                textStorage.setAttributedString(NSAttributedString(string: text))
                textStorage.endEditing()
            }
        }
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SDSScrollableTextView

        init(_ parent: SDSScrollableTextView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
        
        public func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
            // iff necessary, need to insert my own menus into passed menu
            //let myMenuItem = NSMenuItem(title: "MyMenu", action: nil, keyEquivalent: "")
            //menu.addItem(myMenuItem)
            return menu
        }
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
    private var fragmentLayerMap: NSMapTable<NSTextLayoutFragment, CALayer> = .weakToWeakObjects()
    private var contentLayer: CALayer! = nil
    private var selectionLayer: CALayer! = nil

    let keyDownClosure: KeyDownClosure?

    init(frame: CGRect, textContainer: NSTextContainer, keyDown: KeyDownClosure? = nil ) {
        self.keyDownClosure = keyDown
        super.init(frame: frame, textContainer: textContainer)
    }

    open override var acceptsFirstResponder: Bool { return true }

    open override func prepareContent(in rect: NSRect) {
        layer!.setNeedsLayout()
        super.prepareContent(in: rect)
    }
    open override class var isCompatibleWithResponsiveScrolling: Bool { return true }

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
}
