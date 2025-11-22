//
//  FileDropDelegate.swift
//  VanDamme
//
//  Created by Nick Sillik on 11/22/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FileDropDelegate: DropDelegate {
    let modelContext: ModelContext
    @Binding var isTargeted: Bool
    @Binding var errorMessage: String?
    @Binding var isImporting: Bool

    func validateDrop(info: DropInfo) -> Bool {
        // Check if the drop contains file URLs
        return info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false

        guard let itemProvider = info.itemProviders(for: [.fileURL]).first else {
            errorMessage = "No file found in drop"
            return false
        }

        isImporting = true

        itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
            DispatchQueue.main.async {
                defer { isImporting = false }

                if let error = error {
                    errorMessage = "Error loading file: \(error.localizedDescription)"
                    return
                }

                guard let urlData = urlData as? Data,
                      let url = URL(dataRepresentation: urlData, relativeTo: nil) else {
                    errorMessage = "Invalid file URL"
                    return
                }

                // Validate file extension
                guard url.pathExtension == "jsonl" else {
                    errorMessage = "Please drop a .jsonl file"
                    return
                }

                // Parse the file
                do {
                    let conversation = try JSONLParser.parse(fileURL: url, into: modelContext)
                    print("✅ Successfully imported conversation: \(conversation.sessionId)")
                    errorMessage = nil
                } catch {
                    errorMessage = "Failed to parse file: \(error.localizedDescription)"
                }
            }
        }

        return true
    }
}
