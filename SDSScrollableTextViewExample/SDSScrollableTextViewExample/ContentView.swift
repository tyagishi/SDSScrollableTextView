//
//  ContentView.swift
//
//  Created by : Tomoaki Yagishita on 2022/01/24
//  © 2022  SmallDeskSoftware
//

import SwiftUI
import SDSScrollableTextView
import SwiftUIDebugUtil

class TextContainer: NSObject, ObservableObject {
    @Published var text: String = """
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

struct ContentView: View {
    @StateObject var text = TextContainer()
    @State private var control = TextEditorControl()

    var body: some View {
        VStack {
            GeometryReader { geom in
                SDSScrollableTextView($text.text,
                                      rect: CGRect(x: 0, y: 0, width: 200, height: 200),
                                      textContentStorageDelegate: nil, textStorageDelegate: nil,
                                      textLayoutManagerDelegate: nil, textViewportLayoutControllerDelegate: nil,
                                      control: control, textContentManager: nil, keydownClosure: nil)
            }
            SDSPushOutScrollableTextView($text.text, control: control)
            TextEditor(text: $text.text)
            Button(action: {
                text.text += "a"
            }, label: {
                Text("Add")
            })
        }
        .debugBorder(.red)
        .frame(maxHeight: 5000)
        .frame(maxWidth: 5000)
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
