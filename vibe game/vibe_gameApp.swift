//
//  vibe_gameApp.swift
//  vibe game
//
//  Created by jason stoops on 8/2/26.
//

import SwiftUI

@main
struct vibe_gameApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 1440, height: 900)
        .windowResizability(.contentSize)
        #endif
    }
}
