//
//  scriboApp.swift
//  scribo
//
//  Created by bm on 3/3/25.
//

import SwiftUI
import Network

// Network manager to handle WiFi disconnection
class NetworkManager: ObservableObject {
    @Published var isWifiDisabled = false
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    func disableWifi() {
        let process = Process()
        process.launchPath = "/usr/sbin/networksetup"
        process.arguments = ["-setairportpower", "en0", "off"]
        try? process.run()
        isWifiDisabled = true
    }
    
    func enableWifi() {
        let process = Process()
        process.launchPath = "/usr/sbin/networksetup"
        process.arguments = ["-setairportpower", "en0", "on"]
        try? process.run()
        isWifiDisabled = false
    }
}

// Main application
@main
struct scriboApp: App {
    @StateObject private var documentManager = DocumentManager()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(documentManager)
                .frame(minWidth: 800, minHeight: 600)
                .background(Color.white)
                .preferredColorScheme(.light)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            // Remove standard menu items
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .textEditing) {}
            CommandGroup(replacing: .windowList) {}
            CommandGroup(replacing: .help) {}
        }
    }
}

