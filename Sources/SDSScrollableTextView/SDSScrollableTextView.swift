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

public class TextEditorControl: NSObject, ObservableObject {
    public var textView: NSTextView? = nil
//    public var firstResponder: Bool = false
    public var focusRange: NSRange? = nil
//    @Published public var selectionRange: NSRange? = nil
//    @Published public var insertText: String? = nil
//    @Published public var insertRange: NSRange? = nil
//    @Published public var cursors: NSRange? = nil
//    var textContentManager: NSTextContentManager
//    public init(_ contentManager: NSTextContentManager) {
//        textContentManager = contentManager
//    }
//    public init() {}


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

    let textContentManager: MyOwnTextContentManager?
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
                print("receive willSwitchToNSLayoutManagerNotification with \(value)")
                print("============ switched to TextKit1 ============")
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
        if let textStorage = textView.textStorage,
           textStorage.string != text {
            textStorage.beginEditing()
            textStorage.setAttributedString(NSAttributedString(string: text))
            textStorage.endEditing()
            textView.needsDisplay = true
            textView.needsLayout = true
        }

        //            if self.control?.firstResponder == true {
        //                textView.window?.makeFirstResponder(textView)
        //                self.control?.firstResponder = false
        //            }
        if let focusRange = control?.focusRange {
            //                print("scroll to \(focusRange)")
            textView.scrollRangeToVisible(focusRange)
            //                self.control?.focusRange = nil
        }
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SDSScrollableTextView

        init(_ parent: SDSScrollableTextView) {
            self.parent = parent
        }

//        public func textViewDidChangeSelection(_ notification: Notification) {
//            guard let textView = notification.object as? NSTextView else { return }
//            if let control = control,
//               let range = textView.selectedRanges.first as? NSRange {
//                control.selectionRange = range
//                print("set range with \(control.selectionRange) to \(control)")
//            }
//        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
        
