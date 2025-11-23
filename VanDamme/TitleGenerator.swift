//
//  TitleGenerator.swift
//  VanDamme
//
//  Created by Nick Sillik on 11/22/25.
//

import Foundation
import FoundationModels

/// Generates conversation titles using Apple's on-device Foundation Models
class TitleGenerator {

    /// Generate a title from the first few messages of a conversation
    /// - Parameter messages: Array of messages from the conversation (typically first 4)
    /// - Returns: A generated title, or nil if generation fails
    static func generateTitle(from messages: [Message]) async -> String? {
        // Check if the model is available
        guard SystemLanguageModel.default.isAvailable else {
            print("⚠️ Foundation Model is not available")
            return nil
        }

        // Extract text content from messages
        let conversationText = messages.compactMap { message -> String? in
            guard let content = message.plainTextContent else { return nil }
            let role = message.typeEnum == .user ? "User" : "Assistant"
            return "\(role): \(content)"
        }.joined(separator: "\n\n")

        // If no text content, return nil
        guard !conversationText.isEmpty else {
            print("⚠️ No text content found in messages")
            return nil
        }

        // Create a prompt for title generation
        let instructions = """
        You are a conversation title generator.
        Based on the beginning of a conversation, create a short, descriptive title.
        The title should be 3-6 words maximum.
        Do not use quotes or punctuation in the title.
        Respond only with the title, nothing else.
        """

        let prompt = """
        Generate a short title for this conversation:

        \(conversationText.prefix(1000))
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)

            // Clean up the response
            let title = response.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")

            print("✓ Generated title: \(title)")
            return title.isEmpty ? nil : title

        } catch {
            print("⚠️ Failed to generate title: \(error)")
            return nil
        }
    }
}
