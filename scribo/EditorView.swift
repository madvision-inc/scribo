//
//  EditorView.swift
//  scribo
//
//  Created by bm on 3/9/25.
//

import SwiftUI

struct EditorView: View {
    @State private var document: ScriboDocument
    @State private var showExitConfirmation = false
    @State private var showSavedConfirmation = false
    @State private var isTyping = false
    @State private var lastSaveTime = Date()
    @State private var typingTimer: Timer?
    @State private var isDarkMode = false
    @State private var showModeChangeAnimation = false
    
    @ObservedObject private var networkManager = NetworkManager()
    
    let onExit: (ScriboDocument) -> Void
    
    init(document: ScriboDocument, onExit: @escaping (ScriboDocument) -> Void) {
        _document = State(initialValue: document)
        self.onExit = onExit
    }
    
    var body: some View {
        ZStack {
            // Background color based on mode
            Rectangle()
                .fill(isDarkMode ? Color.black : Color.white)
                .edgesIgnoringSafeArea(.all)
            
            // Mode change animation overlay
            if showModeChangeAnimation {
                Rectangle()
                    .fill(isDarkMode ? Color.white : Color.black)
                    .edgesIgnoringSafeArea(.all)
                    .opacity(showModeChangeAnimation ? 1 : 0)
                    .transition(.opacity)
            }
            
            // Document title and content
            VStack(spacing: 0) {
                // Enhanced header with document title and buttons
                HStack {
                    Text(document.title)
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white : .gray)
                    
                    Spacer()
                    
                    // Auto-save indicator
                    if showSavedConfirmation && !isTyping {
                        Text("Saved")
                            .foregroundColor(isDarkMode ? .white : .gray)
                            .font(.caption)
                            .padding(.trailing, 10)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.5), value: showSavedConfirmation)
                    }
                    
                    // Dark mode toggle (moved to right side)
                    Button(action: {
                        toggleDarkMode()
                    }) {
                        Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white : .black)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 10)
                    
                    // Exit button with icon
                    Button(action: {
                        // Auto-save and exit immediately
                        saveDocument()
                        networkManager.enableWifi()
                        onExit(document)
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 18))
                            .foregroundColor(isDarkMode ? .white : .black)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 10)
                }
                .padding()
                .background(isDarkMode ? Color.black : Color.white)
                
                // Main text editor with smaller font
                TextEditor(text: $document.content)
                    .font(.system(size: 14))
                    .padding(10) // Removed padding
                    .background(Color(isDarkMode ? .black : .white))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .colorScheme(isDarkMode ? .dark : .light)
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                        // This helps ensure standard keyboard shortcuts like Cmd+A work properly
                        NSApp.windows.first?.makeFirstResponder(nil)
                    }
                    .onChange(of: document.content) { _ in
                        // Start typing state
                        isTyping = true
                        
                        // Reset the timer when user types
                        typingTimer?.invalidate()
                        
                        // Create a new timer that will trigger after 2 seconds of inactivity
                        typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                            // User stopped typing
                            isTyping = false
                            saveDocument()
                        }
                    }
            }
                
            // Simple exit confirmation dialog
            if showExitConfirmation {
                ZStack {
                    Color(isDarkMode ? .black : .white).opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        Text("Save before exiting?")
                            .font(.headline)
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        HStack(spacing: 20) {
                            Button("Don't Save") {
                                networkManager.enableWifi()
                                onExit(document)
                            }
                            .padding(.horizontal)
                            
                            Button("Cancel") {
                                showExitConfirmation = false
                            }
                            .padding(.horizontal)
                            
                            Button("Save") {
                                saveDocument()
                                networkManager.enableWifi()
                                onExit(document)
                            }
                            .padding(.horizontal)
                            .buttonStyle(DefaultButtonStyle())
                        }
                    }
                    .padding(30)
                    .background(isDarkMode ? Color.gray.opacity(0.8) : Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
            }
        }
        .background(isDarkMode ? Color.black : Color.white)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            // Enter full screen and disable WiFi
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.windows.first?.toggleFullScreen(nil)
                networkManager.disableWifi()
            }
            setupKeyboardShortcuts()
        }
        .onDisappear {
            // Clean up timer when view disappears
            typingTimer?.invalidate()
        }
    }
    
    func toggleDarkMode() {
        // Show flash animation
        withAnimation(.easeInOut(duration: 0.1)) {
            showModeChangeAnimation = true
        }
        
        // After a brief delay, switch the mode and hide animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isDarkMode.toggle()
            withAnimation(.easeInOut(duration: 0.3)) {
                showModeChangeAnimation = false
            }
        }
    }
    
    func saveDocument() {
        lastSaveTime = Date()
        document.modifiedAt = Date()
        
        // Show saved confirmation briefly with animation
        withAnimation {
            showSavedConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSavedConfirmation = false
            }
        }
    }
    
    func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Catch escape key and CMD+Q for exit confirmation
            if event.keyCode == 53 || (event.modifierFlags.contains(.command) && event.keyCode == 12) {
                showExitConfirmation = true
                return nil
            }
            
            // Auto-save shortcut (Command+S)
            if event.modifierFlags.contains(.command) && event.keyCode == 1 {
                saveDocument()
                return nil
            }
            
            // Dark mode toggle (Command+D)
            if event.modifierFlags.contains(.command) && event.keyCode == 2 {
                toggleDarkMode()
                return nil
            }
            
            return event
        }
    }
}

// Create a UIViewRepresentable that gives direct access to the NSTextView
struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isDarkMode: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.drawsBackground = true
        textView.backgroundColor = isDarkMode ? .black : .white
        textView.textColor = isDarkMode ? .white : .black
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.isEditable = true
        textView.isSelectable = true
        textView.delegate = context.coordinator
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        textView.backgroundColor = isDarkMode ? .black : .white
        textView.textColor = isDarkMode ? .white : .black
        
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