        public func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
            // iff necessary, need to insert my own menus into passed menu
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
//        self.wantsLayer = true
//        layer?.backgroundColor = .white
//        self.contentLayer = TextDocumentLayer()
//        self.selectionLayer = TextDocumentLayer()
//        layer?.addSublayer(contentLayer)
//        layer?.addSublayer(selectionLayer)
        //translatesAutoresizingMaskIntoConstraints = false
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

//extension MyNSTextView: CALayerDelegate , NSTextViewportLayoutControllerDelegate {
//    public func viewportBounds(for textViewportLayoutController: NSTextViewportLayoutController) -> CGRect {
//        print(#function)
//        return bounds
//        // TODO: too unstable
////        let overdrawRect = preparedContentRect
////        let visibleRect = self.visibleRect
////        var minY: CGFloat = 0
////        var maxY: CGFloat = 0
////        if overdrawRect.intersects(visibleRect) {
////            // Use preparedContentRect for vertical overdraw and ensure visibleRect is included at the minimum,
////            // the width is always bounds width for proper line wrapping.
////            minY = min(overdrawRect.minY, max(visibleRect.minY, 0))
////            maxY = max(overdrawRect.maxY, visibleRect.maxY)
////        } else {
////            // We use visible rect directly if preparedContentRect does not intersect.
////            // This can happen if overdraw has not caught up with scrolling yet, such as before the first layout.
////            minY = visibleRect.minY
////            maxY = visibleRect.maxY
////        }
////        return CGRect(x: bounds.minX, y: minY, width: bounds.width, height: maxY - minY)
//    }
//
//    public func textViewportLayoutControllerWillLayout(_ controller: NSTextViewportLayoutController) {
////        print(#function)
////        contentLayer.sublayers = nil
////        CATransaction.begin()
//    }
//
//    public func textViewportLayoutControllerDidLayout(_ controller: NSTextViewportLayoutController) {
////        print(#function)
////        CATransaction.commit()
//        updateSelectionHighlights()
//        updateContentSizeIfNeeded()
//        //adjustViewportOffsetIfNeeded()
//    }
//
//    private func findOrCreateLayer(_ textLayoutFragment: NSTextLayoutFragment) -> (TextLayoutFragmentLayer, Bool) {
//        if let layer = fragmentLayerMap.object(forKey: textLayoutFragment) as? TextLayoutFragmentLayer {
//            return (layer, false)
//        } else {
//            let layer = TextLayoutFragmentLayer(layoutFragment: textLayoutFragment, padding: 5.0)
//            fragmentLayerMap.setObject(layer, forKey: textLayoutFragment)
//            return (layer, true)
//        }
//    }
//
//    public func textViewportLayoutController(_ controller: NSTextViewportLayoutController,
//                                      configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment) {
////        let (layer, layerIsNew) = findOrCreateLayer(textLayoutFragment)
//////        layer.showLayerFrames = true
////        if !layerIsNew {
////            let oldPosition = layer.position
////            let oldBounds = layer.bounds
////            layer.updateGeometry()
////            if oldBounds != layer.bounds {
////                layer.setNeedsDisplay()
////            }
////            if oldPosition != layer.position {
////                animate(layer, from: oldPosition, to: layer.position)
////            }
////        }
//        let layer = TextLayoutFragmentLayer(layoutFragment: textLayoutFragment, padding: 0.0)
//        layer.setNeedsDisplay()
//        contentLayer.addSublayer(layer)
//    }
//
//    private func animate(_ layer: CALayer, from source: CGPoint, to destination: CGPoint) {
////        let animation = CABasicAnimation(keyPath: "position")
////        animation.fromValue = source
////        animation.toValue = destination
////        animation.duration = 0.0001
////        layer.add(animation, forKey: nil)
//    }
//
//    var selectionColor: NSColor { return NSColor.red }//selectedTextBackgroundColor.withAlphaComponent(0.2) }
//    var caretColor: NSColor { return .black }
//
//
//    private func updateSelectionHighlights() {
//        if !textLayoutManager!.textSelections.isEmpty {
//            print("selection is NOT empty")
//            selectionLayer.sublayers = nil
//            for textSelection in textLayoutManager!.textSelections {
//                for textRange in textSelection.textRanges {
//                    textLayoutManager!.enumerateTextSegments(in: textRange,
//                                                             type: .highlight,
//                                                             options: []) {(textSegmentRange, textSegmentFrame, baselinePosition, textContainer) in
//                        var highlightFrame = textSegmentFrame
//                        //highlightFrame.origin.x += padding
//                        let highlight = TextDocumentLayer()
//                        if highlightFrame.size.width > 0 {
//                            highlight.backgroundColor = selectionColor.cgColor
//                        } else {
//                            highlightFrame.size.width = 1 // Fatten up the cursor.
//                            highlight.backgroundColor = caretColor.cgColor
//                        }
//                        highlight.frame = highlightFrame
////                        selectionLayer.addSublayer(highlight)
//                        return true // Keep going.
//                    }
//                }
//            }
//        }
//    }
//    func updateContentSizeIfNeeded() {
//        let currentHeight = bounds.height
//        var height: CGFloat = 0
//        textLayoutManager!.enumerateTextLayoutFragments(from: textLayoutManager!.documentRange.endLocation,
//                                                        options: [.reverse, .ensuresLayout]) { layoutFragment in
//            height = layoutFragment.layoutFragmentFrame.maxY
//            return false // stop, use lastsegment's maxY
//        }
//        height = max(height, enclosingScrollView?.contentSize.height ?? 0)
//        if abs(currentHeight - height) > 1e-10 {
//            let contentSize = NSSize(width: self.bounds.width, height: height)
//            setFrameSize(contentSize)
//        }
//    }
//
//    private var scrollView: NSScrollView? {
//        guard let result = enclosingScrollView else { return nil }
//        if result.documentView == self {
//            return result
//        } else {
//            return nil
//        }
//    }
//
//    private func adjustViewportOffsetIfNeeded() {
//        let viewportLayoutController = textLayoutManager!.textViewportLayoutController
//        let contentOffset = scrollView!.contentView.bounds.minY
//        if contentOffset < scrollView!.contentView.bounds.height &&
//            viewportLayoutController.viewportRange!.location.compare(textLayoutManager!.documentRange.location) == .orderedDescending {
//            // Nearing top, see if we need to adjust and make room above.
//            adjustViewportOffset()
//        } else if viewportLayoutController.viewportRange!.location.compare(textLayoutManager!.documentRange.location) == .orderedSame {
//            // At top, see if we need to adjust and reduce space above.
//            adjustViewportOffset()
//        }
//    }
//
//    private func adjustViewportOffset() {
//        let viewportLayoutController = textLayoutManager!.textViewportLayoutController
//        var layoutYPoint: CGFloat = 0
//        textLayoutManager!.enumerateTextLayoutFragments(from: viewportLayoutController.viewportRange!.location,
//                                                        options: [.reverse, .ensuresLayout]) { layoutFragment in
//            layoutYPoint = layoutFragment.layoutFragmentFrame.origin.y
//            return true
//        }
//        if layoutYPoint != 0 {
//            let adjustmentDelta = bounds.minY - layoutYPoint
//            viewportLayoutController.adjustViewport(byVerticalOffset: adjustmentDelta)
//            scroll(CGPoint(x: scrollView!.contentView.bounds.minX, y: scrollView!.contentView.bounds.minY + adjustmentDelta))
//        }
//    }
//
//    open override func setFrameSize(_ newSize: NSSize) {
//        //print(#function)
//        super.setFrameSize(newSize)
//        updateTextContainerSize()
//    }
//
//    private func updateTextContainerSize() {
//        //print(#function)
//        let textContainer = textLayoutManager!.textContainer
//        if textContainer != nil && textContainer!.size.width != bounds.width {
//            textContainer!.size = NSSize(width: bounds.size.width, height: 0)
//            layer?.setNeedsLayout()
//        }
//    }
//
////    open override func mouseDown(with event: NSEvent) {
////        print(#function)
////        var point = convert(event.locationInWindow, from: nil)
////        //point.x -= padding
////        let nav = textLayoutManager!.textSelectionNavigation
////
////        textLayoutManager!.textSelections = nav.textSelections(interactingAt: point,
////                                                               inContainerAt: textLayoutManager!.documentRange.location,
////                                                               anchors: [],
////                                                               modifiers: [],
////                                                               selecting: true,
////                                                               bounds: .zero)
////        layer?.setNeedsLayout()
////    }
////
////    open override func mouseDragged(with event: NSEvent) {
////        print(#function)
////        var point = convert(event.locationInWindow, from: nil)
////        //point.x -= padding
////        let nav = textLayoutManager!.textSelectionNavigation
////
////        textLayoutManager!.textSelections = nav.textSelections(interactingAt: point,
////                                                               inContainerAt: textLayoutManager!.documentRange.location,
////                                                               anchors: textLayoutManager!.textSelections,
////                                                               modifiers: .extend,
////                                                               selecting: true,
////                                                               bounds: .zero)
////        layer?.setNeedsLayout()
////    }
////
//}



// MARK: CALayer
class TextDocumentLayer: CALayer {
    override class func defaultAction(forKey event: String) -> CAAction? {
        // Suppress default animation of opacity when adding comment bubbles.
        return NSNull()
    }
}

class TextLayoutFragmentLayer: CALayer {
    var layoutFragment: NSTextLayoutFragment!
    var padding: CGFloat
    var showLayerFrames: Bool
    
