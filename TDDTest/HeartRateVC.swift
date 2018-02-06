//
//  HeartRateVC.swift
//  TDDTest
//
//  Created by Alina Egorova on 2/6/18.
//  Copyright © 2018 Alina Egorova. All rights reserved.
//

import UIKit
import CoreBluetooth

class HeartRateVC: UIViewController {
    
    @IBOutlet weak var heartRateLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var measureButton: UIButton!
    
    var manager: CBCentralManager!
    var miBand: CBPeripheral!
    
    private let heartRateServiceUUID = "180D"
    private let heartRateCharacteristicUUID = "2A37"
    private let heartRateControlCharacteristicUUID = "2A39"
    private let commandStartHeartRateMeasurement: [UInt8] = [0x15, 0x1, 0x1]//[0x01]//[0x15, 0x2, 0x1]//[21, 2, 1]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "My MiBand 2"
        
        startDiscoverServices()
    }
    
    func setNavigationBar() {
        
        let disconnectButton = UIBarButtonItem(title: "Disconnect", style: .plain, target: self, action: #selector(disconnect(_:)))
        disconnectButton.isEnabled = false
        navigationItem.rightBarButtonItem = disconnectButton
    }
    
    func startDiscoverServices() {
        manager.delegate = self
        miBand.delegate = self
        miBand.discoverServices(nil)
    }
    
    func cancelConnection() {
        manager.cancelPeripheralConnection(miBand)
        manager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    // MARK: - Actions
    
    @objc func disconnect(_ sender: UIBarButtonItem) {
        cancelConnection()
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func measureHeartRate(_ sender: UIButton) {
        guard let hrControlPoint = miBand.services?.first(where: { $0.uuid.uuidString == heartRateServiceUUID })?
                .characteristics?.first(where: { $0.uuid.uuidString == heartRateControlCharacteristicUUID }) else {
                    print("Nothing to measure")
                    return
        }
//        miBand.writeValue(Data(bytes: [0x15, 0x2, 0x1]), for: hrControlPoint, type: .withResponse)
        measureHeartRate(characteristic: hrControlPoint)
    }
    
    // MARK: - Convert values
    
    func getBattery(batteryData: Data) -> Int {
        print("--- UPDATING Battery Data..")
        
        var buffer = [UInt8](batteryData)
        print("\(buffer[0])% charged")
        
        return Int(buffer[0])
    }
    
    func setTime(currentTimeData: Data) {
        print("--- UPDATING Time..")
        
        var buffer = [UInt8](currentTimeData)
        
        let yearData = Data(bytes: buffer[0...1])
        let year = UInt16(littleEndian: yearData.withUnsafeBytes { $0.pointee })
        let month = Int(buffer[2])
        let day = Int(buffer[3])
        let hours = Int(buffer[4])
        let minutes = Int(buffer[5])
        let seconds = Int(buffer[6])
        
        DispatchQueue.main.async {
            self.timeLabel.text = String(format: "%@:%@:%@ %@.%@.%@",
                                                hours > 9 ? "\(hours)" : "0\(hours)",
                                                minutes > 9 ? "\(minutes)" : "0\(minutes)",
                                                seconds > 9 ? "\(seconds)" : "0\(seconds)",
                                                day > 9 ? "\(day)" : "0\(day)",
                                                month > 9 ? "\(month)" : "0\(month)",
                                                "\(year)")
        }
    }
    
    func getSteps(data: Data) -> UInt32 {
        
        print("--- UPDATING Steps ..")
        return UInt32(littleEndian: data.withUnsafeBytes { $0.pointee })
        
        //var buffer = [UInt8](data)
        //let partData = Data(bytes: buffer[0...1])
        //return UInt32(littleEndian: partData.withUnsafeBytes { $0.pointee })
        
        //var buffer = [UInt8](data)
        //return (((UInt32(buffer[0] & 255) | (UInt32(buffer[1] & 255) << 8)) | UInt32(buffer[2] & 255)) | (UInt32(buffer[3] & 255) << 24))
        
        //let steps = (UInt16(buffer[1] & 255) | (UInt16(buffer[2] & 255) << 8))
        //let distance = (((UInt32(buffer[5] & 255) | (UInt32(buffer[6] & 255) << 8)) | UInt32(buffer[7] & 255)) | (UInt32(buffer[8] & 255) << 24));
        //let calories = (((UInt32(buffer[9] & 255) | (UInt32(buffer[10] & 255) << 8)) | UInt32(buffer[11] & 255)) | (UInt32(buffer[12] & 255) << 24));
    }
    
    func measureHeartRate(characteristic: CBCharacteristic) {
//        if let service = peripheral.services?.first(where: {$0.uuid == MiBand2Service.UUID_SERVICE_HEART_RATE}), let characteristic = service.characteristics?.first(where: {$0.uuid == MiBand2Service.UUID_CHARACTERISTIC_HEART_RATE_CONTROL}){
        print(characteristic.getProperties())
            //let data = Data(bytes: commandStartHeartRateMeasurement, count: commandStartHeartRateMeasurement.count)
        
        let data = Data(bytes: commandStartHeartRateMeasurement)
            miBand.writeValue(data, for: characteristic, type: .withResponse)
//        }
    }
    
    func getHeartRate(heartRateData:Data) {
        print("--- UPDATING Heart Rate..")
        var buffer = [UInt8](repeating: 0x00, count: heartRateData.count)
        heartRateData.copyBytes(to: &buffer, count: buffer.count)
        
        var bpm: UInt16?
        if (buffer.count >= 2){
            if (buffer[0] & 0x01 == 0){
                bpm = UInt16(buffer[1]);
            } else {
                bpm = UInt16(buffer[1]) << 8
                bpm =  bpm! | UInt16(buffer[2])
            }
        }
        
        if let actualBpm = bpm {
            heartRateLabel.text = "\(Int(actualBpm))"
        } else {
            heartRateLabel.text = "\(Int(bpm!))"
        }
    }
    
    private func heartRate(from characteristic: CBCharacteristic) {
        guard let characteristicData = characteristic.value else { return }
        let byteArray = [UInt8](characteristicData)
        
        let firstBitValue = byteArray[0] & 0x01
        if firstBitValue == 0 {
            // Heart Rate Value Format is in the 2nd byte
            heartRateLabel.text = "\(Int(byteArray[1]))"
        } else {
            // Heart Rate Value Format is in the 2nd and 3rd bytes
            heartRateLabel.text = "\((Int(byteArray[1]) << 8) + Int(byteArray[2]))"
        }
    }
}

extension HeartRateVC: CBPeripheralDelegate {
    
    // Discovered peripheral services
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services! {
            debugPrint("Service: ", service.uuid)
            print("Service: \(service.uuid), uuid: \(service.uuid.uuidString)")
            
            if service.uuid.uuidString == heartRateServiceUUID {
                peripheral.discoverCharacteristics(nil, for: service)
            } else if service.uuid.uuidString == "FEE0" {
                peripheral.discoverCharacteristics(nil, for: service)
            } else {
                peripheral.discoverCharacteristics(nil, for: service) 
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        debugPrint("Enabling ...")
        
        // Look at provided characteristics
        for characteristic in service.characteristics! {
            print("Characteristic: \(characteristic.uuid), uuid: \(characteristic.uuid.uuidString)")
            
            if characteristic.uuid.uuidString == "2A2B" {
                peripheral.readValue(for: characteristic)
                
            } else if characteristic.uuid.uuidString == "00000004-0000-3512-2118-0009AF100700" {
                peripheral.readValue(for: characteristic)
                
            } else if characteristic.uuid.uuidString == heartRateCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
                
            } else if characteristic.uuid.uuidString == heartRateControlCharacteristicUUID {
                peripheral.readValue(for: characteristic)
            
            
//            if characteristic.uuid.uuidString == "FF06" {
//                print("READING STEPS")
//                peripheral.readValue(for: characteristic)
//
//            } else if characteristic.uuid.uuidString == "FF0C" {
//                print("READING BATTERY")
//                peripheral.readValue(for: characteristic)
//
//            } else if characteristic.uuid.uuidString == "FF02" {
//                print("READING DEVICE NAME")
//                peripheral.readValue(for: characteristic)
//
//            } else if characteristic.uuid.uuidString == "FF01" {
//                print("READING DEVICE INFO")
//                peripheral.readValue(for: characteristic)
//
//            } else if characteristic.uuid.uuidString == "FF04" {
//                print("READING USER INFO")
//                peripheral.readValue(for: characteristic)
//
            } else if characteristic.uuid.uuidString == "FF0D" {
                print("TEST")
                let value: [UInt8] = [0x01]
                let data = Data(bytes: value)
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
                
            } else {
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }
    
    // Data arrived from peripheral
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        print("\n_________________________")
        
        print("Data for \(characteristic.uuid.uuidString)")
        
        guard let value = characteristic.value else { return }
        
        var bytesArray = [UInt8](repeating: 0, count: value.count)
        value.copyBytes(to: &bytesArray, count: value.count)
        print("Bytes array: \(bytesArray)")
        
        let data = Data(bytes: bytesArray)
        
        guard !bytesArray.isEmpty else { return }
        
        if characteristic.uuid.uuidString == heartRateCharacteristicUUID {
            getHeartRate(heartRateData: value)
            
        } else if characteristic.uuid.uuidString == "2A2B" {
            setTime(currentTimeData: value)
        
        } else if characteristic.uuid.uuidString == "FF06" {
            let steps = getSteps(data: value)
            print("Steps: \(steps)")
            
        } else if characteristic.uuid.uuidString == "FF0C" {
            let data = NSData(bytes: [UInt8(bytesArray[0])], length: MemoryLayout<UInt8>.size)
            var target: UInt8 = 0
            data.getBytes(&target, length: MemoryLayout.size(ofValue: data))
            print("\(target)% charged")
            // Same
            //getBattery(batteryData: value)
            
        } else if characteristic.uuid.uuidString == "FF01" {
            let u16: UInt8 = data.subdata(in: 0..<4).withUnsafeBytes{ $0.pointee }
            print("\(u16) device id")
            
            //            let data = NSData(bytes: [[UInt8](bytesArray[0...3])], length: MemoryLayout<UInt16>.size)
            //            var target: UInt16 = 0
            //            data.getBytes(&target, length: MemoryLayout.size(ofValue: data))
            //            print("\(target) device id")
            //            print("\nHexa string: \( bytesArray[0...3].map{ String(format: "%02x", $0) }.joined(separator: ""))")
        } else if characteristic.uuid.uuidString == "FF02" {
            print("String: \(String(bytes: value, encoding: String.Encoding.utf8) ?? "Can't convert into string")")
        }
        //
        //        print("\nValue from characteristic UUID: \(characteristic.uuid)\n")
        //
        //        print(characteristic.value ?? "Characteristic has no value")
        //
        //        if let value = characteristic.value {
        //
        //            // Get bytes into string
        //            print("\nString: \(String(bytes: value, encoding: String.Encoding.utf8) ?? "Can't convert into string")")
        //
        //            print("\nHexa string: \( value.map{ String(format: "%02x", $0) }.joined(separator: ""))")
        //
        //            var bytesArray = [UInt8](repeating: 0, count: value.count)
        //            value.copyBytes(to: &bytesArray, count: value.count)
        //            print("\nBytes array: \(bytesArray)")
        //
        //            let characters = bytesArray.map { Character(UnicodeScalar($0)) }
        //            print("\nUInt8 string: \(String(Array(characters)))")
        //
        //            //            let bigEndianValue = bytesArray.withUnsafeBufferPointer {
        //            //                ($0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0 })
        //            //                }.pointee
        //            //            let integerValue = UInt32(bigEndian: bigEndianValue)
        //
        //            if !bytesArray.isEmpty {
        //                let data = Data(bytes: bytesArray)
        //                let integerValue = UInt32(bigEndian: data.withUnsafeBytes { $0.pointee })
        //                print("\nIntegerValue: \(integerValue)")
        //            }
        //        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("peripheral:didWriteValueFor:characteristic")
        if error != nil {
            print("Error writing value: " + error!.localizedDescription)
        } else {
            peripheral.readValue(for: characteristic)
        }
    }
    
    // Write value
    // let value: UInt8 = 0xDE
    // let data = Data(bytes: [value])
    // peripheral.writeValue(Data(), for: characteristic, type: .withoutResponse)
    
    // Send "01:00" (0x0100)
    //var parameter = NSInteger(1)
    //let data = NSData(bytes: &parameter, length: 1)
    //peripheral.writeValue(data, forCharacteristic: characteric, type: CBCharacteristicWriteType.WithResponse)
    
    // Send "0802"
    //var parameter = 0x0802
    //let data = NSData(bytes: &parameter, length: 2)
}

extension HeartRateVC: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(central.state)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        debugPrint("Disconnected.")
        
        DispatchQueue.main.async {
            self.navigationController?.popViewController(animated: true)
        }
    }

}
















