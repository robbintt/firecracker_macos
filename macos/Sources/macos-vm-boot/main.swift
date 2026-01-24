import Foundation

struct Arguments {
    var kernelPath: String?
    var rootfsPath: String?
    var memoryMB: Int?
    var cpuCount: Int?
    
    static func parse() -> Arguments? {
        var args = Arguments()
        let arguments = CommandLine.arguments
        var i = 1
        
        while i < arguments.count {
            switch arguments[i] {
            case "--kernel":
                guard i + 1 < arguments.count else {
                    print("Error: --kernel requires a value")
                    return nil
                }
                args.kernelPath = arguments[i + 1]
                i += 2
            case "--rootfs":
                guard i + 1 < arguments.count else {
                    print("Error: --rootfs requires a value")
                    return nil
                }
                args.rootfsPath = arguments[i + 1]
                i += 2
            case "--memory":
                guard i + 1 < arguments.count else {
                    print("Error: --memory requires a value")
                    return nil
                }
                if let memory = Int(arguments[i + 1]) {
                    args.memoryMB = memory
                } else {
                    print("Error: --memory must be an integer")
                    return nil
                }
                i += 2
            case "--cpus":
                guard i + 1 < arguments.count else {
                    print("Error: --cpus requires a value")
                    return nil
                }
                if let cpus = Int(arguments[i + 1]) {
                    args.cpuCount = cpus
                } else {
                    print("Error: --cpus must be an integer")
                    return nil
                }
                i += 2
            case "--help", "-h":
                printUsage()
                return nil
            default:
                print("Error: Unknown argument '\(arguments[i])'")
                return nil
            }
        }
        
        return args
    }
    
    func validate() -> Bool {
        guard let kernelPath = kernelPath else {
            print("Error: --kernel is required")
            return false
        }
        guard let rootfsPath = rootfsPath else {
            print("Error: --rootfs is required")
            return false
        }
        guard let memoryMB = memoryMB else {
            print("Error: --memory is required")
            return false
        }
        
        guard FileManager.default.fileExists(atPath: kernelPath) else {
            print("Error: Kernel file not found: \(kernelPath)")
            return false
        }
        guard FileManager.default.fileExists(atPath: rootfsPath) else {
            print("Error: Rootfs file not found: \(rootfsPath)")
            return false
        }
        guard memoryMB > 0 else {
            print("Error: Memory must be positive")
            return false
        }
        
        let cpus = cpuCount ?? 1
        guard cpus > 0 && cpus <= ProcessInfo.processInfo.processorCount else {
            print("Error: CPUs must be between 1 and \(ProcessInfo.processInfo.processorCount)")
            return false
        }
        
        return true
    }
    
    static func printUsage() {
        print("""
        Usage: macos-vm-boot --kernel <path> --rootfs <path> --memory <MB> [--cpus <N>]
        
        Options:
          --kernel <path>    Path to the kernel image (vmlinux)
          --rootfs <path>    Path to the root filesystem image (rootfs.ext4)
          --memory <MB>      Amount of memory in megabytes
          --cpus <N>         Number of CPUs (default: 1)
          --help, -h         Show this help message
        
        Example:
          macos-vm-boot --kernel vmlinux --rootfs rootfs.ext4 --memory 128 --cpus 2
        """)
    }
}

@main
struct MacOSVMBoot {
    static func main() async {
        guard let args = Arguments.parse() else {
            exit(1)
        }
        
        guard args.validate() else {
            Arguments.printUsage()
            exit(1)
        }
        
        let manager = VMManager(
            kernelPath: args.kernelPath!,
            rootfsPath: args.rootfsPath!,
            memoryMB: args.memoryMB!,
            cpuCount: args.cpuCount ?? 1
        )
        
        do {
            try await manager.run()
            exit(0)
        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }
}
