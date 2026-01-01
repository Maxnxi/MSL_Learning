//
//  ContentView.swift
//  MSL_Learning
//
//  Created by Maksim Ponomarev on 1/1/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
			
			TriangleView()
			
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
