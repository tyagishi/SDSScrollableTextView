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

public class TextEditorControl: ObservableObject {
    @Published public var firstResponder: Bool = false
    @Published public var focusRange: NSRange? = nil
    @Published public var insertText: String? = nil
    public init() {}
}
public typealias keydownClosure = (NSTextView, NSEvent) -> Bool

public struct SDSPushOutScrollableTextView: View {
    @Binding var text: String
    let control: TextEditorControl?
    let textContentStorageDelegate: NSTextContentStorageDelegate?
    let textStorageDelegate: NSTextStorageDelegate?
    let textLayoutManagerDelegate: NSTextLayoutManagerDelegate?
    let keyDownClosure: keydownClosure?


    public init(text: Binding<String>,
                control: TextEditorControl? = nil,
                textContentStorageDelegate: NSTextContentStorageDelegate? = nil,
                textStorageDelegate: NSTextStorageDelegate? = nil, textLayoutManagerDelegate: NSTextLayoutManagerDelegate? = nil,
                keydownClosure: keydownClosure? = nil ) {
        self._text = text
        self.control = control
        self.textContentStorageDelegate = textContentStorageDelegate
        self.textStorageDelegate = textStorageDelegate
        self.textLayoutManagerDelegate = textLayoutManagerDelegate
        self.keyDownClosure = keydownClosure
    }

    public var body: some View {
        GeometryReader { geom in
            SDSScrollableTextView(text: $text,
                                  control: control,
                                  rect: geom.frame(in: .local),
                                  textContentStorageDelegate: textContentStorageDelegate,
                                  textStorageDelegate: textStorageDelegate,
                                  textLayoutManagerDelegate: textLayoutManagerDelegate,
                                  keydownClosure: keyDownClosure)

        }
    }
}

public struct SDSScrollableTextView: NSViewRepresentable {
    public typealias NSViewType = NSScrollView
    
    @Binding var text: String
    var control: TextEditorControl?
    let rect: CGRect
    
    let textContentStorageDelegate: NSTextContentStorageDelegate?
    let textStorageDelegate: NSTextStorageDelegate?
    let textLayoutManagerDelegate: NSTextLayoutManagerDelegate?
    var textKit1Check: AnyCancellable? = nil
    let keyDownClosure: keydownClosure?

    public init(text: Binding<String>,
                control: TextEditorControl? = nil,
                rect: CGRect, textContentStorageDelegate: NSTextContentStorageDelegate? = nil,
                textStorageDelegate: NSTextStorageDelegate? = nil, textLayoutManagerDelegate: NSTextLayoutManagerDelegate? = nil,
                keydownClosure: keydownClosure? = nil ) {
        self._text = text
        self.control = control
        self.rect = rect
        self.textContentStorageDelegate = textContentStorageDelegate
        self.textStorageDelegate = textStorageDelegate
        self.textLayoutManagerDelegate = textLayoutManagerDelegate
        self.keyDownClosure = keydownClosure

        textKit1Check = NotificationCenter.default.publisher(for: NSTextView.didSwitchToNSLayoutManagerNotification)
            .sink { value in
                print("receive didSwitchToNSLayoutManagerNotification with \(value)")
            }
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        // scrollview setup
        let scrollView = NSScrollView(frame: rect)
        scrollView.borderType = .lineBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        
        // setup TextlayoutManager
        let textLayoutManager = NSTextLayoutManager()
        textLayoutManager.delegate = textLayoutManagerDelegate

        // setup TextContainer
        let textContainer = NSTextContainer(size: CGSize( width: rect.size.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true // adjust width according to textView
        textContainer.heightTracksTextView = true
        textLayoutManager.textContainer = textContainer

        let textContentStorage = NSTextContentStorage()
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContentStorage.delegate = textContentStorageDelegate

        // textview
        let textView = MyNSTextView(frame: rect, textContainer: textContainer, keyDown: keyDownClosure)//NSTextView(frame: rect, textContainer: textContainer)
        textView.textStorage?.delegate = textStorageDelegate
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
        
        textView.textContainer?.containerSize = CGSize(width: rect.size.width, height: CGFloat.greatestFiniteMagnitude)
        //textView.textContainer?.widthTracksTextView = true
        
        // assemble
        scrollView.documentView = textView
        
        //print("end of init")
        //printSizes(scrollView)
        return scrollView
    }
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(self)
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
        //print("before updateNSView")
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
                if textStorage.string != text {
                    textStorage.beginEditing()
                    textStorage.setAttributedString(NSAttributedString(string: text))
                    textStorage.endEditing()
                }
                
                if let insertText = self.control?.insertText,
                   let selection = textView.selectedRanges.first as? NSRange {
                    textView.insertText(insertText, replacementRange: selection)
                    self.control?.insertText = nil
                }

            }
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
        init(_ parent: SDSScrollableTextView) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
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

