//
//  StartScreen.swift
//  scribo
//
//  Created by bm on 3/9/25.
//

import SwiftUI

struct DocumentListView: View {
    @State private var showNewDocumentDialog = false
    @State private var newDocumentTitle = ""
    @FocusState private var isTextFieldFocused: Bool
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
                // App title and subtitle with reduced spacing
                VStack(spacing: 8) {  // Reduced spacing between title and subtitle
                    Text("scribo")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.black)
                    
                    Text("distraction-free writing")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.gray)
                }
                
                // Wider recent documents with compose button
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("recent writing")
                            .font(.headline)
                        
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
                                .foregroundColor(.black)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            if documentManager.documents.isEmpty {
                                Text("no documents yet")
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
                    .frame(maxWidth: .infinity)  // Full width
                    .background(Color(white: 0.98))
                    .cornerRadius(12)
                }
            }
            .padding(60)
            
            // Made with love text at bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("madvision.com | san francisco, ca")
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray.opacity(0.6))
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
                        
                        TextField("", text: $newDocumentTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 300)
                            .focused($isTextFieldFocused) // Use FocusState binding
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
                            
                            Button("write") {
                                guard !newDocumentTitle.isEmpty else { return }
                                let newDocument = documentManager.createDocument(title: newDocumentTitle)
                                showNewDocumentDialog = false
                                newDocumentTitle = ""
                                isTextFieldFocused = false
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
