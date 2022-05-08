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

public class TextEditorControl: ObservableObject {
    @Published public var firstResponder: Bool = false
    @Published public var focusRange: NSRange? = nil
    @Published public var insertText: String? = nil
//    var textContentManager: NSTextContentManager
//    public init(_ contentManager: NSTextContentManager) {
//        textContentManager = contentManager
//    }
    public init() {}
}
public typealias keydownClosure = (NSTextView, NSEvent) -> Bool

public struct TextEditorDelegates {
    var textContentStorageDelegate: NSTextContentStorageDelegate? = nil
    var textStorageDelegate: NSTextStorageDelegate? = nil
    var textLayoutManagerDelegate: NSTextLayoutManagerDelegate? = nil
    var textViewportLayoutControllerDelegate: NSTextViewportLayoutControllerDelegate? = nil
}
public protocol TextEditorSource: NSTextContentStorageDelegate, NSTextStorageDelegate,
                                  NSTextLayoutManagerDelegate, NSTextViewportLayoutControllerDelegate {
    var text: String {get set}
}

public struct SDSScrollableTextView: NSViewRepresentable {
    public typealias NSViewType = NSScrollView
    static let logger = Logger(subsystem: "com.smalldesksoftware.SDSScrollableTextView", category: "SDSScrollableTextView")
    
    var textEditorSource: TextEditorSource
    var control: TextEditorControl?
    let rect: CGRect
    
    let textContentManager: MyOwnTextContentManager?
    var textKit1Check: AnyCancellable? = nil
    let keyDownClosure: keydownClosure?

    public init(_ textEditorSource: TextEditorSource,
                control: TextEditorControl? = nil,
                rect: CGRect,
                textContentManager: MyOwnTextContentManager? = nil,
                keydownClosure: keydownClosure? = nil ) {
        self.textEditorSource = textEditorSource
        self.control = control
        self.rect = rect
        self.textContentManager = textContentManager
        self.keyDownClosure = keydownClosure

        textKit1Check = NotificationCenter.default.publisher(for: NSTextView.didSwitchToNSLayoutManagerNotification)
            .sink { value in
                print("receive didSwitchToNSLayoutManagerNotification with \(value)")
            }
        //print("init")
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        //print("makeNSView")
        // scrollview setup
        let scrollView = NSScrollView(frame: rect)
        scrollView.borderType = .lineBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        
        // setup TextlayoutManager
        let textLayoutManager = NSTextLayoutManager()
        textLayoutManager.delegate = textEditorSource
        textLayoutManager.textViewportLayoutController.delegate = textEditorSource

        // setup TextContainer
        let textContainer = NSTextContainer(size: CGSize( width: rect.size.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true // adjust width according to textView
        textContainer.heightTracksTextView = true
        textLayoutManager.textContainer = textContainer

        let textContentStorage = context.coordinator.textContentManager
        //let textContentStorage = NSTextContentStorage()
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContentStorage.delegate = textEditorSource

        // textview
        let textView = MyNSTextView(frame: rect, textContainer: textContainer, keyDown: keyDownClosure)//NSTextView(frame: rect, textContainer: textContainer)
        textView.textStorage?.delegate = textEditorSource
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

        textContentStorage.textStorage?.setAttributedString(NSAttributedString(string: textEditorSource.text))

        // NSTextView のサイズを自動で広げてくれる(TextContainer は広げてくれない)
        // .height は、新しい行が追加された時に TextView が広がるために必要
        textView.autoresizingMask = [.height]
        
        textView.textContainer?.containerSize = CGSize(width: rect.size.width, height: CGFloat.greatestFiniteMagnitude)
        //textView.textContainer?.widthTracksTextView = true
        
        // assemble
        scrollView.documentView = textView
        
        //print("end of init")
        //printSizes(scrollView)
        return scrollView
    }
    
    public func makeCoordinator() -> Coordinator {
        
        return Coordinator(self, self.textContentManager != nil ? self.textContentManager! : NSTextContentStorage())
    }
    
    func printSizes(_ scrollView: NSScrollView) {
        if let textView = scrollView.documentView as? NSTextView {
            print("textView frame: \(textView.frame)")
            if let container = textView.textLayoutManager?.textContainer {
                print("container Size: \(container.size)")
            }
        }

    }
    
    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        //Self.logger.info("before updateNSView")
        //printSizes(scrollView)
        if let textView = scrollView.documentView as? NSTextView {
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
                if textStorage.string != textEditorSource.text {
                    textStorage.beginEditing()
                    textStorage.setAttributedString(NSAttributedString(string: textEditorSource.text))
                    textStorage.endEditing()
                } else {
                    textStorage.beginEditing()
                    textStorage.processEditing()
                    textStorage.endEditing()
                }
                
                if let insertText = self.control?.insertText,
                   let selection = textView.selectedRanges.first as? NSRange {
                    textView.insertText(insertText, replacementRange: selection)
                    self.control?.insertText = nil
                }

            }
            textView.needsDisplay = true
            textView.needsLayout = true
            DispatchQueue.main.async {
                if self.control?.firstResponder == true {
                    textView.window?.makeFirstResponder(textView)
                    self.control?.firstResponder = false
                }
                if let focusRange = self.control?.focusRange {
                    textView.scrollRangeToVisible(focusRange)
                    self.control?.focusRange = nil
                }
            }
        }
        //print("after updateNSView")
        //printSizes(scrollView)
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SDSScrollableTextView
        var textContentManager: MyOwnTextContentManager

        init(_ parent: SDSScrollableTextView,_ textContentManager: MyOwnTextContentManager) {
            self.parent = parent
            self.textContentManager = textContentManager
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.textEditorSource.text = textView.string
        }
        
        public func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
            // iff necessary, need to insert my own menus into passed menu
            return menu
        }
    }
}

open class MyNSTextView: NSTextView {
    let keyDownClosure: keydownClosure?
    
    init(frame: CGRect, textContainer: NSTextContainer, keyDown: keydownClosure? = nil ) {
        self.keyDownClosure = keyDown
        super.init(frame: frame, textContainer: textContainer)
    }
    
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

public struct SDSPushOutScrollableTextView: View {
    var textEditorSource: TextEditorSource
    let control: TextEditorControl?
    let textContentManager: MyOwnTextContentManager?
    let keyDownClosure: keydownClosure?


    public init(_ textEditorSource: TextEditorSource,
                control: TextEditorControl? = nil,
                textContentManager: MyOwnTextContentManager? = nil,
                keydownClosure: keydownClosure? = nil ) {
        self.textEditorSource = textEditorSource
        self.control = control
        self.textContentManager = textContentManager
        self.keyDownClosure = keydownClosure
    }

    public var body: some View {
        GeometryReader { geom in
            SDSScrollableTextView(textEditorSource,
                                  control: control,
                                  rect: geom.frame(in: .local),
                                  textContentManager: textContentManager,
                                  keydownClosure: keyDownClosure)

        }
    }
}
