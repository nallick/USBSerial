//
//  IOKitIterator.swift
//
//  Copyright © 2019 Purgatory Design. Licensed under the MIT License.
//

#if os(macOS)

import IOKit

public typealias IOKitIterator = io_iterator_t

extension IOKitIterator {

    /// Initialize a starting IOKit iterator.
    ///
    public init() {
        self = 0
    }

    /// Specify if the receiver is valid.
    ///
    /// - Returns: The valid state of the receiver.
    ///
    public var isValid: Bool {
        return IOIteratorIsValid(self) != 0
    }

    /// Returns the receiver's next iterative object and increment the receiver.
    ///
    /// - Returns: The next IOKit object (if any).
    ///
    public var next: io_object_t? {
        let result = IOIteratorNext(self)
        return (result != 0) ? result : nil
    }

    /// Reset the receiver at the start.
    ///
    public func reset() {
        IOIteratorReset(self)
    }
}

#endif
