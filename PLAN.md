# VanDamme - Claude JSONL Viewer for macOS

## Overview
A macOS app to view Claude's `.jsonl` conversation files with drag-and-drop support, persistent storage, and chat-style display.

## Architecture

### Data Models (SwiftData)
1. **Conversation Model** (replaces current `Item.swift`)
   - `id: UUID`
   - `sessionId: String` (from JSONL)
   - `title: String` (initially sessionId, supports renaming)
   - `createdAt: Date`
   - `filePath: String?` (optional reference to original file)
   - `messages: [Message]` (relationship)

2. **Message Model** (implemented)
   - `uuid: String` (from JSONL)
   - `parentUuid: String?`
   - `messageType: String` (stored as String, with MessageType enum for type-safe access)
   - `role: String` (stored as String, with MessageRole enum for type-safe access)
   - `timestamp: Date`
   - `contentData: Data?` (JSON-encoded array of MessageContent)
   - `model: String?` (for assistant messages)
   - `tokenUsageData: Data?` (JSON-encoded TokenUsage)
   - `isSidechain: Bool`
   - `conversation: Conversation?` (relationship)
   - Computed properties: `typeEnum`, `roleEnum`, `content`, `tokenUsage`, `plainTextContent`

### Views

1. **ContentView.swift** (update existing)
   - Add drag-and-drop handler for `.jsonl` files
   - Update sidebar to show conversation list with titles
   - Add delete/rename functionality
   - Route to ConversationDetailView when selected

2. **ConversationDetailView.swift** (new)
   - Chat-style message display
   - Differentiate user/assistant/system messages visually
   - Collapsible sections for tool uses and system messages
   - Show metadata (timestamps, model, tokens) on demand

3. **MessageBubbleView.swift** (implemented)
   - ✅ Individual message component with rich formatting
   - ✅ Support for text content with selection
   - ✅ Collapsible tool_use/tool_result display
   - ✅ Timestamp and metadata display (toggleable)
   - ✅ Visual differentiation by message type (user/assistant/system)
   - ✅ Token usage display
   - Sub-components:
     - `ContentItemView`: Routes content types to appropriate views
     - `ToolUseView`: Displays tool invocations with parameters
     - `ToolResultView`: Displays tool outputs

4. **ConversationDetailView.swift** (implemented)
   - ✅ Full conversation view with scrollable message list
   - ✅ Conversation header with title, date, message count
   - ✅ Session ID display
   - ✅ Lazy loading for performance
   - ✅ Preview support with sample data

### Utilities

1. **JSONLParser.swift** (implemented)
   - ✅ Parse `.jsonl` file line-by-line
   - ✅ Convert to Conversation + Message models
   - ✅ Handle malformed lines gracefully (queue-operations, null content)
   - ✅ Extract sessionId and group messages
   - ✅ Duplicate detection (checks existing sessionId)
   - ✅ Support for user/assistant messages, tool uses, token usage

2. **FileDropDelegate.swift** (implemented)
   - ✅ Handle drag-and-drop operations
   - ✅ Validate `.jsonl` file type
   - ✅ Trigger parsing and storage
   - ✅ Visual feedback for drag-over state
   - ✅ Error handling with user-friendly messages
   - ✅ Loading state management

## Implementation Steps

### ✅ Phase 1: Data Layer (COMPLETE)
1. ✅ Update `Item.swift` → `Conversation.swift` with new schema
2. ✅ Create `Message.swift` model with enums for type/role
3. ✅ Update `VanDammeApp.swift` model container with both models
4. ✅ Create `JSONLParser.swift` utility

**Implemented:**
- `Conversation.swift`: SwiftData model with sessionId, title, messages relationship
- `Message.swift`: SwiftData model with MessageType/MessageRole enums, JSON content storage
- `JSONLParser.swift`: Full JSONL parser with support for user/assistant messages, tool uses, token usage
- Parser handles queue-operations, null content, and malformed lines gracefully
- Duplicate detection prevents re-importing same conversation

### ✅ Phase 1.1: Testing (COMPLETE)

