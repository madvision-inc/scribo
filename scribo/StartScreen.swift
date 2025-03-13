//
//  StartScreen.swift
//  scribo
//
//  Created by bm on 3/9/25.
//

import SwiftUI

// SwipeableDocumentItem - New component for swipeable document items
struct SwipeableDocumentItem: View {
    let document: ScriboDocument
    let onOpen: () -> Void
    let onDelete: () -> Void
    let isDarkMode: Bool
    
    @State private var offset: CGFloat = 0
    @State private var showDeleteButton = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @GestureState private var isDragging = false
    
    // Constants for animation
    private let deleteButtonWidth: CGFloat = 80
    private let deleteThreshold: CGFloat = 60
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background (revealed when swiping)
            HStack(spacing: 0) {
                Spacer()
                
                // Delete button that appears when swiping
                Button(action: {
                    withAnimation(.spring()) {
                        confirmDelete()
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: deleteButtonWidth)
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color.red)
                .cornerRadius(4)
                .opacity(showDeleteButton ? 1 : 0)
            }
            
            // Document item that can be swiped
            Button(action: onOpen) {
                HStack {
                    Text(document.title)
                        .lineLimit(1)
                        .foregroundColor(isDarkMode ? .white : .black)
                    Spacer()
                    Text(formattedDate(document.modifiedAt))
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .gray : .gray)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isDarkMode ? Color.black : Color.white)
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        // Only allow dragging to the left
                        let dragAmount = value.translation.width
                        if dragAmount < 0 {
                            offset = max(dragAmount, -deleteButtonWidth)
                            showDeleteButton = true
                        }
                    }
                    .onEnded { value in
                        // Check if dragged past threshold
                        if -offset > deleteThreshold {
                            withAnimation(.spring()) {
                                offset = -deleteButtonWidth
                            }
                        } else {
                            withAnimation(.spring()) {
                                offset = 0
                                showDeleteButton = false
                            }
                        }
                    }
            )
            // Add context menu for right-click delete - but delete directly without additional confirmation
            .contextMenu {
                Button(action: {
                    // Delete directly without additional confirmation when using right-click
                    deleteDocument()
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            // Delete confirmation overlay - simplified design
            if showDeleteConfirmation {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Delete this document?")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        Button("cancel") {
                            withAnimation(.spring()) {
                                showDeleteConfirmation = false
                                offset = 0
                                showDeleteButton = false
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        
                        Button("delete") {
                            deleteDocument()
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(4)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                .transition(.opacity)
                .zIndex(2)
                .offset(x: -10, y: 0)
            }
        }
        // Apply opacity animation when deleting
        .opacity(isDeleting ? 0 : 1)
        .animation(isDeleting ? .easeOut(duration: 0.3) : .spring(), value: isDeleting)
    }
    
    // Format date for display
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Show delete confirmation
    func confirmDelete() {
        withAnimation(.spring()) {
            showDeleteConfirmation = true
        }
    }
    
    // Perform actual deletion with animation
    func deleteDocument() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isDeleting = true
        }
        
        // Small delay to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDelete()
        }
    }
}

struct DocumentListView: View {
    @State private var showNewDocumentDialog = false
    @State private var newDocumentTitle = ""
    @State private var showDeletedNotification = false
    @State private var lastDeletedDocument: ScriboDocument?
    @State private var undoTimer: Timer?
    @State private var showModeChangeAnimation = false
    @State private var iconRotation: Double = 0
    @FocusState private var isTextFieldFocused: Bool
    @EnvironmentObject var documentManager: DocumentManager
    
    // Use AppStorage to share dark mode preference across the app
    @AppStorage("ScriboDarkModeEnabled") private var isDarkMode = false
    
    var onNewDocument: (ScriboDocument) -> Void
    var onOpenDocument: (ScriboDocument) -> Void
    
