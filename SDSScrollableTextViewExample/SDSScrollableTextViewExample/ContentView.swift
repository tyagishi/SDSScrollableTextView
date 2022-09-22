//
//  ContentView.swift
//
//  Created by : Tomoaki Yagishita on 2022/01/24
//  © 2022  SmallDeskSoftware
//

import SwiftUI
import SDSScrollableTextView
import SwiftUIDebugUtil

class TextContainer: NSObject, ObservableObject, TextEditorSource {
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
                SDSScrollableTextView(text, rect: geom.frame(in: .local),
                                      textContentStorageDelegate: nil, textStorageDelegate: nil,
                                      textLayoutManagerDelegate: nil, textViewportLayoutControllerDelegate: nil,
                                      control: nil, textContentManager: nil, keydownClosure: nil)
            }
            SDSPushOutScrollableTextView(text, control: control)
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
