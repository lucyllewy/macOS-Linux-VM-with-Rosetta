/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app delegate that sets up and starts the virtual machine.
*/

import Virtualization

let vmBundlePath = NSHomeDirectory() + "/RosettaVM.bundle/"
let mainDiskImagePath = vmBundlePath + "Disk.img"
let efiVariableStorePath = vmBundlePath + "NVRAM"
let machineIdentifierPath = vmBundlePath + "MachineIdentifier"

struct RosettaVMError: Error, LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate, VZVirtualMachineDelegate {

    @IBOutlet var window: NSWindow!

    @IBOutlet weak var virtualMachineView: VZVirtualMachineView!

    private var virtualMachine: VZVirtualMachine!

    private var installerISOPath: URL?

    private var needsInstall = true

    override init() {
        super.init()
    }

#if arch(arm64)
    private func installRosetta() async throws {
        let rosettaAvailability = VZLinuxRosettaDirectoryShare.availability

        switch rosettaAvailability {
        case .notSupported:
            throw RosettaVMError("Rosetta is not supported on your system")

        case .notInstalled:
            do {
                try await VZLinuxRosettaDirectoryShare.installRosetta()
                // Success: The system installs Rosetta on the host system.
            } catch {
                throw RosettaVMError("There was an error installing Rosetta or the installation was cancelled.")
            }

            // TODO: The below `catch` code from Apple sample doesn't seem to work. I don't know why.

            //                } catch let error {
            //                    switch error.code {
            //                    case .networkError:
            //                        // A network error prevented the download from completing successfully.
            //                        fatalError("There was a network error while installing Rosetta. Please try again.")
            //                    case .outOfDiskSpace:
            //                        // Not enough disk space on the system volume to complete the installation.
            //                        fatalError("Your system does not have enuogh disk space to install Rosetta")
            //                    case .userCancelled:
            //                        // The user cancelled the installation.
            //                        break
            //                    case .notSupported:
            //                        // Rosetta isn't supported on the host Mac or macOS version.
            //                        break
            //                    default:
            //                        break // A non installer-related error occurred.
            //                    }
            //                }
            break
        case .installed:
            break // Ready to go.
        @unknown default:
            throw RosettaVMError("Unknown error returned while checking for Rosetta")
        }
    }
#endif

    private func createVMBundle() throws {
        do {
            try FileManager.default.createDirectory(atPath: vmBundlePath, withIntermediateDirectories: false)
        } catch {
            throw RosettaVMError("There was an error creating “GUI Linux VM.bundle“ in your home folder.")
        }
    }

