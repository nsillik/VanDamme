//
//  Message.swift
//  VanDamme
//
//  Created by Nick Sillik on 11/22/25.
//

import Foundation
import SwiftData

enum MessageType: String, Codable {
    case user
    case assistant
    case system
    case tool
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// Represents the content structure from Claude JSONL
struct MessageContent: Codable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: [String: AnyCodable]?
    let content: String?
    let toolUseId: String?

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input, content
        case toolUseId = "tool_use_id"
    }

    func inputValueString(for key: String) -> String? {
        guard let input = input, let anyCodable = input[key] else {
            return nil
        }

        return valueToString(anyCodable.value)
    }

    private func valueToString(_ value: Any, indentLevel: Int = 0) -> String {
        let indent = String(repeating: "  ", count: indentLevel)

        switch value {
        case let bool as Bool:
            return bool ? "true" : "false"

        case let int as Int:
            return "\(int)"

        case let double as Double:
            return "\(double)"

        case let string as String:
            // Truncate very long strings
            if string.count > 200 {
                return "\(string.prefix(200))..."
            }
            return string

        case let array as [Any]:
            if array.isEmpty {
                return "[]"
            }

            // For small arrays, show inline
            if array.count <= 3 {
                let items = array.map { valueToString($0, indentLevel: indentLevel) }
                return "[\(items.joined(separator: ", "))]"
            }

            // For larger arrays, show multi-line
            let items = array.map { "\(indent)  - \(valueToString($0, indentLevel: indentLevel + 1))" }
            return "[\n\(items.joined(separator: "\n"))\n\(indent)]"

        case let dict as [String: Any]:
            if dict.isEmpty {
                return "{}"
            }

            // For small dicts, try inline
            if dict.count <= 2 {
                let pairs = dict.sorted { $0.key < $1.key }.map { "\($0.key): \(valueToString($0.value, indentLevel: indentLevel))" }
                let inline = "{ \(pairs.joined(separator: ", ")) }"
                // If it's short enough, use inline
                if inline.count <= 60 {
                    return inline
                }
            }

            // Multi-line format for larger or complex dicts
            let pairs = dict.sorted { $0.key < $1.key }.map {
                "\(indent)  \($0.key): \(valueToString($0.value, indentLevel: indentLevel + 1))"
            }
            return "{\n\(pairs.joined(separator: "\n"))\n\(indent)}"

        case is NSNull:
            return "null"

        default:
            return String(describing: value)
        }
    }
}

// Helper to handle arbitrary JSON values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// Token usage statistics
struct TokenUsage: Codable {
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

@Model
final class Message {
    var uuid: String
    var parentUuid: String?
    var messageType: String // Store as String for SwiftData compatibility
    var role: String // Store as String for SwiftData compatibility
    var timestamp: Date
    var contentData: Data? // JSON-encoded array of MessageContent
    var model: String?
    var tokenUsageData: Data? // JSON-encoded TokenUsage
    var isSidechain: Bool

    // Relationship
    var conversation: Conversation?

    @MainActor
    init(
        uuid: String,
        parentUuid: String?,
        messageType: MessageType,
        role: MessageRole,
        timestamp: Date,
        content: [MessageContent]?,
        model: String? = nil,
        tokenUsage: TokenUsage? = nil,
        isSidechain: Bool = false
    ) {
        self.uuid = uuid
        self.parentUuid = parentUuid
        self.messageType = messageType.rawValue
        self.role = role.rawValue
        self.timestamp = timestamp
        self.model = model
        self.isSidechain = isSidechain

        // Encode content to Data
        if let content = content {
            self.contentData = try? JSONEncoder().encode(content)
        }

        // Encode token usage to Data
        if let tokenUsage = tokenUsage {
            self.tokenUsageData = try? JSONEncoder().encode(tokenUsage)
        }
    }

    // Convenience computed properties
    var typeEnum: MessageType? {
        MessageType(rawValue: messageType)
    }

    var roleEnum: MessageRole? {
        MessageRole(rawValue: role)
    }

    @MainActor
    var content: [MessageContent]? {
        guard let contentData = contentData else { return nil }
        return try? JSONDecoder().decode([MessageContent].self, from: contentData)
    }

    @MainActor
    var tokenUsage: TokenUsage? {
        guard let tokenUsageData = tokenUsageData else { return nil }
        return try? JSONDecoder().decode(TokenUsage.self, from: tokenUsageData)
    }

    @MainActor
    var plainTextContent: String? {
        guard let content = content else { return nil }
        return content.compactMap { $0.text ?? $0.content }.joined(separator: "\n")
    }
}

