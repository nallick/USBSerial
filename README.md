# USBSerial

Provides RS232 serial connections for macOS and Linux using USB-Serial adaptors. The input stream and errors are provided via NotificationManager notifications or a Combine publisher (when available). If logging is desired, a swift-log logger can be provided to the SerialSession.

### For example:
````
#if os(macOS)
let serialDeviceInfo = UsbDevice.Information(idVendor: 0x0403, idProduct: 0x6001, bcdDevice: 0x0600)    // FTDI USB-Serial
#else
let serialDeviceInfo = UsbDevice.Information(idVendor: 0x067B, idProduct: 0x2303, bcdDevice: 0x0400)    // Prolific USB-Serial
#endif

let drivers = UsbDevice.driversWithInformation(serialDeviceInfo)
guard let driver = drivers.first else { fatalError("No USB-Serial devices found") }

let inputNotification = NSNotification.Name(rawValue: driver.lastPathComponent + "-input")
let closedNotification = NSNotification.Name(rawValue: driver.lastPathComponent + "-closed")

let inputToken = NotificationCenter.default.addObserver(forName: inputNotification, object: nil, queue: .main)  { byte in
    // handle the input byte
}

let closedToken = NotificationCenter.default.addObserver(forName: closedNotification, object: nil, queue: .main)  { reason in
    // handle the port closing (e.g., the USB device was removed)
}

let serialSession = SerialSession(driver: driver, inputNotification: inputNotification, closedNotification: closedNotification)
````

### Use:

To add USBSerial to your project, declare a dependency in your Package.swift file,
````
.package(url: "https://github.com/nallick/USBSerial.git", from: "1.0.0"),
````
and add the dependency to your target:
````
.target(name: "MyProjectTarget", dependencies: ["USBSerial"]),
````

### Dependencies:

Thank you to the creators of the following Swift packages:

>[swift-log](https://github.com/apple/swift-log) from Apple

>[SwiftSerial](https://github.com/yeokm1/SwiftSerial) from Yeo Kheng Meng