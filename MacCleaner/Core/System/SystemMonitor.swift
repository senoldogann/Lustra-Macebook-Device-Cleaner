import Foundation
import Combine
import IOKit.ps

/// Monitors System Resources (CPU & RAM)
/// Uses Mach Kernel APIs for low-level stats.
@MainActor
class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()
    
    @Published var cpuUsage: Double = 0.0
    @Published var ramUsage: Double = 0.0 // Percentage
    @Published var usedRAM: String = "0 GB"
    @Published var totalRAM: String = "0 GB"
    
    private var timer: Timer?
    private var lastInfo = host_cpu_load_info()
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        // Run immediately
        updateStats()
        
        // Schedule timer (2 seconds interval to save battery)
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStats()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateStats() {
        self.cpuUsage = getCPUUsage()
        let ram = getRAMUsage()
        self.ramUsage = ram.percentage
        self.usedRAM = ram.used
        self.totalRAM = ram.total
    }
    
    // MARK: - CPU Usage
    private func getCPUUsage() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let userDiff = Double(info.cpu_ticks.0 - lastInfo.cpu_ticks.0)
            let sysDiff  = Double(info.cpu_ticks.1 - lastInfo.cpu_ticks.1)
            let idleDiff = Double(info.cpu_ticks.2 - lastInfo.cpu_ticks.2)
            let niceDiff = Double(info.cpu_ticks.3 - lastInfo.cpu_ticks.3)
            
            let totalTicks = userDiff + sysDiff + idleDiff + niceDiff
            lastInfo = info
            
            if totalTicks > 0 {
                let usage = ((userDiff + sysDiff + niceDiff) / totalTicks) * 100.0
                return min(max(usage, 0.0), 100.0)
            }
        }
        return 0.0
    }
    
    // MARK: - RAM Usage
    private func getRAMUsage() -> (percentage: Double, used: String, total: String) {
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        // Host port
        let hostPort = mach_host_self()
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &size)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            
            // "Active" + "Wired" is roughly what acts as "Used" for users
            // "Compressed" is also technically used.
            let active = UInt64(stats.active_count) * pageSize
            let wired = UInt64(stats.wire_count) * pageSize
            let compressed = UInt64(stats.compressor_page_count) * pageSize
            
            let usedBytes = active + wired + compressed
            let totalBytes = ProcessInfo.processInfo.physicalMemory
            
            let percentage = (Double(usedBytes) / Double(totalBytes)) * 100.0
            
            return (
                percentage: percentage,
                used: ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .memory),
                total: ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .memory)
            )
        }
        
        return (0.0, "0 GB", "0 GB")
    }
}
