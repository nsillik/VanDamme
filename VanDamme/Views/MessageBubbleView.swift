//
//  MessageBubbleView.swift
//  VanDamme
//
//  Created by Nick Sillik on 11/22/25.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    @State private var isExpanded = false
    @State private var showMetadata = false

    var body: some View {
        VStack(alignment: messageAlignment, spacing: 8) {
            // Message Header
            HStack {
                if message.typeEnum == .assistant {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.blue)
                } else if message.typeEnum == .user {
                    Image(systemName: "person.circle")
                        .foregroundStyle(.green)
                } else if message.typeEnum == .tool {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(.orange)
                }

                Text(message.typeEnum == .tool ? "Tool Result" : (message.typeEnum?.rawValue.capitalized ?? "Unknown"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if let model = message.model {
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text(model)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Button {
                    showMetadata.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Message Content
            if let content = message.content {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(content.enumerated()), id: \.offset) { index, contentItem in
                        ContentItemView(contentItem: contentItem, isExpanded: $isExpanded)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            // Metadata Section
            if showMetadata {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()

                    if let tokenUsage = message.tokenUsage {
                        HStack {
                            Text("Tokens:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if let input = tokenUsage.inputTokens {
                                Text("In: \(input)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            if let output = tokenUsage.outputTokens {
                                Text("Out: \(output)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            if let cacheRead = tokenUsage.cacheReadInputTokens, cacheRead > 0 {
                                Text("Cache: \(cacheRead)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Text("UUID: \(message.uuid)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(messageBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }

    private var messageAlignment: HorizontalAlignment {
        message.typeEnum == .user ? .trailing : .leading
    }

    private var messageBackground: some View {
        Group {
            if message.typeEnum == .user {
                Color.green.opacity(0.1)
            } else if message.typeEnum == .assistant {
                Color.blue.opacity(0.1)
            } else if message.typeEnum == .tool {
                Color.orange.opacity(0.1)
            } else {
                Color.gray.opacity(0.1)
            }
        }
    }
}

// Content Item View - handles different content types
struct ContentItemView: View {
    let contentItem: MessageContent
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch contentItem.type {
            case "text":
                if let text = contentItem.text {
                    Text(text)
                        .font(.body)
                        .textSelection(.enabled)
                }

            case "tool_use":
                ToolUseView(contentItem: contentItem, isExpanded: $isExpanded)

            case "tool_result":
                ToolResultView(contentItem: contentItem, isExpanded: $isExpanded)

            default:
                Text("[\(contentItem.type)]")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// Tool Use View
struct ToolUseView: View {
    let contentItem: MessageContent
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)

                    Image(systemName: "wrench.and.screwdriver")
                        .font(.caption)

                    if let name = contentItem.name {
                        Text("Tool: \(name)")
                            .font(.body)
                            .fontWeight(.medium)
                    } else {
                        Text("Tool Use")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
                .foregroundStyle(.purple)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if let id = contentItem.id {
                        Text("ID: \(id)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let input = contentItem.input {
                        Text("Input:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Display input parameters
                        ForEach(Array(input.keys.sorted()), id: \.self) { key in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• \(key):")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let valueString = contentItem.inputValueString(for: key) {
                                    Text(valueString)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .textSelection(.enabled)
                                } else {
                                    Text("(no value)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .italic()
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

// Tool Result View
struct ToolResultView: View {
    let contentItem: MessageContent
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)

                    Image(systemName: "checkmark.circle")
                        .font(.caption)

                    Text("Tool Result")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)

            if isExpanded {
                if let content = contentItem.content {
                    Text(content)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}
