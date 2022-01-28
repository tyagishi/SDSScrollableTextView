//
//  ContentView.swift
//
//  Created by : Tomoaki Yagishita on 2022/01/24
//  © 2022  SmallDeskSoftware
//

import SwiftUI
import SDSScrollableTextView
import SwiftUIDebugUtil

struct ContentView: View {
    @State private var text = """
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
//    let delegate = TextViewDelegate()
    @State private var control = TextEditorControl()

    var body: some View {
        VStack {
//            GeometryReader { geom in
//                SDSTextView(text: $text,
//                            control: control,
//                            rect: geom.frame(in: .local),
//                            textContentStorageDelegate: delegate,
//                            textStorageDelegate: delegate,
//                            textLayoutManagerDelegate: delegate)
//            }
//            GeometryReader { geom in
//                SDSScrollableTextView(text: $text,
//                                      rect: geom.frame(in: .local))
//            }
            SDSPushOutScrollableTextView(text: $text,
                                         control: control,
                                         textContentStorageDelegate: nil,
                                         textStorageDelegate: nil,
                                         textLayoutManagerDelegate: nil)
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
