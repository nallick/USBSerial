//
//  SerialSession.swift
//
//  Copyright © 2019 Purgatory Design. Licensed under the MIT License.
//

import Foundation
import Logging
import SwiftSerial

#if os(macOS)
import Combine
#endif

public class SerialSession {

    public enum Status: Error { case portClosed, portRemoved }

    public typealias BaudRate = SwiftSerial.BaudRate
    public typealias Parity = SwiftSerial.ParityType
    public typealias DataBits = SwiftSerial.DataBitsSize

    public let driver: URL
    public let baudRate: BaudRate
    public let parity: Parity
    public let stopBits: UInt
    public let dataBits: DataBits
    public let logger: Logger?
    public let writeQueue = OperationQueue()
    public let closedNotification: NSNotification.Name?
    public let inputNotification: NSNotification.Name?

    public private(set) var portIsOpen = false

    private let port: SerialPort
    private let readQueue: DispatchQueue

	#if os(macOS)
    @available(macOS 10.15, *) private lazy var subject: PassthroughSubject<UInt8, Error>? = nil
    @available(macOS 10.15, *) public lazy var publisher: AnyPublisher<UInt8, Error>? = nil
	#endif

    /// Initialize a SerialSession.
    ///
    /// - Parameter driver: A file URL specifying the serial device driver file.
    /// - Parameter baudRate: The serial port baud rate.
    /// - Parameter parity: The serial port parity
    /// - Parameter stopBits: The serial port stop bit count.
    /// - Parameter dataBits: The serial port data bit count.
    /// - Parameter inputNotification: The name of the notification to be used to convey input bytes (or nil to omit input notifications).
    /// - Parameter closedNotification: The name of the notification to be used to convey serial port closure (or nil to omit close notifications).
    /// - Parameter readQueue: The queue used for reading from the serial port (or nil for the default).
    /// - Parameter logger: A logger for recording serial events (or nil to omit logging).
    ///
    public init(driver: URL, baudRate: BaudRate = .baud19200, parity: Parity = .none, stopBits: UInt = 1, dataBits: DataBits = .bits8, inputNotification: NSNotification.Name? = nil, closedNotification: NSNotification.Name? = nil, readQueue: DispatchQueue? = nil, logger: Logger? = nil) {
        self.driver = driver
        self.baudRate = baudRate
        self.parity = parity
        self.stopBits = stopBits
        self.dataBits = dataBits
        self.port = SwiftSerial.SerialPort(path: driver.path)

		self.closedNotification = closedNotification
		self.inputNotification = inputNotification
        self.logger = logger
        self.readQueue = readQueue ?? DispatchQueue(label: "SerialPortReadQueue")

        self.writeQueue.maxConcurrentOperationCount = 1
	}

    /// Deinitialize the receiver.
    ///
    deinit {
        if self.portIsOpen {
            self.close()
            self.logger?.info("Serial port released")
        }
    }

    /// Open the receiver by opening the serial port and starting to read from it.
    ///
    /// - Throws: Any errors encountered when opening the serial port.
    ///
    public func open() throws {
        do {
            try self.port.openPort()
            self.port.setSettings(receiveRate: self.baudRate, transmitRate: self.baudRate, minimumBytesToRead: 1, parityType: self.parity, sendTwoStopBits: self.stopBits > 1, dataBitsSize: self.dataBits)

            #if os(macOS)
            if #available(macOS 10.15, *) {
                let subject = PassthroughSubject<UInt8, Error>()
                self.publisher = AnyPublisher<UInt8, Error>(subject)
                self.subject = subject
            }
            #endif

            self.portIsOpen = true
            self.startReading()

            self.logger?.info("Serial port \(self.driver.lastPathComponent) opened")
        } catch {
            self.logger?.error("Serial port \(self.driver.lastPathComponent) failed to open with error: \(error)")
            throw error
        }
    }

    /// Close the receiver by closing the serial port and sending final notifications.
    ///
	public func close() {
        self.close(notify: true)
    }

    /// Send data to the receiver.
    ///
    /// - Parameter data: The data to send.
    ///
    /// - Throws: Any errors encountered when writing to the serial port.
    ///
    public func send(_ data: Data) throws {
        do {
            let bytesWritten = try self.port.writeData(data)
            if bytesWritten != data.count { self.logger?.error("Serial port only wrote \(bytesWritten) of \(data.count) bytes") }
        } catch {
            self.logger?.error("Serial port (\(self.driver.lastPathComponent)) encountered write error: \(error)")
            throw error
        }
    }

    /// Close the serial session by closing the serial port.
    ///
    /// - Parameter notify: Specifies if final notifications are sent.
    ///
    private func close(notify: Bool) {
        if self.portIsOpen {
            self.portIsOpen = false
            self.port.closePort()

            if notify {
                if let notification = self.closedNotification {
                    NotificationCenter.default.post(name: notification, object: Status.portClosed)
                }

                #if os(macOS)
                if #available(macOS 10.15, *) {
                    self.subject?.send(completion: .finished)
                }
                #endif

                self.logger?.info("Serial port \(self.driver.lastPathComponent) closed")
            }
        }
    }

    /// Start an asynchronous task to read from the serial port until it is closed.
    ///
    private func startReading() {
        self.readQueue.async { [weak self] in
            while let self = self, self.portIsOpen {
                do {
                    var byte: UInt8 = 0
                    let bytesRead = try self.port.readBytes(into: &byte, size: 1)
                    if bytesRead > 0 {
						#if os(macOS)
						if #available(macOS 10.15, *) {
							self.subject?.send(byte)
						}
						#endif

						if let notification = self.inputNotification {
                            NotificationCenter.default.post(name: notification, object: byte)
                        }
                    }
                } catch {
                    if error as? PortError == .deviceNotConnected {
                        self.logger?.info("Serial port \(self.driver.lastPathComponent) removed")
						self.close(notify: false)

                        if let notification = self.closedNotification {
                            NotificationCenter.default.post(name: notification, object: Status.portRemoved)
                        }

						#if os(macOS)
						if #available(macOS 10.15, *) {
							self.subject?.send(completion: .failure(SerialSession.Status.portRemoved))
						}
						#endif
					} else {
                        self.logger?.error("Serial port (\(self.driver.lastPathComponent)) encountered read error: \(error)")
                    }
                }
            }
        }
    }
}