    // Create an empty disk image for the virtual machine.
    private func createMainDiskImage() throws {
        let diskCreated = FileManager.default.createFile(atPath: mainDiskImagePath, contents: nil, attributes: nil)
        if !diskCreated {
            throw RosettaVMError("Could not create the VM's main disk image.")
        }

        guard let mainDiskFileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: mainDiskImagePath)) else {
            throw RosettaVMError("Could not open the VM's main disk image.")
        }

        do {
            // 64 GB disk space.
            try mainDiskFileHandle.truncate(atOffset: 64 * 1024 * 1024 * 1024)
        } catch {
            throw RosettaVMError("Could not truncate the VM's main disk image.")
        }
    }

    // MARK: Create device configuration objects for the virtual machine.

    private func createBlockDeviceConfiguration() throws -> VZVirtioBlockDeviceConfiguration {
        guard let mainDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: mainDiskImagePath), readOnly: false) else {
            throw RosettaVMError("Could not attach the VM's main disk image.")
        }

        let mainDisk = VZVirtioBlockDeviceConfiguration(attachment: mainDiskAttachment)
        return mainDisk
    }

    private func computeCPUCount() -> Int {
        let totalAvailableCPUs = ProcessInfo.processInfo.processorCount

        var virtualCPUCount = totalAvailableCPUs <= 1 ? 1 : totalAvailableCPUs - 1
        virtualCPUCount = max(virtualCPUCount, VZVirtualMachineConfiguration.minimumAllowedCPUCount)
        virtualCPUCount = min(virtualCPUCount, VZVirtualMachineConfiguration.maximumAllowedCPUCount)

        return virtualCPUCount
    }

    private func computeMemorySize() -> UInt64 {
        var memorySize = (4 * 1024 * 1024 * 1024) as UInt64 // 4 GiB
        memorySize = max(memorySize, VZVirtualMachineConfiguration.minimumAllowedMemorySize)
        memorySize = min(memorySize, VZVirtualMachineConfiguration.maximumAllowedMemorySize)

        return memorySize
    }

    private func createAndSaveMachineIdentifier() -> VZGenericMachineIdentifier {
        let machineIdentifier = VZGenericMachineIdentifier()

        // Store the machine identifier to disk so you can retrieve it for subsequent boots.
        try! machineIdentifier.dataRepresentation.write(to: URL(fileURLWithPath: machineIdentifierPath))
        return machineIdentifier
    }

    private func retrieveMachineIdentifier() throws -> VZGenericMachineIdentifier {
        // Retrieve the machine identifier.
        guard let machineIdentifierData = try? Data(contentsOf: URL(fileURLWithPath: machineIdentifierPath)) else {
            throw RosettaVMError("Failed to retrieve the machine identifier data.")
        }

        guard let machineIdentifier = VZGenericMachineIdentifier(dataRepresentation: machineIdentifierData) else {
            throw RosettaVMError("Failed to create the machine identifier.")
        }

        return machineIdentifier
    }

    private func createEFIVariableStore() throws -> VZEFIVariableStore {
        guard let efiVariableStore = try? VZEFIVariableStore(creatingVariableStoreAt: URL(fileURLWithPath: efiVariableStorePath)) else {
            throw RosettaVMError("Failed to create the EFI variable store.")
        }

        return efiVariableStore
    }

    private func retrieveEFIVariableStore() throws -> VZEFIVariableStore {
        if !FileManager.default.fileExists(atPath: efiVariableStorePath) {
            throw RosettaVMError("EFI variable store does not exist.")
        }

        return VZEFIVariableStore(url: URL(fileURLWithPath: efiVariableStorePath))
    }

    private func createUSBMassStorageDeviceConfiguration() throws -> VZUSBMassStorageDeviceConfiguration {
        guard let intallerDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: installerISOPath!, readOnly: true) else {
            throw RosettaVMError("Failed to create installer's disk attachment.")
        }

        return VZUSBMassStorageDeviceConfiguration(attachment: intallerDiskAttachment)
    }

    private func createNetworkDeviceConfiguration() throws -> VZVirtioNetworkDeviceConfiguration {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        networkDevice.attachment = VZNATNetworkDeviceAttachment()

        return networkDevice
    }

    private func createGraphicsDeviceConfiguration() -> VZVirtioGraphicsDeviceConfiguration {
        let graphicsDevice = VZVirtioGraphicsDeviceConfiguration()
        graphicsDevice.scanouts = [
            VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1280, heightInPixels: 720)
        ]

        return graphicsDevice
    }

    private func createInputAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
        let inputAudioDevice = VZVirtioSoundDeviceConfiguration()

        let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
        inputStream.source = VZHostAudioInputStreamSource()

        inputAudioDevice.streams = [inputStream]
        return inputAudioDevice
    }

    private func createOutputAudioDeviceConfiguration() -> VZVirtioSoundDeviceConfiguration {
        let outputAudioDevice = VZVirtioSoundDeviceConfiguration()

        let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStream.sink = VZHostAudioOutputStreamSink()

        outputAudioDevice.streams = [outputStream]
        return outputAudioDevice
    }

    private func createSpiceAgentConsoleDeviceConfiguration() -> VZVirtioConsoleDeviceConfiguration {
        let consoleDevice = VZVirtioConsoleDeviceConfiguration()

        let spiceAgentPort = VZVirtioConsolePortConfiguration()
        spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
        spiceAgentPort.attachment = VZSpiceAgentPortAttachment()
        consoleDevice.ports[0] = spiceAgentPort

        return consoleDevice
    }

    // MARK: Create the virtual machine configuration and instantiate the virtual machine.

    func createVirtualMachine() throws {
        let virtualMachineConfiguration = VZVirtualMachineConfiguration()

        virtualMachineConfiguration.cpuCount = computeCPUCount()
        virtualMachineConfiguration.memorySize = computeMemorySize()

        let platform = VZGenericPlatformConfiguration()
        let bootloader = VZEFIBootLoader()
        let disksArray = NSMutableArray()

        if needsInstall {
            // This is a fresh install: Create a new machine identifier and EFI variable store,
            // and configure a USB mass storage device to boot the ISO image.
            platform.machineIdentifier = createAndSaveMachineIdentifier()
            bootloader.variableStore = try createEFIVariableStore()
            disksArray.add(try createUSBMassStorageDeviceConfiguration())
        } else {
            // The VM is booting from a disk image that already has the OS installed.
            // Retrieve the machine identifier and EFI variable store that were saved to
            // disk during installation.
            platform.machineIdentifier = try retrieveMachineIdentifier()
            bootloader.variableStore = try retrieveEFIVariableStore()
        }

        virtualMachineConfiguration.platform = platform
        virtualMachineConfiguration.bootLoader = bootloader

        disksArray.add(try createBlockDeviceConfiguration())
        guard let disks = disksArray as? [VZStorageDeviceConfiguration] else {
            throw RosettaVMError("Invalid disksArray.")
        }
        virtualMachineConfiguration.storageDevices = disks

        virtualMachineConfiguration.networkDevices = [try createNetworkDeviceConfiguration()]
        virtualMachineConfiguration.graphicsDevices = [createGraphicsDeviceConfiguration()]
        virtualMachineConfiguration.audioDevices = [createInputAudioDeviceConfiguration(), createOutputAudioDeviceConfiguration()]

        virtualMachineConfiguration.keyboards = [VZUSBKeyboardConfiguration()]
        virtualMachineConfiguration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        virtualMachineConfiguration.consoleDevices = [createSpiceAgentConsoleDeviceConfiguration()]

#if arch(arm64)
        let tag = "ROSETTA"
        do {
            let _ = try VZVirtioFileSystemDeviceConfiguration.validateTag(tag)
            let rosettaDirectoryShare = try VZLinuxRosettaDirectoryShare()
            let fileSystemDevice = VZVirtioFileSystemDeviceConfiguration(tag: tag)
            fileSystemDevice.share = rosettaDirectoryShare

            virtualMachineConfiguration.directorySharingDevices = [ fileSystemDevice ]
        } catch {
            throw RosettaVMError("Rosetta is not available")
        }
#endif

        try! virtualMachineConfiguration.validate()
        virtualMachine = VZVirtualMachine(configuration: virtualMachineConfiguration)
    }

    // MARK: Start the virtual machine.

    func configureAndStartVirtualMachine() {
        DispatchQueue.main.async {
            Task { @MainActor in
#if arch(arm64)
                do {
                    try await self.installRosetta()
                } catch let error {
                    print(error.localizedDescription)

                    let alert = NSAlert()
                    alert.messageText = "Failed to install Rosetta"
                    alert.informativeText = error.localizedDescription

                    await alert.beginSheetModal(for: self.window)
                    exit(-1)
                }
#endif

                do {
                    try self.createVirtualMachine()
                } catch let error {
                    print(error.localizedDescription)
                    let alert = NSAlert()
                    alert.messageText = "Failed to create VM"
                    alert.informativeText = "Failed to create VM with error: \(error.localizedDescription)"

                    await alert.beginSheetModal(for: self.window)
                    exit(-1)
                }
                self.virtualMachineView.virtualMachine = self.virtualMachine
                self.virtualMachine.delegate = self
                self.virtualMachine.start(completionHandler: { (result) in
                    switch result {
                    case let .failure(error):
                        print(error.localizedDescription)
                        Task { @MainActor in
                            let alert = NSAlert()
                            alert.messageText = "Failed to start VM"
                            alert.informativeText = "Virtual machine failed to start with error: \(error.localizedDescription)"

                            await alert.beginSheetModal(for: self.window)
                            exit(-1)
                        }
                    default:
                        print("Virtual machine successfully started.")
                    }
                })
            }
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in
            // If "RosettaVM.bundle" doesn't exist, the sample app tries to create
            // one and install Linux onto an empty disk image from the ISO image,
            // otherwise, it tries to directly boot from the disk image inside
            // the "RosettaVM.bundle".
            if !FileManager.default.fileExists(atPath: vmBundlePath) {
                needsInstall = true
                do {
                    try createVMBundle()
                    try createMainDiskImage()
                } catch let error {
                    print(error.localizedDescription)

                    let alert = NSAlert()
                    alert.messageText = "Failed to create VM"
                    alert.informativeText = error.localizedDescription

                    await alert.beginSheetModal(for: self.window)
                    exit(-1)
                }

                let openPanel = NSOpenPanel()
                openPanel.canChooseFiles = true
                openPanel.allowsMultipleSelection = false
                openPanel.canChooseDirectories = false
                openPanel.canCreateDirectories = false

                let result = await openPanel.begin()
                if result == .OK {
                    self.installerISOPath = openPanel.url!
                    self.configureAndStartVirtualMachine()
                } else {
                    print("ISO file not selected")
                    do {
                        try FileManager.default.removeItem(atPath: vmBundlePath)
                    } catch {
                        let message = "Tried to cleanup but could not remove the bundle at: \(vmBundlePath). Please remove it manually as the VM app will crash with the bundle in it's current state."

                        print(message)

                        let alert = NSAlert()
                        alert.messageText = "ISO file not selected"
                        alert.informativeText = message

                        await alert.beginSheetModal(for: self.window)
                        exit(-1)
                    }
                    exit(0)
                }
            } else {
                needsInstall = false
                configureAndStartVirtualMachine()
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        do {
            if self.virtualMachine.canRequestStop == true {
                let alert = NSAlert()
                alert.messageText = "Stopping VM"
                alert.informativeText = "Sent a stop command to the guest operating system. You might need to manually trigger the shutdown within the guest OS if it doesn't shutdown automatically."

                alert.beginSheetModal(for: self.window)

                try self.virtualMachine.requestStop()
                return NSApplication.TerminateReply.terminateCancel
            } else {
                throw RosettaVMError("Unable to request stop")
            }
        } catch let error {
            let message = "Failed to stop VM"

            print(message)

            let alert = NSAlert()
            alert.messageText = "Failed to stop VM"
            alert.informativeText = "Could not automatically shut down the guest operating system: \(error.localizedDescription)"
            alert.addButton(withTitle: "Force close")
            alert.addButton(withTitle: "Continue running")

            var forceClose: NSApplication.TerminateReply = .terminateLater
            alert.beginSheetModal(for: self.window) { (result) in
                switch result {
                case .alertFirstButtonReturn:
                    forceClose = NSApplication.TerminateReply.terminateNow
                    break
                case .alertSecondButtonReturn:
                    forceClose = NSApplication.TerminateReply.terminateCancel
                    break
                default:
                    forceClose = NSApplication.TerminateReply.terminateCancel
                    break
                }
            }
            return forceClose
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: VZVirtualMachineDelegate methods.

    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        let message = "Virtual machine did stop with error: \(error.localizedDescription)"

        print(message)

        let alert = NSAlert()
        alert.messageText = "VM Stopped"
        alert.informativeText = message

        alert.beginSheetModal(for: self.window) { (result) in
            exit(-1)
        }
    }

    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        let message = "Guest did stop virtual machine."
        print(message)
        exit(0)
    }

    func virtualMachine(_ virtualMachine: VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError error: Error) {
        let message = "Network attachment was disconnected with error: \(error.localizedDescription)"

        print(message)

        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "VM network disconnected"
            alert.informativeText = message

            await alert.beginSheetModal(for: self.window)
        }
    }
}
