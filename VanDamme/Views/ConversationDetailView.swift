//
//  ConversationDetailView.swift
//  VanDamme
//
//  Created by Nick Sillik on 11/22/25.
//

import SwiftUI
import SwiftData

struct ConversationDetailView: View {
    let conversation: Conversation

    var sortedMessages: [Message] {
        conversation.messages.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Text(conversation.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack {
                        Text(conversation.createdAt, format: .dateTime.month().day().year().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(.tertiary)

                        Text("\(conversation.messageCount) messages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Session: \(conversation.sessionId)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Messages
                ForEach(sortedMessages, id: \.uuid) { message in
                    MessageBubbleView(message: message)
                        .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

#Preview {
    // Create preview data
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Conversation.self, Message.self, configurations: config)
    let context = container.mainContext

    // Create sample conversation
    let conversation = Conversation(
        sessionId: "preview-session",
        title: "Sample Conversation",
        createdAt: Date()
    )

    // Create sample messages
    let userMessage = Message(
        uuid: "user-1",
        parentUuid: nil,
        messageType: .user,
        role: .user,
        timestamp: Date(),
        content: [
            MessageContent(
                type: "text",
                text: "Hello! Can you help me with SwiftUI?",
                id: nil,
                name: nil,
                input: nil,
                content: nil,
                toolUseId: nil
            )
        ]
    )
    userMessage.conversation = conversation

    let assistantMessage = Message(
        uuid: "assistant-1",
        parentUuid: "user-1",
        messageType: .assistant,
        role: .assistant,
        timestamp: Date().addingTimeInterval(5),
        content: [
            MessageContent(
                type: "text",
                text: "Of course! I'd be happy to help you with SwiftUI. What would you like to know?",
                id: nil,
                name: nil,
                input: nil,
                content: nil,
                toolUseId: nil
            )
        ],
        model: "claude-sonnet-4-5",
        tokenUsage: TokenUsage(
            inputTokens: 100,
            outputTokens: 50,
            cacheCreationInputTokens: nil,
            cacheReadInputTokens: nil
        )
    )
    assistantMessage.conversation = conversation

    context.insert(conversation)
    context.insert(userMessage)
    context.insert(assistantMessage)

    return ConversationDetailView(conversation: conversation)
        .modelContainer(container)
}
