//
//  DataConvertible.swift
//  TDDTest
//
//  Created by Alina Egorova on 2/1/18.
//  Copyright © 2018 Alina Egorova. All rights reserved.
//

import Foundation

protocol DataConvertible {
    init(data:Data)
    var data:Data { get }
}

extension DataConvertible {
    
    init(data:Data) {
        guard data.count == MemoryLayout<Self>.size else {
            fatalError("data size (\(data.count)) != type size (\(MemoryLayout<Self>.size))")
        }
        self = data.withUnsafeBytes { $0.pointee }
    }
    
    var data: Data {
        var value = self
        return Data(buffer: UnsafeBufferPointer(start: &value, count: 1))
    }
}

extension UInt8: DataConvertible {}
extension UInt16: DataConvertible {}
extension UInt32: DataConvertible {}
extension Int32: DataConvertible {}
extension Int64: DataConvertible {}
extension Double: DataConvertible {}
extension Float: DataConvertible {}

extension UInt32 {
    static func from(bytes: [UInt8]) -> UInt32? {
        guard bytes.count <= 4 else { return nil }
        return bytes
            .enumerated()
            .map { UInt32($0.element) << UInt32($0.offset * 8) }
            .reduce(0, +)
    }
}
