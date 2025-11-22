//
//  VanDammeTests.swift
//  VanDammeTests
//
//  Created by Nick Sillik on 11/22/25.
//

import Foundation
import Testing
import SwiftData
@testable import VanDamme

@MainActor
struct VanDammeTests {

    @Test func testJSONLParserDeserializesCorrectly() async throws {
        // Setup: Create in-memory model container
        let schema = Schema([
            Conversation.self,
            Message.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let context = ModelContext(container)

        // Get test file URL from test resources
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("test-conversation.jsonl")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Issue.record("Test JSONL file not found at: \(fileURL.path)")
            return
        }

        // Parse the file
        let conversation = try JSONLParser.parse(fileURL: fileURL, into: context)

        // Validate conversation properties
        #expect(conversation.sessionId == "afbb70e2-4360-432f-8b41-ec4adc3cad69")
        #expect(conversation.filePath == fileURL.path)
        #expect(conversation.messages.count > 0, "Should have parsed messages")

        // Validate messages were parsed
        let messages = conversation.messages.sorted { $0.timestamp < $1.timestamp }

        // Check first message
        if let firstMessage = messages.first {
            #expect(firstMessage.uuid != "")
            #expect(firstMessage.timestamp != Date(timeIntervalSince1970: 0))
            #expect(firstMessage.typeEnum != nil, "Message type should be valid")
            #expect(firstMessage.roleEnum != nil, "Message role should be valid")
        }

        // Validate user messages exist
        let userMessages = messages.filter { $0.typeEnum == .user }
        #expect(userMessages.count > 0, "Should have at least one user message")

        // Validate assistant messages exist
        let assistantMessages = messages.filter { $0.typeEnum == .assistant }
        #expect(assistantMessages.count > 0, "Should have at least one assistant message")

        // Validate assistant messages have model info
        if let firstAssistant = assistantMessages.first {
            #expect(firstAssistant.model != nil, "Assistant messages should have model info")
        }

        // Validate content can be decoded
        for message in messages.prefix(5) {
            if let content = message.content {
                #expect(content.count > 0, "Content should not be empty")

                // Plain text content can be decoded (but may be empty for some message types)
                _ = message.plainTextContent
            }
        }

        // Validate that at least some messages have non-empty plain text
        let messagesWithText = messages.filter {
            if let text = $0.plainTextContent, !text.isEmpty {
                return true
            }
            return false
        }
        #expect(messagesWithText.count > 0, "Should have at least some messages with text content")

        // Validate token usage can be decoded for assistant messages
        if let assistantWithTokens = assistantMessages.first(where: { $0.tokenUsageData != nil }) {
            let usage = assistantWithTokens.tokenUsage
            #expect(usage != nil, "Should be able to decode token usage")
        }

        print("✅ Parsed \(messages.count) messages from conversation \(conversation.sessionId)")
    }

    @Test func testJSONLParserHandlesDuplicates() async throws {
        // Setup: Create in-memory model container
        let schema = Schema([
            Conversation.self,
            Message.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let context = ModelContext(container)

        // Get test file URL from test resources
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("test-conversation.jsonl")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Issue.record("Test JSONL file not found at: \(fileURL.path)")
            return
        }

        // Parse the file twice
        let conversation1 = try JSONLParser.parse(fileURL: fileURL, into: context)
        let conversation2 = try JSONLParser.parse(fileURL: fileURL, into: context)

        // Should return the same conversation (not create duplicate)
        #expect(conversation1.sessionId == conversation2.sessionId)

        // Verify only one conversation exists
        let descriptor = FetchDescriptor<Conversation>()
        let allConversations = try context.fetch(descriptor)
        #expect(allConversations.count == 1, "Should not create duplicate conversations")

        print("✅ Duplicate detection works correctly")
    }

    @Test func testMessageContentSerialization() async throws {
        // Test that MessageContent can be serialized and deserialized
        let textContent = MessageContent(
            type: "text",
            text: "Hello, world!",
            id: nil,
            name: nil,
            input: nil,
            content: nil,
            toolUseId: nil
        )

        let toolUseContent = MessageContent(
            type: "tool_use",
            text: nil,
            id: "tool-123",
            name: "Read",
            input: ["file_path": AnyCodable("/path/to/file")],
            content: nil,
            toolUseId: nil
        )

        let contents = [textContent, toolUseContent]

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(contents)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([MessageContent].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded[0].type == "text")
        #expect(decoded[0].text == "Hello, world!")
        #expect(decoded[1].type == "tool_use")
        #expect(decoded[1].name == "Read")

        print("✅ MessageContent serialization works correctly")
    }

    @Test func testTokenUsageSerialization() async throws {
        // Test that TokenUsage can be serialized and deserialized
        let usage = TokenUsage(
            inputTokens: 100,
            outputTokens: 50,
            cacheCreationInputTokens: 10,
            cacheReadInputTokens: 5
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(usage)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TokenUsage.self, from: data)

        #expect(decoded.inputTokens == 100)
        #expect(decoded.outputTokens == 50)
        #expect(decoded.cacheCreationInputTokens == 10)
        #expect(decoded.cacheReadInputTokens == 5)

        print("✅ TokenUsage serialization works correctly")
    }

}
