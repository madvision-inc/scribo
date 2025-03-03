//
//  scriboApp.swift
//  scribo
//
//  Created by bm on 3/3/25.
//

import SwiftUI
import Network

// Main application
@main
struct scriboApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .background(Color.white)
                .onAppear {
                    NSApplication.shared.windows.first?.toggleFullScreen(nil)
                }
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

// Password authentication for exiting
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var passwords = ["", "", ""]
    @Published var passwordIndex = 0
    
    // These would be securely stored and hashed in a real app
    let correctPasswords = ["focus", "create", "freedom"]
    
    func checkPassword() -> Bool {
        if passwords[passwordIndex] == correctPasswords[passwordIndex] {
            passwordIndex += 1
            if passwordIndex >= 3 {
                isAuthenticated = true
                return true
            }
            return false
        } else {
            passwords[passwordIndex] = ""
            return false
        }
    }
    
    func reset() {
        passwordIndex = 0
        passwords = ["", "", ""]
        isAuthenticated = false
    }
}
