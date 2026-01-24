import Foundation
import Virtualization

class VMManager: NSObject {
    private let kernelPath: String
    private let rootfsPath: String
    private let memoryMB: Int
    private let cpuCount: Int
    private let noNetwork: Bool
    
    private var virtualMachine: VZVirtualMachine?
    private var shouldStop = false
    
    init(kernelPath: String, rootfsPath: String, memoryMB: Int, cpuCount: Int, noNetwork: Bool = false) {
        self.kernelPath = kernelPath
        self.rootfsPath = rootfsPath
        self.memoryMB = memoryMB
        self.cpuCount = cpuCount
        self.noNetwork = noNetwork
        super.init()
    }
    
    func run() async throws {
        let configuration = try createVMConfiguration()
        
        try configuration.validate()
        
        virtualMachine = VZVirtualMachine(configuration: configuration)
        virtualMachine?.delegate = self
        
        print("Starting VM...")
        print("Kernel: \(kernelPath)")
        print("Rootfs: \(rootfsPath)")
        print("Memory: \(memoryMB) MB")
        print("CPUs: \(cpuCount)")
        print("---")
        
        try await virtualMachine?.start()
        
        // Wait for VM to stop
        while !shouldStop {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        print("---")
        print("VM stopped")
    }
    
    private func createVMConfiguration() throws -> VZVirtualMachineConfiguration {
        let configuration = VZVirtualMachineConfiguration()
        
        // CPU configuration
        configuration.cpuCount = cpuCount
        
        // Memory configuration
        let memorySize = UInt64(memoryMB) * 1024 * 1024
        configuration.memorySize = memorySize
        
        // Boot loader configuration
        let bootloader = VZLinuxBootLoader(kernelURL: URL(fileURLWithPath: kernelPath))
        bootloader.commandLine = "console=hvc0 root=/dev/vda rw"
        configuration.bootLoader = bootloader
        
        // Storage configuration
        let diskAttachment = try VZDiskImageStorageDeviceAttachment(
            url: URL(fileURLWithPath: rootfsPath),
            readOnly: false
        )
        let blockDevice = VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)
        configuration.storageDevices = [blockDevice]
        
        // Console configuration
        let consoleDevice = VZVirtioConsoleDeviceConfiguration()
        let consolePort = VZVirtioConsolePortConfiguration()
        consolePort.isConsole = true
        
        let inputFileHandle = FileHandle.standardInput
        let outputFileHandle = FileHandle.standardOutput
        let serialPortAttachment = VZFileHandleSerialPortAttachment(
            fileHandleForReading: inputFileHandle,
            fileHandleForWriting: outputFileHandle
        )
        consolePort.attachment = serialPortAttachment
        consoleDevice.ports[0] = consolePort
        configuration.consoleDevices = [consoleDevice]
        
        // Entropy device for /dev/random
        let entropyDevice = VZVirtioEntropyDeviceConfiguration()
        configuration.entropyDevices = [entropyDevice]
        
        // Traditional memory balloon device
        let memoryBalloonDevice = VZVirtioTraditionalMemoryBalloonDeviceConfiguration()
        configuration.memoryBalloonDevices = [memoryBalloonDevice]
        
        // Network device (optional)
        if !noNetwork {
            let networkDevice = VZVirtioNetworkDeviceConfiguration()
            networkDevice.attachment = VZNATNetworkDeviceAttachment()
            configuration.networkDevices = [networkDevice]
        }
        
        return configuration
    }
}

extension VMManager: VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        shouldStop = true
    }
    
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        print("VM stopped with error: \(error)")
        shouldStop = true
    }
}
