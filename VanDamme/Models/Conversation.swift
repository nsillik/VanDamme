//
//  Conversation.swift
//  VanDamme
//
//  Created by Nick Sillik on 11/22/25.
//

import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var sessionId: String
    var title: String
    var createdAt: Date
    var filePath: String?

    // Relationship
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    init(
        id: UUID = UUID(),
        sessionId: String,
        title: String? = nil,
        createdAt: Date = Date(),
        filePath: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.title = title ?? sessionId
        self.createdAt = createdAt
        self.filePath = filePath
    }

    // Computed property for message count
    var messageCount: Int {
        messages.count
    }

    // Get the first user message for potential title generation
    var firstUserMessage: Message? {
        messages.first { $0.typeEnum == .user }
    }
}