    let strokeWidth: CGFloat = 2
    
    override class func defaultAction(forKey: String) -> CAAction? {
        // Suppress default opacity animations.
        return NSNull()
    }

    func updateGeometry() {
        bounds = layoutFragment.renderingSurfaceBounds
        if showLayerFrames {
            var typographicBounds = layoutFragment.layoutFragmentFrame
            typographicBounds.origin = .zero
            bounds = bounds.union(typographicBounds)
        }
        // The (0, 0) point in layer space should be the anchor point.
        anchorPoint = CGPoint(x: -bounds.origin.x / bounds.size.width, y: -bounds.origin.y / bounds.size.height)
        position = layoutFragment.layoutFragmentFrame.origin
        //position.x += padding
    }
    
    init(layoutFragment: NSTextLayoutFragment, padding: CGFloat) {
        self.layoutFragment = layoutFragment
        self.padding = padding
        showLayerFrames = true
        super.init()
        contentsScale = 2
        updateGeometry()
        setNeedsDisplay()
    }

    // MARK: looks NOT used
    override init(layer: Any) {
        let tlfLayer = layer as! TextLayoutFragmentLayer
        layoutFragment = tlfLayer.layoutFragment
        padding = tlfLayer.padding
        showLayerFrames = tlfLayer.showLayerFrames
        super.init(layer: layer)
        updateGeometry()
        setNeedsDisplay()
    }
    
    required init?(coder: NSCoder) {
        layoutFragment = nil
        padding = 0
        showLayerFrames = true
        super.init(coder: coder)
    }
    
    override func draw(in ctx: CGContext) {
        layoutFragment.draw(at: .zero, in: ctx)
        if showLayerFrames && false {
            let inset = 0.5 * strokeWidth
            // Draw rendering surface bounds.
            ctx.setLineWidth(strokeWidth)
            ctx.setStrokeColor(NSColor.systemOrange.cgColor)
            ctx.setLineDash(phase: 0, lengths: []) // Solid line.
            ctx.stroke(layoutFragment.renderingSurfaceBounds.insetBy(dx: inset, dy: inset))
            
            // Draw typographic bounds.
            ctx.setStrokeColor(NSColor.systemPurple.cgColor)
            ctx.setLineDash(phase: 0, lengths: [strokeWidth, strokeWidth]) // Square dashes.
            var typographicBounds = layoutFragment.layoutFragmentFrame
            typographicBounds.origin = .zero
            ctx.stroke(typographicBounds.insetBy(dx: inset, dy: inset))
        }
    }
}
