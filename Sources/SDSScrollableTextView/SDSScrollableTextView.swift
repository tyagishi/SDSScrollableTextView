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
    public init() {}
}
public struct SDSPushOutScrollableTextView: View {
    @Binding var text: String
    let control: TextEditorControl
    let textContentStorageDelegate: NSTextContentStorageDelegate?
    let textStorageDelegate: NSTextStorageDelegate?
    let textLayoutManagerDelegate: NSTextLayoutManagerDelegate?
    
    public init(text: Binding<String>,
                control: TextEditorControl,
                textContentStorageDelegate: NSTextContentStorageDelegate? = nil,
                textStorageDelegate: NSTextStorageDelegate? = nil, textLayoutManagerDelegate: NSTextLayoutManagerDelegate? = nil ) {
        self._text = text
        self.control = control
        self.textContentStorageDelegate = textContentStorageDelegate
        self.textStorageDelegate = textStorageDelegate
        self.textLayoutManagerDelegate = textLayoutManagerDelegate
    }

    public var body: some View {
        GeometryReader { geom in
            SDSScrollableTextView(text: $text,
                                  control: control,
                                  rect: geom.frame(in: .local),
                                  textContentStorageDelegate: textContentStorageDelegate,
                                  textStorageDelegate: textStorageDelegate,
                                  textLayoutManagerDelegate: textLayoutManagerDelegate)

        }
    }
}

public struct SDSScrollableTextView: NSViewRepresentable {
    public typealias NSViewType = NSScrollView
    
    @Binding var text: String
    @ObservedObject var control: TextEditorControl
    let rect: CGRect
    
    let textContentStorageDelegate: NSTextContentStorageDelegate?
    let textStorageDelegate: NSTextStorageDelegate?
    let textLayoutManagerDelegate: NSTextLayoutManagerDelegate?
    var textKit1Check: AnyCancellable? = nil

    public init(text: Binding<String>,
                control: TextEditorControl,
                rect: CGRect, textContentStorageDelegate: NSTextContentStorageDelegate? = nil,
                textStorageDelegate: NSTextStorageDelegate? = nil, textLayoutManagerDelegate: NSTextLayoutManagerDelegate? = nil ) {
        self._text = text
        self.control = control
        self.rect = rect
        self.textContentStorageDelegate = textContentStorageDelegate
        self.textStorageDelegate = textStorageDelegate
        self.textLayoutManagerDelegate = textLayoutManagerDelegate

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
        let textView = NSTextView(frame: rect, textContainer: textContainer)
        textView.textStorage?.delegate = textStorageDelegate
        textView.delegate = context.coordinator
        textView.isEditable = true
        
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
//            if let textStorage = textView.textStorage {
//            }
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
            if let textStorage = textView.textStorage,
               textStorage.string != text {
                textStorage.setAttributedString(NSAttributedString(string: text))
            }
            DispatchQueue.main.async {
                if self.control.firstResponder == true {
                    textView.window?.makeFirstResponder(textView)
                    self.control.firstResponder = false
                }
                if let focusRange = self.control.focusRange {
                    textView.scrollRangeToVisible(focusRange)
                    self.control.focusRange = nil
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
    }
    
    
}

