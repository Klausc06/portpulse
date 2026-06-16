import Foundation
import IOKit
import PortPulseCore
import PortPulseHardware

public protocol PortMonitorDelegate: AnyObject {
    func portMonitor(_ monitor: PortMonitor, didUpdatePorts ports: [USBCPort])
    func portMonitor(_ monitor: PortMonitor, didConnectPort port: USBCPort)
    func portMonitor(_ monitor: PortMonitor, didDisconnectPort portIndex: Int)
}

private final class PortMonitorContext {
    weak var monitor: PortMonitor?
    init(monitor: PortMonitor) { self.monitor = monitor }
}

public final class PortMonitor {
    public weak var delegate: PortMonitorDelegate?
    public var debugLogging = false
    
    private let reader = IOKitReader()
    private var notifyPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var pollTimer: Timer?
    private var previousPorts: [USBCPort] = []
    private var context: PortMonitorContext?
    
    public init() {}
    
    deinit {
        stop()
    }
    
    private func log(_ message: String) {
        guard debugLogging else { return }
        let logPath = "/tmp/portpulse.log"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let handle = FileHandle(forWritingAtPath: logPath) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }
    }
    
    public func start(interval: TimeInterval = 2.0) {
        log("[PortMonitor] Starting with interval: \(interval)s")
        
        // Set up IOKit notification port
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            log("[PortMonitor] ERROR: Failed to create IONotificationPort")
            return
        }
        notifyPort = port
        let runLoopSource = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        
        log("[PortMonitor] IOKit notification port created")
        
        // Use a context object with weak reference to avoid dangling pointer
        let ctx = PortMonitorContext(monitor: self)
        context = ctx
        let contextPtr = Unmanaged.passRetained(ctx).toOpaque()
        
        // Register for USB device add/remove notifications
        let matchingAdd = IOServiceMatching("IOUSBDevice")
        let matchingRemove = IOServiceMatching("IOUSBDevice")
        
        IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            matchingAdd,
            { (rawContext, iterator) in
                guard let rawContext = rawContext else { return }
                let ctx = Unmanaged<PortMonitorContext>.fromOpaque(rawContext).takeUnretainedValue()
                ctx.monitor?.handleDeviceAdded(iterator: iterator)
            },
            contextPtr,
            &addedIterator
        )
        
        IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            matchingRemove,
            { (rawContext, iterator) in
                guard let rawContext = rawContext else { return }
                let ctx = Unmanaged<PortMonitorContext>.fromOpaque(rawContext).takeUnretainedValue()
                ctx.monitor?.handleDeviceRemoved(iterator: iterator)
            },
            contextPtr,
            &removedIterator
        )
        
        // Prime the notifications
        primeIterator(addedIterator)
        primeIterator(removedIterator)
        
        // Start polling for port state changes
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        
        // Initial read
        poll()
    }
    
    public func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        
        if let notifyPort = notifyPort {
            IONotificationPortDestroy(notifyPort)
            self.notifyPort = nil
        }
        
        if addedIterator != IO_OBJECT_NULL {
            IOObjectRelease(addedIterator)
            addedIterator = IO_OBJECT_NULL
        }
        
        if removedIterator != IO_OBJECT_NULL {
            IOObjectRelease(removedIterator)
            removedIterator = IO_OBJECT_NULL
        }
        
        // Balance the retain from passRetained in start()
        if let ctx = context {
            Unmanaged.passUnretained(ctx).release()
            context = nil
        }
    }
    
    public func refresh() -> [USBCPort] {
        let ports = reader.readAllPorts()
        previousPorts = ports
        return ports
    }
    
    private func poll() {
        log("[PortMonitor] poll() called")
        let ports = reader.readAllPorts()
        
        let connectedPorts = ports.filter(\.isConnected)
        let prevConnected = previousPorts.filter(\.isConnected)
        if connectedPorts.count != prevConnected.count {
            log("[PortMonitor] Port count changed: \(prevConnected.count) → \(connectedPorts.count)")
        }
        
        for port in ports where port.isConnected {
            let wasConnected = previousPorts.contains { $0.portIndex == port.portIndex && $0.isConnected }
            if !wasConnected {
                log("[PortMonitor] New connection: Port \(port.portIndex)")
                delegate?.portMonitor(self, didConnectPort: port)
            }
        }
        
        for prev in previousPorts where prev.isConnected {
            let stillConnected = ports.contains { $0.portIndex == prev.portIndex && $0.isConnected }
            if !stillConnected {
                log("[PortMonitor] Disconnection: Port \(prev.portIndex)")
                delegate?.portMonitor(self, didDisconnectPort: prev.portIndex)
            }
        }
        
        previousPorts = ports
        delegate?.portMonitor(self, didUpdatePorts: ports)
    }
    
    private func handleDeviceAdded(iterator: io_iterator_t) {
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        // Trigger immediate poll
        poll()
    }
    
    private func handleDeviceRemoved(iterator: io_iterator_t) {
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        // Trigger immediate poll
        poll()
    }
    
    private func primeIterator(_ iterator: io_iterator_t) {
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }
}
