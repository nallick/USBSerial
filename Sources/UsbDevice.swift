//
//  UsbDevice.swift
//
//  Copyright © 2019 Purgatory Design. Licensed under the MIT License.
//

import Foundation

#if os(macOS)
import IOKit
import IOKit.hid
import IOKit.usb.IOUSBLib
#endif

public enum UsbDevice {

    /// The information to identify a specific USB device.
    ///
    public struct Information: Equatable {
        let idVendor, idProduct, bcdDevice: Int

        public init(idVendor: Int, idProduct: Int, bcdDevice: Int) {
            self.idVendor = idVendor
            self.idProduct = idProduct
            self.bcdDevice = bcdDevice
        }
    }

    /// The directory containing device drivers.
    ///
    public static let driverDirectory = URL(fileURLWithPath: "/dev", isDirectory: true)

#if os(macOS)

    /// Returns the serial numbers of any installed USB devices with the specified information.
    ///
    /// - Parameter information: The USB device information to find serial numbers for (if any).
    ///
    /// - Returns: A list of serial numbers.
    ///
    public static func serialNumbersFor(_ information: UsbDevice.Information) -> [String] {
        var iterator = IOKitIterator()
        guard let matchingDictionary: NSMutableDictionary = IOServiceMatching(kIOUSBDeviceClassName) else { return [] }
        matchingDictionary.addEntries(from: [kUSBVendorID: information.idVendor, kUSBProductID: information.idProduct])
        guard IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDictionary, &iterator) == kIOReturnSuccess else { return [] }

        var result: [String] = []
        while let usbDevice = iterator.next {
            defer { IOObjectRelease(usbDevice) }

            var cfProperties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(usbDevice, &cfProperties, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                let properties: NSDictionary = cfProperties?.takeRetainedValue(),
                let serialNumber = (properties[kIOHIDSerialNumberKey] ?? properties[kUSBSerialNumberString]) as? String
                else { continue }
            result.append(serialNumber)
        }

        return result
    }

    /// Returns the file URLs of the device driver files for USB devices with the specified information.
    ///
    /// - Parameter information: The USB device information to find serial numbers for (if any).
    ///
    /// - Returns: A list of device driver file URLs.
    ///
    public static func driversWithInformation(_ information: UsbDevice.Information) -> [URL] {
        let serialNumbers = UsbDevice.serialNumbersFor(information)
        return serialNumbers.map { self.driverUrlFor(serialNumber: $0 )}
    }

    /// Returns the device driver URL for a device with a specified serial number.
    ///
    /// - Parameter serialNumber: The USB device serial number.
    ///
    /// - Returns: The USB device driver URL.
    ///
    /// - Note: The device driver may or may not exist.
    ///
    public static func driverUrlFor(serialNumber: String) -> URL {
        return self.driverDirectory.appendingPathComponent("cu.usbserial-\(serialNumber)")
    }

#elseif os(Linux)

    /// The directory containing device driver information.
    ///
    public static let driverInfoDirectory = URL(fileURLWithPath: "/sys/bus/usb-serial/devices", isDirectory: true)

    /// Cached information about all known USB devices, as of the most recent update.
    ///
    public private(set) static var deviceInformation: [String: UsbDevice.Information] = { UsbDevice.currentDeviceInformation() }()

    /// Returns the information for a specific USB device driver.
    ///
    /// - Parameter driver: The device driver file.
    ///
    /// - Returns: The USB device information (if any).
    ///
    public static func information(for driver: URL) -> UsbDevice.Information? {
        let productKey = "PRODUCT="
        let driverInfo = driver.appendingPathComponent("../uevent")
        let fileContents = try? Data(contentsOf: driverInfo)
        guard let fileData = fileContents,
            let fileString = String(data: fileData, encoding: .utf8),
            let id = fileString
                .split(separator: "\n")
                .first(where: { $0.hasPrefix(productKey) })?
                .dropFirst(productKey.count)
                .split(separator: "/")
                .compactMap({ string in Int(string, radix: 16) }),
            id.count == 3
            else { return nil }
        return UsbDevice.Information(idVendor: id[0], idProduct: id[1], bcdDevice: id[2])
    }

    /// Returns the file URLs of the device driver files for USB devices with the specified information.
    ///
    /// - Parameter information: The USB device information to find serial numbers for (if any).
    ///
    /// - Returns: A list of device driver file URLs.
    ///
    public static func driversWithInformation(_ information: UsbDevice.Information) -> [URL] {
        let driverNames = UsbDevice.deviceInformation.filter({ $0.1 == information }).keys
        return driverNames.map { self.driverDirectory.appendingPathComponent($0) }
    }

    /// Update the cache containing the current information about all known USB devices.
    ///
    public static func updateDeviceInformation() {
        self.deviceInformation = self.currentDeviceInformation()
    }

    /// Returns the current information about all known USB devices.
    ///
    /// - Returns: The current USB device information for each driver.
    ///
    private static func currentDeviceInformation() -> [String: UsbDevice.Information] {
        guard let drivers = try? FileManager.default.contentsOfDirectory(at: self.driverInfoDirectory, includingPropertiesForKeys: nil) else { return [:] }
        return drivers.reduce(into: [:]) { result, driver in
            guard let deviceInfo = self.information(for: driver) else { return }
            result[driver.lastPathComponent] = deviceInfo
        }
    }

#endif
}
