//
//  ContentView.swift
//  VanDamme
//
//  Created by Nick Sillik on 11/22/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext)
    private var modelContext

    @Query(sort: \Conversation.createdAt, order: .reverse)
    private var conversations: [Conversation]

    @State private var selectedConversation: Conversation?
    @State private var isDropTargeted = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showingRenameAlert = false
    @State private var conversationToRename: Conversation?
    @State private var newTitle = ""

    var body: some View {
        NavigationSplitView {
            conversationList
                .navigationSplitViewColumnWidth(min: 250, ideal: 300)
                .onDrop(
                    of: [.fileURL],
                    delegate: FileDropDelegate(
                        modelContext: modelContext,
                        isTargeted: $isDropTargeted,
                        errorMessage: $errorMessage,
                        isImporting: $isImporting
                    )
                )
                .alert("Error", isPresented: .constant(errorMessage != nil)) {
                    Button("OK") {
                        errorMessage = nil
                    }
                } message: {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                    }
                }
                .alert("Rename Conversation", isPresented: $showingRenameAlert) {
                    TextField("Title", text: $newTitle)
                    Button("Cancel", role: .cancel) {
                        conversationToRename = nil
                        newTitle = ""
                    }
                    Button("Rename") {
                        if let conversation = conversationToRename {
                            conversation.title = newTitle
                            try? modelContext.save()
                        }
                        conversationToRename = nil
                        newTitle = ""
                    }
                }
        } detail: {
            detailView
        }
    }

    @ViewBuilder
    private var conversationList: some View {
        VStack {
            // Conversation List
            List(selection: $selectedConversation) {
                ForEach(conversations) { conversation in
                    NavigationLink(value: conversation) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title)
                                .font(.headline)
                                .lineLimit(1)

                            HStack {
                                Text(conversation.createdAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text("\(conversation.messageCount) messages")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .contextMenu {
                        Button("Rename") {
                            conversationToRename = conversation
                            newTitle = conversation.title
                            showingRenameAlert = true
                        }

                        Button("Delete", role: .destructive) {
                            deleteConversation(conversation)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            // Drop Zone at bottom
            DropZoneView(isTargeted: isDropTargeted, isImporting: isImporting)
                .frame(height: 80)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let conversation = selectedConversation {
            ConversationDetailView(conversation: conversation)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)

                Text("No Conversation Selected")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("Drag and drop a .jsonl file to import")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func deleteConversation(_ conversation: Conversation) {
        withAnimation {
            modelContext.delete(conversation)
            try? modelContext.save()
        }
    }
}

// Drop Zone View
struct DropZoneView: View {
    let isTargeted: Bool
    let isImporting: Bool

    var body: some View {
        VStack(spacing: 8) {
            if isImporting {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Importing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.title2)
                    .foregroundStyle(isTargeted ? .blue : .secondary)

                Text(isTargeted ? "Drop to import" : "Drop .jsonl file here")
                    .font(.caption)
                    .foregroundStyle(isTargeted ? .blue : .secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isTargeted ? Color.blue : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [5])
                        )
                )
        )
        .padding(8)
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Conversation.self, inMemory: true)
}