    var body: some View {
        ZStack {
            // Force background color based on mode
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
            
            VStack(spacing: 40) {
                // App title, subtitle, and dark mode toggle
                VStack(spacing: 8) {
                    // Separate the dark mode toggle to position it higher
                    HStack {
                        Spacer()
                        
                        // Dark mode toggle in top right corner - smaller and higher
                        Button(action: {
                            toggleDarkMode()
                        }) {
                            // Use different icons without rotation to avoid upside-down issue
                            Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                                .font(.system(size: 14)) // Smaller icon
                                .foregroundColor(isDarkMode ? .white : .black)
                                .scaleEffect(iconRotation != 0 ? 1.2 : 1.0) // Scale instead of rotate
                                .padding(8) // Add padding inside the button
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 20) // Position higher
                        .padding(.trailing, 20) // More right padding
                    }
                    .padding(.bottom, -10) // Negative padding to reduce space below
                    
                    Text("scribo")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text("distraction-free writing")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(isDarkMode ? .gray : .gray)
                }
                
                // Wider recent documents with compose button
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("recent writing")
                            .font(.headline)
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        Spacer()
                        
                        // Compose button (icon only)
                        Button(action: {
                            showNewDocumentDialog = true
                            // Focus text field when dialog opens
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isTextFieldFocused = true
                            }
                        }) {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 20))
                                .foregroundColor(isDarkMode ? .white : .black)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            if documentManager.documents.isEmpty {
                                Text("no documents yet")
                                    .foregroundColor(isDarkMode ? .gray : .gray)
                                    .italic()
                            } else {
                                ForEach(documentManager.documents) { document in
                                    SwipeableDocumentItem(
                                        document: document,
                                        onOpen: {
                                            onOpenDocument(document)
                                        },
                                        onDelete: {
                                            deleteDocument(document)
                                        },
                                        isDarkMode: isDarkMode
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity)  // Full width
                    .background(isDarkMode ? Color(white: 0.1) : Color(white: 0.98))
                    .cornerRadius(12)
                }
            }
            .padding(60)
            // Apply animation modifier to the entire content stack to ensure synchronized transitions
            .animation(.easeInOut(duration: 0.3), value: isDarkMode)
            
            // Made with love text at bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("madvision.com | san francisco, ca")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? Color.gray.opacity(0.6) : Color.gray.opacity(0.6))
                        .padding()
                }
            }
            
            // New document dialog
            if showNewDocumentDialog {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        Text("give your piece a name...")
                            .font(.headline)
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        TextField("", text: $newDocumentTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 300)
                            .focused($isTextFieldFocused)
                            .onAppear {
                                // Make sure the field is focused when dialog appears
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isTextFieldFocused = true
                                }
                            }
                            .onSubmit {
                                // Trigger the same action as the "write" button when Enter is pressed
                                if !newDocumentTitle.isEmpty {
                                    let newDocument = documentManager.createDocument(title: newDocumentTitle)
                                    showNewDocumentDialog = false
                                    newDocumentTitle = ""
                                    isTextFieldFocused = false
                                    onNewDocument(newDocument)
                                }
                            }
                        
                        HStack(spacing: 20) {
                            Button("cancel") {
                                showNewDocumentDialog = false
                                newDocumentTitle = ""
                                isTextFieldFocused = false
                            }
                            .padding(.horizontal)
                            .foregroundColor(isDarkMode ? .white : .black)
                            
                            Button("write") {
                                guard !newDocumentTitle.isEmpty else { return }
                                let newDocument = documentManager.createDocument(title: newDocumentTitle)
                                showNewDocumentDialog = false
                                newDocumentTitle = ""
                                isTextFieldFocused = false
                                onNewDocument(newDocument)
                            }
                            .padding(.horizontal)
                            .foregroundColor(isDarkMode ? .white : .black)
                            .disabled(newDocumentTitle.isEmpty)
                        }
                    }
                    .padding(30)
                    .background(isDarkMode ? Color.black : Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
            }
            
            // Undo notification for deleted documents - fixed styling for consistency
            if showDeletedNotification, let deletedDoc = lastDeletedDocument {
                VStack {
                    Spacer()
                    
                    HStack {
                        Text("\(deletedDoc.title) deleted")
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("undo") {
                            undoDelete()
                        }
                        .foregroundColor(.white)
                        // Removed underline for consistent styling
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .padding()
                    .transition(.move(edge: .bottom))
                }
                .zIndex(100)
                .animation(.spring(), value: showDeletedNotification)
            }
        }
    }
    
    // Format date for display
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Toggle dark mode with enhanced animation
    func toggleDarkMode() {
        // Use scale animation instead of rotation
        withAnimation(.easeInOut(duration: 0.2)) {
            iconRotation = 1.0 // Just a non-zero value to trigger scale
        }
        
        // Show flash animation with improved timing
        withAnimation(.easeInOut(duration: 0.2)) {
            showModeChangeAnimation = true
        }
        
        // After a brief delay, switch the mode and hide animation with smoother transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isDarkMode.toggle()
            
            withAnimation(.easeInOut(duration: 0.4)) {
                showModeChangeAnimation = false
            }
            
            // Reset the icon rotation/scale after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    iconRotation = 0
                }
            }
        }
    }
    
    // Delete document with undo capability
    func deleteDocument(_ document: ScriboDocument) {
        // Store document for potential undo
        lastDeletedDocument = document
        
        // Delete the document
        documentManager.deleteDocument(document)
        
        // Show undo notification
        withAnimation(.spring()) {
            showDeletedNotification = true
        }
        
        // Cancel existing timer if one exists
        undoTimer?.invalidate()
        
        // Set timer for auto-dismissal of undo notification
        undoTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeOut) {
                showDeletedNotification = false
            }
            lastDeletedDocument = nil
        }
    }
    
    // Undo the last delete action
    func undoDelete() {
        if let document = lastDeletedDocument {
            // Save the document back to storage
            documentManager.saveDocument(document)
            
            // Clear undo state
            withAnimation {
                showDeletedNotification = false
            }
            lastDeletedDocument = nil
            undoTimer?.invalidate()
        }
    }
}
