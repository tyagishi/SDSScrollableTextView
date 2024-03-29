//
//  ContentView.swift
//
//  Created by : Tomoaki Yagishita on 2022/01/24
//  © 2022  SmallDeskSoftware
//

import SwiftUI
import Combine
import SDSScrollableTextView
import SwiftUIDebugUtil

class TextContainer: NSObject, ObservableObject {
    @Published var text: String = ""
    @Published var text2: String = """
Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello Hello
Hello1
Hello2
Hello3
Hello4
Hello5
Hello6
Hello7Helllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllloooooooooooooooooooooo
Hello8
Hello9
Hello0
Hello1
Hello2
Hello3
Hello4
Hello5
Hello6
Hello7
Hello8
Hello9
Hello0
Hello1
Hello2
Hello3
Hello4
Hello5
Hello6
Hello7
Hello8
Hello9
Hello0
Hello1
Hello2
Hello3
Hello4
world
"""
}

extension TextContainer: TextViewSource {
    func updateText(_ str: String) {
        self.text = str
    }
}

//extension EditorControlKey: FocusedValueKey {
//    typealias Value = TextEditorControl
//}


struct ContentView: View {
    @StateObject var textContainer = TextContainer()

    var body: some View {
        VStack {
            GroupBox("SDSScrollableTextView") {
                GeometryReader { geom in
                    SDSScrollableTextView(textContainer,
                                          rect: geom.frame(in: .local),//  size,  //CGRect(x: 0, y: 0, width: 200, height: 200),
                                          textContentStorageDelegate: nil, textStorageDelegate: nil,
                                          textLayoutManagerDelegate: nil, textViewportLayoutControllerDelegate: nil,
                                          textContentManager: nil,
                                          coordinatorProducer: coordinatorProducer,
                                          keydownClosure: nil,
                                          updateTextView: updateTextView,
                                          accessibilityIdentifier: "SDSScrollableTextEditor")
                }
                //SDSPushOutScrollableTextView($text.text, control: control)
            }
            .frame(width: 250)
            GroupBox("Text content with TextEditor") {
                TextEditor(text: $textContainer.text)
                    .accessibilityIdentifier("TextEditor")
                    .accessibilityLabel("MyTextEditor")
            }
        }
        .debugBorder(.red)
        .frame(maxHeight: 5000)
        .frame(maxWidth: 5000)
            .padding()
    }

    func coordinatorProducer<TextContainer>(_ scrollableTextView: SDSScrollableTextView<TextContainer>) -> NSUITextViewBaseCoordinator<TextContainer>{
        return NSUITextViewBaseCoordinator(scrollableTextView)
    }

    func updateTextView<TextContainer>(_ textView: NSUITextView,_ container: TextContainer,_ coordinator: NSUITextViewBaseCoordinator<TextContainer>?) -> Void {
        Task {
            textView.string = await container.text
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
