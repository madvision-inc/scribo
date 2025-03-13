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
        
        // Load the saved dark mode preference
        _isDarkMode = State(initialValue: UserDefaults.standard.bool(forKey: "ScriboDarkModeEnabled"))
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
                
                // Using our custom text editor instead of SwiftUI's TextEditor
                CustomTextEditor(text: $document.content, isDarkMode: isDarkMode, onTextChange: { _ in
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
                })
                .background(isDarkMode ? Color.black : Color.white)
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
                    .background(isDarkMode ? Color.black : Color.white)
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
            
            // Save the dark mode preference
            UserDefaults.standard.set(isDarkMode, forKey: "ScriboDarkModeEnabled")
            
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
            
            // Let standard keyboard shortcuts like Command+C, Command+V, Command+A pass through
            // by not intercepting them here, so they're handled by the NSTextView responder chain
            
            return event
        }
    }
}

// Completely custom NSViewRepresentable text editor with precise control over styling
struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isDarkMode: Bool
    var onTextChange: ((String) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        configureTextView(textView)
        textView.delegate = context.coordinator
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Only update the string if it's different to avoid cursor jumping
        if textView.string != text {
            textView.string = text
        }
        
        // Always update appearance properties
        configureTextView(textView)
    }
    
    private func configureTextView(_ textView: NSTextView) {
        // Basic configuration
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 14)
        
        // Critical: Ensure we use the exact same color as header
        textView.drawsBackground = true
        textView.backgroundColor = isDarkMode ? .black : .white
        textView.textColor = isDarkMode ? .white : .black
        
        // Disable system appearance adaptations that might override our colors
        textView.usesAdaptiveColorMappingForDarkAppearance = false
        
        // Remove any system-provided background insets or styling
        textView.textContainerInset = NSSize(width: 10, height: 10)
        
        // Explicitly disable any fancy text effects
        textView.isAutomaticTextReplacementEnabled = false
        textView.enclosingScrollView?.hasVerticalScroller = true
        textView.enclosingScrollView?.hasHorizontalScroller = false
        textView.isRichText = false
        
        // Make sure scroll indicators match theme
        textView.enclosingScrollView?.scrollerStyle = .overlay
        
        // Ensure the scrollView also matches our color scheme
        textView.enclosingScrollView?.backgroundColor = isDarkMode ? .black : .white
        textView.enclosingScrollView?.drawsBackground = true
        
        // Ensure standard keyboard shortcuts work by making the text view the first responder
        textView.window?.makeFirstResponder(textView)
        
        // Enable standard editing keyboard shortcuts
        setupStandardShortcuts(for: textView)
    }
    
    private func setupStandardShortcuts(for textView: NSTextView) {
        // Ensure standard edit menu is properly connected
        // This enables Command+X (cut), Command+C (copy), Command+V (paste), 
        // Command+A (select all), Command+Z (undo), and Command+Shift+Z (redo)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // Explicitly enable common keyboard shortcut actions
        textView.enabledTextCheckingTypes = 0
        
        // The undoManager property in NSTextView is get-only
        // We can't assign to it, but we can ensure that it has an associated undo manager
        // from the window or use the shared one
        if textView.undoManager == nil {
            // This is just a check - if nil, the text view will use the window's undo manager
            // when it becomes part of a window hierarchy
            NSLog("Warning: TextView has no undoManager. Will use default when available.")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onTextChange: onTextChange)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onTextChange: ((String) -> Void)?
        
        init(text: Binding<String>, onTextChange: ((String) -> Void)?) {
            self.text = text
            self.onTextChange = onTextChange
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            onTextChange?(textView.string)
        }
    }
}
