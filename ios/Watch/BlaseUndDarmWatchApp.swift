//
//  BlaseUndDarmWatchApp.swift
//  Blase & Darm — Watch
//
//  Einstiegspunkt der watchOS-App. Bewusst minimal:
//  keine eigene Info.plist (wird von Xcode generiert),
//  keine Extension-Konstruktion — moderne Single-Target-Watch-App.
//

import SwiftUI

@main
struct BlaseUndDarmWatchApp: App {
    @StateObject private var session = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}