1. ✅ Comprehensive test suite validating de-/serialization
   - `testJSONLParserDeserializesCorrectly`: Validates 73 messages parsed correctly
   - `testJSONLParserHandlesDuplicates`: Confirms duplicate detection works
   - `testMessageContentSerialization`: Tests content structure encoding
   - `testTokenUsageSerialization`: Tests token usage encoding
   - All tests passing with real Claude JSONL data

### ✅ Phase 2: File Handling (COMPLETE)
1. ✅ Implement `FileDropDelegate.swift` for drag-and-drop
2. ✅ Add drop zone to `ContentView.swift`
3. ✅ Wire up parser to create SwiftData objects
4. ✅ Handle duplicate imports (check sessionId)

**Implemented:**
- `FileDropDelegate.swift`: Full drag-and-drop support with validation and error handling
- `ContentView.swift`: Complete UI with conversation list, drop zone, rename/delete functionality
- `DropZoneView`: Visual drop zone with animated feedback
- Error alerts and loading indicators
- Async file import with progress feedback

**Features:**
- Drag & drop `.jsonl` files anywhere on sidebar
- Visual feedback (highlighted drop zone, loading spinner)
- Context menu for rename/delete operations
- Duplicate detection (prevents re-importing same sessionId)
- Empty state messaging

### ✅ Phase 3: UI - Sidebar (COMPLETE - integrated with Phase 2)
1. ✅ Update sidebar in `ContentView.swift` to show conversation titles
2. ✅ Add context menu for rename/delete
3. ✅ Show conversation metadata (date, message count)

**Note:** Phase 3 was completed as part of Phase 2 implementation. All sidebar features are functional.

### ✅ Phase 4: UI - Conversation Display (COMPLETE)
1. ✅ Create `ConversationDetailView.swift`
2. ✅ Create `MessageBubbleView.swift` for individual messages
3. ✅ Implement chat-style layout (ScrollView with LazyVStack)
4. ✅ Add visual differentiation for user vs assistant
5. ✅ Implement collapsible tool use sections
6. ✅ Add metadata display (model, tokens, timestamps)

**Implemented:**
- `ConversationDetailView.swift`: Full conversation view with header and chronological message display
- `MessageBubbleView.swift`: Individual message component with rich formatting
- `ContentItemView`: Routes different content types (text, tool_use, tool_result)
- `ToolUseView`: Collapsible tool invocation display with parameters
- `ToolResultView`: Collapsible tool result display

**Features:**
- Chat-style message bubbles with visual differentiation:
  - User messages: Green background with person icon
  - Assistant messages: Blue background with sparkles icon
  - Tool Result messages: Orange background with bidirectional arrow icon
  - System messages: Gray background
- Collapsible tool use sections showing:
  - Tool name and ID
  - Input parameters as key-value pairs
  - Purple accent color with wrench icon
- Collapsible tool result sections showing:
  - Tool output/results
  - Orange accent color with checkmark icon
- Metadata display (toggleable per message):
  - Token usage (input, output, cache reads)
  - Message UUID
  - Model name and timestamp
- Text selection enabled for all content
- Lazy loading for performance with large conversations

### ✅ Phase 5: AI Title Generation (COMPLETE)
1. ✅ Create TitleGenerator utility using FoundationModels
2. ✅ Integrate auto-title generation into JSONLParser
3. ✅ Generate titles from first 4 messages of conversation

**Implemented:**
- `TitleGenerator.swift`: Uses Apple's on-device Foundation Models to generate concise conversation titles
- Automatic title generation during JSONL import
- Falls back to sessionId if generation fails or model unavailable
- Titles are 3-6 words, descriptive, based on conversation context

### Phase 6: Polish
1. Add empty states (no conversations, no selection)
2. Add loading indicators during parsing
3. Error handling and user feedback
4. Test with large JSONL files
5. Collapsible XML tags in messages

## Future Enhancements (Not in MVP)
- Search within conversations
- Export conversations
- Multi-file drop support
- Syntax highlighting for code blocks in messages
- Filter by date/model/type

## Technical Decisions
- **SwiftData**: Already configured, perfect for local persistence
- **NavigationSplitView**: Already in place, ideal for sidebar + detail
- **JSON Content Storage**: Store message content as `Data` to handle varying structures flexibly
- **Session-based grouping**: Use `sessionId` to group messages into conversations
- **Lazy loading**: Only parse and display messages for selected conversation
