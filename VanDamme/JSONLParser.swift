//
//  JSONLParser.swift
//  VanDamme
//
//  Created by Nick Sillik on 11/22/25.
//

import Foundation
import SwiftData

// Raw JSON structures matching Claude's JSONL format
struct JSONLLine: Codable {
    let parentUuid: String?
    let isSidechain: Bool?
    let sessionId: String
    let type: String
    let message: JSONLMessage?
    let uuid: String?  // Optional because queue-operations don't have UUIDs
    let timestamp: String
}

struct JSONLMessage: Codable {
    let role: String
    let content: JSONLContent?
    let model: String?
    let id: String?
    let type: String?
    let usage: JSONLUsage?
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case role, content, model, id, type, usage
        case stopReason = "stop_reason"
    }
}

enum JSONLContent: Codable {
    case string(String)
    case array([MessageContent])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([MessageContent].self) {
            self = .array(array)
        } else {
            // If we can't decode it, just treat it as null
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .null:
            try container.encodeNil()
        }
    }
}

struct JSONLUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

enum JSONLParserError: Error {
    case invalidURL
    case fileReadError
    case noSessionId
    case invalidTimestamp
}

class JSONLParser {
    static func parse(fileURL: URL, into modelContext: ModelContext) throws -> Conversation {
        // Read file contents
        guard let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            throw JSONLParserError.fileReadError
        }

        // Split into lines and decode
        let lines = fileContents.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        var jsonlLines: [JSONLLine] = []
        let decoder = JSONDecoder()

        for (index, line) in lines.enumerated() {
            guard let data = line.data(using: .utf8) else {
                print("Warning: Could not convert line \(index) to data")
                continue
            }

            do {
                let jsonlLine = try decoder.decode(JSONLLine.self, from: data)
                jsonlLines.append(jsonlLine)
            } catch {
                print("Warning: Could not decode line \(index): \(error)")
                continue
            }
        }

        // Get session ID from first line
        guard let sessionId = jsonlLines.first?.sessionId else {
            throw JSONLParserError.noSessionId
        }

        // Check if conversation already exists
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )

        let existingConversations = try? modelContext.fetch(descriptor)
        if let existing = existingConversations?.first {
            print("Conversation with sessionId \(sessionId) already exists")
            return existing
        }

        // Create new conversation
        let conversation = Conversation(
            sessionId: sessionId,
            filePath: fileURL.path
        )

        modelContext.insert(conversation)

        // Parse messages
        for jsonlLine in jsonlLines {
            // Skip lines without UUIDs (like queue-operations)
            guard let uuid = jsonlLine.uuid else { continue }

            guard let message = jsonlLine.message else { continue }

            // Parse timestamp
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let timestamp = formatter.date(from: jsonlLine.timestamp) else {
                print("Warning: Could not parse timestamp: \(jsonlLine.timestamp)")
                continue
            }

            // Parse content first to check for tool results
            var contentArray: [MessageContent]? = nil

            if let content = message.content {
                switch content {
                case .string(let str):
                    contentArray = [MessageContent(
                        type: "text",
                        text: str,
                        id: nil,
                        name: nil,
                        input: nil,
                        content: nil,
                        toolUseId: nil
                    )]
                case .array(let array):
                    contentArray = array
                case .null:
                    contentArray = nil
                }
            }

            // Determine message type and role
            // Check if this is a tool result message (has tool_result content)
            let hasToolResult = contentArray?.contains { $0.type == "tool_result" } ?? false

            let messageType: MessageType
            let role: MessageRole

            if hasToolResult {
                print("✓ Detected tool result message: \(uuid)")
                messageType = .tool
                role = .user  // Tool results are technically from the user/environment
            } else if jsonlLine.type == "user" {
                messageType = .user
                role = .user
            } else if jsonlLine.type == "assistant" || message.role == "assistant" {
                messageType = .assistant
                role = .assistant
            } else {
                messageType = .system
                role = .system
            }

            // Parse token usage
            var tokenUsage: TokenUsage? = nil
            if let usage = message.usage {
                tokenUsage = TokenUsage(
                    inputTokens: usage.inputTokens,
                    outputTokens: usage.outputTokens,
                    cacheCreationInputTokens: usage.cacheCreationInputTokens,
                    cacheReadInputTokens: usage.cacheReadInputTokens
                )
            }

            // Create message
            let msg = Message(
                uuid: uuid,
                parentUuid: jsonlLine.parentUuid,
                messageType: messageType,
                role: role,
                timestamp: timestamp,
                content: contentArray,
                model: message.model,
                tokenUsage: tokenUsage,
                isSidechain: jsonlLine.isSidechain ?? false
            )

            msg.conversation = conversation
            modelContext.insert(msg)
        }

        // Save context
        try modelContext.save()

        return conversation
    }
}
