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

import SwiftUI
import Network

// Document model
struct ScriboDocument: Codable, Identifiable {
    var id = UUID()
    var title: String
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    
    init(title: String, content: String = "") {
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

// Document storage manager
class DocumentManager: ObservableObject {
    @Published var documents: [ScriboDocument] = []
    private let documentsURL: URL
    
    init() {
        // Get the app's documents directory
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        self.documentsURL = documentsDirectory.appendingPathComponent("ScriboDocuments")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: documentsURL.path) {
            try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        loadDocuments()
    }
    
    // Load all documents from disk
    func loadDocuments() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            documents = []
            
            for fileURL in fileURLs where fileURL.pathExtension == "scribo" {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let document = try JSONDecoder().decode(ScriboDocument.self, from: data)
                    documents.append(document)
                } catch {
                    print("Error loading document: \(error)")
                }
            }
            
            // Sort by modification date, newest first
            documents.sort { $0.modifiedAt > $1.modifiedAt }
        } catch {
            print("Error loading documents: \(error)")
        }
    }
    
    // Save a document to disk
    func saveDocument(_ document: ScriboDocument) {
        do {
            var docToSave = document
            docToSave.modifiedAt = Date()
            
            let fileURL = documentsURL.appendingPathComponent("\(document.id).scribo")
            let data = try JSONEncoder().encode(docToSave)
            try data.write(to: fileURL)
            
            // Update the document in memory
            if let index = documents.firstIndex(where: { $0.id == document.id }) {
                documents[index] = docToSave
            } else {
                documents.append(docToSave)
            }
            
            // Re-sort documents
            documents.sort { $0.modifiedAt > $1.modifiedAt }
        } catch {
            print("Error saving document: \(error)")
        }
    }
    
    // Create a new document
    func createDocument(title: String) -> ScriboDocument {
        let newDocument = ScriboDocument(title: title)
        saveDocument(newDocument)
        return newDocument
    }
    
    // Delete a document
    func deleteDocument(_ document: ScriboDocument) {
        let fileURL = documentsURL.appendingPathComponent("\(document.id).scribo")
        try? FileManager.default.removeItem(at: fileURL)
        documents.removeAll { $0.id == document.id }
    }
}

// Main view controller
struct MainView: View {
    @State private var selectedDocument: ScriboDocument?
    @State private var isEditingDocument = false
    @EnvironmentObject var documentManager: DocumentManager
    
    var body: some View {
        Group {
            if let document = selectedDocument, isEditingDocument {
                EditorView(document: document) { updatedDocument in
                    documentManager.saveDocument(updatedDocument)
                    selectedDocument = nil
                    isEditingDocument = false
                }
            } else {
                DocumentListView(
                    onNewDocument: { document in
                        selectedDocument = document
                        isEditingDocument = true
                    },
                    onOpenDocument: { document in
                        selectedDocument = document
                        isEditingDocument = true
                    }
                )
            }
        }
    }
}

// Document list view (start screen)
struct DocumentListView: View {
    @State private var showNewDocumentDialog = false
    @State private var newDocumentTitle = ""
    @EnvironmentObject var documentManager: DocumentManager
    
    var onNewDocument: (ScriboDocument) -> Void
    var onOpenDocument: (ScriboDocument) -> Void
    
