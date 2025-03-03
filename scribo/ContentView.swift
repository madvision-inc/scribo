//
//  ContentView.swift
//  scribo
//
//  Created by bm on 3/3/25.
//

import SwiftUI

// Main view
struct ContentView: View {
    @State private var text = ""
    @State private var showEscapeDialog = false
    @State private var showPasswordPrompt = false
    @ObservedObject private var networkManager = NetworkManager()
    @ObservedObject private var authManager = AuthenticationManager()
    
    var body: some View {
        ZStack {
            // Main writing area
            TextEditor(text: $text)
                .font(.system(size: 18))
                .padding()
                .background(Color.white)
                .onAppear {
                    networkManager.disableWifi()
                }
                .onDisappear {
                    if authManager.isAuthenticated {
                        networkManager.enableWifi()
                    }
                }
            
            // Escape dialog
            if showEscapeDialog {
                VStack {
                    Text("Enter passwords to exit Scribo")
                        .font(.headline)
                        .padding()
                    
                    Text("Password \(authManager.passwordIndex + 1) of 3")
                        .padding(.bottom)
                    
                    SecureField("Enter password", text: $authManager.passwords[authManager.passwordIndex])
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .frame(width: 300)
                    
                    HStack {
                        Button("Cancel") {
                            showEscapeDialog = false
                        }
                        .padding()
                        
                        Button("Submit") {
                            if authManager.checkPassword() {
                                if authManager.isAuthenticated {
                                    showEscapeDialog = false
                                    networkManager.enableWifi()
                                    NSApplication.shared.terminate(self)
                                }
                            }
                        }
                        .padding()
                    }
                }
                .frame(width: 400, height: 250)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 10)
            }
        }
        .background(Color.white)
        .edgesIgnoringSafeArea(.all)
        .onAppear(perform: setupKeyboardShortcuts)
    }
    
    func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Catch escape key and CMD+Q to prevent normal exit
            if event.keyCode == 53 || (event.modifierFlags.contains(.command) && event.keyCode == 12) {
                showEscapeDialog = true
                return nil
            }
            return event
        }
    }
}

// New document view
struct NewDocumentView: View {
    @State private var documentTitle = ""
    @Binding var startWriting: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Scribo")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.black)
            
            Text("Distraction-free writing")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(.gray)
            
            TextField("Document title (optional)", text: $documentTitle)
                .font(.system(size: 18))
                .textFieldStyle(PlainTextFieldStyle())
                .frame(width: 400)
                .padding()
                .background(Color(white: 0.98))
                .cornerRadius(8)
            
            Button("Start Writing") {
                startWriting = true
            }
            .font(.system(size: 18, weight: .medium))
            .padding()
            .frame(width: 200)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

#Preview {
    ContentView()
}
