import SwiftUI
import Combine

/// ViewModel responsible for item selection state
/// Extracted from MainViewModel for Single Responsibility Principle
@MainActor
final class SelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedItems: Set<UUID> = []
    @Published var showDeleteConfirmation: Bool = false
    @Published var itemToDelete: StorageItem?
    @Published var isDiscardSectionExpanded: Bool = true
    
    // MARK: - Computed Properties
    
    var selectedItemsCount: Int {
        selectedItems.count
    }
    
    func totalSelectedSize(from categories: [StorageCategory]) -> Int64 {
        allSelectedItems(from: categories).reduce(0) { $0 + $1.size }
    }
    
    func allSelectedItems(from categories: [StorageCategory]) -> [StorageItem] {
        categories.flatMap { $0.items }.filter { selectedItems.contains($0.id) }
    }
    
    func formattedSelectedSize(from categories: [StorageCategory]) -> String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize(from: categories), countStyle: .file)
    }
    
    // MARK: - Selection Methods
    
    func toggleSelection(_ item: StorageItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    func selectAll(from items: [StorageItem]) {
        for item in items {
            selectedItems.insert(item.id)
        }
    }
    
    func deselectAll() {
        selectedItems.removeAll()
    }
    
    func isSelected(_ item: StorageItem) -> Bool {
        selectedItems.contains(item.id)
    }
    
    // MARK: - Delete Confirmation
    
    func requestDeleteConfirmation(for item: StorageItem? = nil) {
        itemToDelete = item
        showDeleteConfirmation = true
    }
    
    func cancelDelete() {
        itemToDelete = nil
        showDeleteConfirmation = false
    }
    
    /// Performs the actual deletion and returns the count of deleted items
    func performDeletion(from categories: inout [StorageCategory]) -> Int {
        let itemsToRemove = allSelectedItems(from: categories)
        var deletedCount = 0
        
        for item in itemsToRemove {
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                deletedCount += 1
            } catch {
                print("DEBUG: Failed to delete \(item.name): \(error.localizedDescription)")
            }
        }
        
        // Remove deleted items from categories
        for i in 0..<categories.count {
            categories[i].items.removeAll { selectedItems.contains($0.id) }
            categories[i].size = categories[i].items.reduce(0) { $0 + $1.size }
        }
        
        selectedItems.removeAll()
        itemToDelete = nil
        showDeleteConfirmation = false
        
        return deletedCount
    }
}