    var body: some View {
        ZStack {
            // Force white background
            Rectangle()
                .fill(Color.white)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                // App title
                Text("Scribo")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(.black)
                
                Text("Distraction-free writing")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.gray)
                
                HStack(spacing: 40) {
                    // New document button
                    Button(action: {
                        showNewDocumentDialog = true
                    }) {
                        VStack {
                            Image(systemName: "plus.square")
                                .font(.system(size: 32))
                            Text("New Document")
                                .font(.headline)
                        }
                        .frame(width: 180, height: 120)
                        .background(Color(white: 0.98))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Recent documents section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Recent Documents")
                            .font(.headline)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                if documentManager.documents.isEmpty {
                                    Text("No documents yet")
                                        .foregroundColor(.gray)
                                        .italic()
                                } else {
                                    ForEach(documentManager.documents) { document in
                                        Button(action: {
                                            onOpenDocument(document)
                                        }) {
                                            HStack {
                                                Text(document.title)
                                                Spacer()
                                                Text(formattedDate(document.modifiedAt))
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(Color.white)
                                            .cornerRadius(4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .padding()
                        }
                        .frame(width: 400, height: 300)
                        .background(Color(white: 0.98))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(60)
            
            // New document dialog
            if showNewDocumentDialog {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        Text("Create New Document")
                            .font(.headline)
                        
                        TextField("Document Title", text: $newDocumentTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 300)
                        
                        HStack(spacing: 20) {
                            Button("Cancel") {
                                showNewDocumentDialog = false
                                newDocumentTitle = ""
                            }
                            .padding(.horizontal)
                            
                            Button("Create") {
                                guard !newDocumentTitle.isEmpty else { return }
                                let newDocument = documentManager.createDocument(title: newDocumentTitle)
                                showNewDocumentDialog = false
                                newDocumentTitle = ""
                                onNewDocument(newDocument)
                            }
                            .padding(.horizontal)
                            .disabled(newDocumentTitle.isEmpty)
                        }
                    }
                    .padding(30)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
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
}

// Editor view
struct EditorView: View {
    @State private var document: ScriboDocument
    @State private var showEscapeDialog = false
    @State private var isFullScreen = false
    @State private var showSavedConfirmation = false
    @State private var lastSaveTime = Date()
    
    @ObservedObject private var networkManager = NetworkManager()
    @ObservedObject private var authManager = AuthenticationManager()
    
    let onExit: (ScriboDocument) -> Void
    
    init(document: ScriboDocument, onExit: @escaping (ScriboDocument) -> Void) {
        _document = State(initialValue: document)
        self.onExit = onExit
    }
    
    var body: some View {
        ZStack {
            // Force white background
            Rectangle()
                .fill(Color.white)
                .edgesIgnoringSafeArea(.all)
            
            // Document title and content
            VStack(spacing: 0) {
                // Simple header with document title
                HStack {
                    Text(document.title)
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Auto-save indicator
                    if showSavedConfirmation {
                        Text("Saved")
                            .foregroundColor(.gray)
                            .font(.caption)
                            .padding(.trailing, 10)
                    }
                }
                .padding()
                .background(Color.white)
                
                // Main text editor
                TextEditor(text: $document.content)
                    .font(.system(size: 18))
                    .padding()
                    .background(Color.white)
                    .colorScheme(.light)
                    .onChange(of: document.content) { _ in
                        // Only save if it's been at least 2 seconds since last save
                        let now = Date()
                        if now.timeIntervalSince(lastSaveTime) > 2.0 {
                            saveDocument()
                        }
                    }
            }
            
            // Escape dialog
            if showEscapeDialog {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
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
                                authManager.reset()
                            }
                            .padding()
                            
                            Button("Submit") {
                                if authManager.checkPassword() {
                                    if authManager.isAuthenticated {
                                        showEscapeDialog = false
                                        saveDocument()
                                        networkManager.enableWifi()
                                        onExit(document)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                    .padding(30)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
            }
        }
        .background(Color.white)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            // Enter full screen and disable WiFi
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.windows.first?.toggleFullScreen(nil)
                networkManager.disableWifi()
            }
            setupKeyboardShortcuts()
        }
    }
    
    func saveDocument() {
        lastSaveTime = Date()
        document.modifiedAt = Date()
        
        // Show saved confirmation briefly
        showSavedConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSavedConfirmation = false
        }
    }
    
    func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Catch escape key and CMD+Q to prevent normal exit
            if event.keyCode == 53 || (event.modifierFlags.contains(.command) && event.keyCode == 12) {
                showEscapeDialog = true
                return nil
            }
            
            // Auto-save shortcut (Command+S)
            if event.modifierFlags.contains(.command) && event.keyCode == 1 {
                saveDocument()
                return nil
            }
            
            return event
        }
    }
}
