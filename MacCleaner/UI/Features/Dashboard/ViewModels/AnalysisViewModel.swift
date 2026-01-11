import SwiftUI
import Combine
import os

/// ViewModel responsible for AI analysis operations
/// Extracted from MainViewModel for Single Responsibility Principle
@MainActor
final class AnalysisViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAnalyzing: Bool = false
    
    private let ollamaService = OllamaService.shared
    
    // MARK: - Analysis Methods
    
    /// Analyze a single item
    func analyzeItem(_ item: StorageItem, in items: inout [StorageItem]) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        items[index].analysisStatus = .analyzing
        
        let analysis = await ollamaService.analyzeFile(
            name: item.name,
            path: item.url.path,
            size: item.size,
            isDirectory: item.isDirectory
        )
        
        guard let validIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        items[validIndex].analysisStatus = analysis.status
        items[validIndex].analysisDescription = analysis.description
        items[validIndex].analysisConsequences = analysis.consequences
        items[validIndex].safeToDelete = analysis.safeToDelete
    }
    
    /// Analyze multiple selected items
    func analyzeSelectedItems(
        selectedIds: Set<UUID>,
        items: inout [StorageItem]
    ) async {
        isAnalyzing = true
        
        let itemsToAnalyze = items.filter { selectedIds.contains($0.id) }
        
        for item in itemsToAnalyze {
            guard let index = items.firstIndex(where: { $0.id == item.id }) else { continue }
            items[index].analysisStatus = .analyzing
            
            let analysis = await ollamaService.analyzeFile(
                name: item.name,
                path: item.url.path,
                size: item.size,
                isDirectory: item.isDirectory
            )
            
            if let validIndex = items.firstIndex(where: { $0.id == item.id }) {
                items[validIndex].analysisStatus = analysis.status
                items[validIndex].analysisDescription = analysis.description
                items[validIndex].analysisConsequences = analysis.consequences
                items[validIndex].safeToDelete = analysis.safeToDelete
            }
        }
        
        isAnalyzing = false
    }
}
