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
                    Text("enter tri-passwords to exit Scribo")
                        .font(.headline)
                        .padding()
                    
                    Text("password \(authManager.passwordIndex + 1) of 3")
                        .padding(.bottom)
                    
                    SecureField("enter password", text: $authManager.passwords[authManager.passwordIndex])
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .frame(width: 300)
                    
                    HStack {
                        Button("cancel") {
                            showEscapeDialog = false
                        }
                        .padding()
                        
                        Button("submit") {
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
            Text("scribo")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.black)
            
            Text("distraction-free writing")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(.gray)
            
            TextField("document title (optional)", text: $documentTitle)
                .font(.system(size: 18))
                .textFieldStyle(PlainTextFieldStyle())
                .frame(width: 400)
                .padding()
                .background(Color(white: 0.98))
                .cornerRadius(8)
            
            Button("start writing") {
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
