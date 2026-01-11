import Foundation
import os

/// Safe RAM Cleaner using "Memory Pressure" simulation.
/// Unlike dangerous sudo commands (purge), this allocates safe virtual memory
/// to trigger macOS's own memory compressor and file cache cleaner.
actor MemoryCleaner {
    static let shared = MemoryCleaner()
    private let logger = Logger(subsystem: "com.senoldogan.MacCleaner", category: "MemoryCleaner")
    
    /// Allocated pointers to hold memory temporarily
    private var memoryHolders: [UnsafeMutableRawPointer] = []
    
    func cleanMemory() async throws {
        logger.info("Starting Memory Cleaning Process...")
        
        // Get total physical memory
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        // Target: Allocate ~60% of total RAM to force compression of idle apps
        let targetAllocation = UInt64(Double(totalRAM) * 0.60)
        let chunkSize = 100 * 1024 * 1024 // 100 MB chunks
        
        let startTime = Date()
        
        // 1. Rapid Allocation
        var allocated: UInt64 = 0
        while allocated < targetAllocation {
            if Task.isCancelled { break }
            
            // malloc is safer than UnsafeMutableRawPointer.allocate for simple raw bytes here
            let ptr = malloc(Int(chunkSize))
            if let ptr = ptr {
                // Determine write to force physical allocation (dirty the pages)
                memset(ptr, 0, Int(chunkSize))
                memoryHolders.append(ptr)
                allocated += UInt64(chunkSize)
            } else {
                break
            }
            // Small sleep to not freeze UI entirely
            try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms
        }
        
        logger.info("Allocated \(allocated / 1024 / 1024) MB to trigger pressure.")
        
        // 2. Hold momentarily to let OS react
        try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds
        
        // 3. Deallocate (Free)
        for ptr in memoryHolders {
            free(ptr)
        }
        memoryHolders.removeAll()
        
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Memory Cleaning Finished. Duration: \(duration, format: .fixed(precision: 1))s")
    }
}
