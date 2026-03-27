//
//  SnapStateApp.swift
//  SnapState
//
//  Created by Arush Wadhawan on 3/27/26.
//

import SwiftUI

@main
struct SnapStateApp: App {
    @State private var store = WorkspaceStore()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("SnapState", systemImage: "rectangle.3.group.bubble") {
            MenuBarContentView()
                .environment(store)
                .frame(width: 380)
        }
        .menuBarExtraStyle(.window)

        Window("SnapState", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 980, minHeight: 700)
        }
        .windowResizability(.contentSize)
    }
}
