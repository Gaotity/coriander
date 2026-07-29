import Foundation

/// Shared measurement helpers for the Container App and Keyboard Extension.
enum RimeMeter {
    static let groupID = "group.com.gaotity.coriander"
    static let sharedDirName = "rime/shared"
    static let userDirName = "rime/user"

    static var groupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    /// Resident memory of the current process, in MB.
    static func residentMemoryMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Double(info.resident_size) / 1_048_576
    }

    /// Wall-clock time the current process was started, via the kernel.
    static func processStartTime() -> Date {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        let started = info.kp_proc.p_starttime
        return Date(timeIntervalSince1970: TimeInterval(started.tv_sec) + TimeInterval(started.tv_usec) / 1_000_000)
    }
}
