//
//  BluetoothVC.swift
//  TDDTest
//
//  Created by Alina Egorova on 1/31/18.
//  Copyright © 2018 Alina Egorova. All rights reserved.
//

import UIKit
import CoreBluetooth

enum PeripheralState {
    case searching
    case devicesMode
    case servicesMode
    case characteristicsMode
}

class BluetoothVC: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var currentState = PeripheralState.searching
    
    var tableSource = [String: Any]()
    
    var manager: CBCentralManager!
    var peripheral: CBPeripheral!
    
    let heartRateServiceUUID = "180D"
    let heartRateCharacteristicUUID = "2A39"

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setNavigationBar()

        self.manager = CBCentralManager(delegate: self, queue: DispatchQueue(label: "bluetooth"))
    }
    
    func setNavigationBar() {
        
        let disconnectButton = UIBarButtonItem(title: "Disconnect", style: .plain, target: self, action: #selector(disconnect(_:)))
        disconnectButton.isEnabled = false
        navigationItem.rightBarButtonItem = disconnectButton
        
        let measureHeartRateButton = UIBarButtonItem(title: "Measure", style: .plain, target: self, action: #selector(measureHeartRate))
        navigationItem.leftBarButtonItem = measureHeartRateButton
    }
    
    func setPeripheral(_ peripheral: CBPeripheral) {
        
        currentState = .servicesMode
        
        self.manager.stopScan()
        self.peripheral = peripheral
        self.peripheral.delegate = self
        
        tableSource.removeAll()
        tableView.reloadData()
        
        manager.connect(peripheral, options: nil)
        navigationItem.rightBarButtonItem?.isEnabled = true
        
        debugPrint("Connecting ...")
    }
    
    func selectService(_ service: CBService) {
        
        currentState = .characteristicsMode
        
        tableSource.removeAll()
        tableView.reloadData()
        
        peripheral.discoverCharacteristics(nil, for: service)

        debugPrint("Connect service ...")
    }
    
    func cancelConnection() {
        manager.cancelPeripheralConnection(peripheral)
        peripheral = nil
        
        tableSource.removeAll()
        tableView.reloadData()
        
        currentState = .searching
        
        // Start scanning again
        manager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func reloadTableOnMainThread() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Actions
    
    @objc func disconnect(_ sender: UIBarButtonItem) {
        navigationItem.rightBarButtonItem?.isEnabled = false
        cancelConnection()
    }
    
    @objc func measureHeartRate() {
        guard let peripheral = peripheral,
            let hrControlPoint = peripheral.services?.first(where: { $0.uuid.uuidString == heartRateServiceUUID })?
                .characteristics?.first(where: { $0.uuid.uuidString == heartRateCharacteristicUUID }) else {
                    print("Nothing to measure")
                    return
        }
        peripheral.writeValue(Data(bytes: [0x15, 0x2, 0x1]), for: hrControlPoint, type: .withResponse)
    }
}

extension BluetoothVC: CBPeripheralDelegate {
    
    
    // Discovered peripheral services
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services! {
            tableSource[service.uuid.description] = service as Any
            debugPrint("Service: ", service.uuid)
        }
        reloadTableOnMainThread()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        debugPrint("Enabling ...")
        
        // Look at provided characteristics
        for characteristic in service.characteristics! {
            tableSource[characteristic.uuid.uuidString] = characteristic as Any
            debugPrint("Characteristic: ", characteristic.uuid)
            //debugPrint("Properties: ", characteristic.getProperties())
            
//            if characteristic.properties.contains(.read) {
//                peripheral.readValue(for: characteristic)
//            }
//            if characteristic.properties.contains(.notify) {
//                peripheral.setNotifyValue(true, for: characteristic)
//            }
            
            peripheral.setNotifyValue(true, for: characteristic)
            
            if characteristic.uuid.uuidString == "FF0F"{
                // Pairing with device
                print("Writing value for FF0F")
                //let data: Data = "2".data(using: String.Encoding.utf8)!
                //peripheral.writeValue(data, for: characteristic, type: .withResponse)
                
            } else if characteristic.uuid.uuidString == "FF06" {
                print("READING STEPS")
                peripheral.readValue(for: characteristic)
                
            } else if characteristic.uuid.uuidString == "FF0C" {
                print("READING BATTERY")
                peripheral.readValue(for: characteristic)
                
            } else if characteristic.uuid.uuidString == "FF02" {
                print("READING DEVICE NAME")
                peripheral.readValue(for: characteristic)
                //let data: Data = "ShittyKitty".data(using: String.Encoding.utf8)!
                //peripheral.writeValue(data, for: characteristic, type: .withResponse)
                
            } else if characteristic.uuid.uuidString == "FF01" {
                print("READING DEVICE INFO")
                peripheral.readValue(for: characteristic)
                
            } else if characteristic.uuid.uuidString == "FF04" {
                print("READING USER INFO")
                peripheral.readValue(for: characteristic)
                //let value: [UInt8] = [0x01, 0x01, 0x01, 0x00, 0x1C, 0xAC, 0x38, 0x00, 0x00, 0x00, 0x00, 0x00]
                //let data = Data(bytes: value)
                //peripheral.writeValue(data, for: characteristic, type: .withResponse)
                
            } else if characteristic.uuid.uuidString == "FF0D" {
                print("TEST")
                debugPrint("Properties: ", characteristic.getProperties())
                let value: [UInt8] = [0x01]
                let data = Data(bytes: value)
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
            }
            
        }
        reloadTableOnMainThread()
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
    
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        print("peripheral:didWriteValueFor:descriptor")
        if error != nil {
            print("Error writing value: " + error!.localizedDescription)
        } else {
            peripheral.readValue(for: descriptor.characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("peripheral:didWriteValueFor:characteristic")
        if error != nil {
            print("Error writing value: " + error!.localizedDescription)
        } else {
            peripheral.readValue(for: characteristic)
        }
    }
    
    func getBattery(batteryData: Data) -> Int{
        print("--- UPDATING Battery Data..")
        
        var buffer = [UInt8](batteryData)
        print("\(buffer[0])% charged")
        
        return Int(buffer[0])
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
        
        //return (Int.init(steps), Int.init(distance), Int.init(calories))
    }
    
    func getHeartRate(heartRateData:Data) -> Int{
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
        
        if let actualBpm = bpm{
            return Int(actualBpm)
        } else {
            return Int(bpm!)
        }
    }
    
    private func heartRate(from characteristic: CBCharacteristic) -> Int {
        guard let characteristicData = characteristic.value else { return -1 }
        let byteArray = [UInt8](characteristicData)
        
        let firstBitValue = byteArray[0] & 0x01
        if firstBitValue == 0 {
            // Heart Rate Value Format is in the 2nd byte
            return Int(byteArray[1])
        } else {
            // Heart Rate Value Format is in the 2nd and 3rd bytes
            return (Int(byteArray[1]) << 8) + Int(byteArray[2])
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
        
        if(characteristic.uuid.uuidString == "FF06") {
            let steps = getSteps(data: value)
            print("Steps: \(steps)")
            
        } else if(characteristic.uuid.uuidString == "FF0C") {
            let data = NSData(bytes: [UInt8(bytesArray[0])], length: MemoryLayout<UInt8>.size)
            var target: UInt8 = 0
            data.getBytes(&target, length: MemoryLayout.size(ofValue: data))
            print("\(target)% charged")
            // Same
            //getBattery(batteryData: value)
            
        } else if(characteristic.uuid.uuidString == "FF01") {
            let u16: UInt8 = data.subdata(in: 0..<4).withUnsafeBytes{ $0.pointee }
            print("\(u16) device id")
            
//            let data = NSData(bytes: [[UInt8](bytesArray[0...3])], length: MemoryLayout<UInt16>.size)
//            var target: UInt16 = 0
//            data.getBytes(&target, length: MemoryLayout.size(ofValue: data))
//            print("\(target) device id")
//            print("\nHexa string: \( bytesArray[0...3].map{ String(format: "%02x", $0) }.joined(separator: ""))")
        } else if(characteristic.uuid.uuidString == "FF02") {
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
}

extension BluetoothVC: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central:CBCentralManager) {
        
        // Is Bluetooth even on
        if central.state == CBManagerState.poweredOn {
            // Start looking
            central.scanForPeripherals(withServices: nil, options: nil)
            
            // If we know nessesary service uuid
            //manager?.scanForPeripherals(withServices: [CBUUID.init(string: heartRateServiceUUID)], options: nil)
            
            debugPrint("Searching ...")
        } else {
            debugPrint("Bluetooth not available.")
        }
    }
    
    // Found a peripheral
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if currentState == .searching {
            currentState = .devicesMode
        }
        
        guard currentState == .devicesMode else { return }
        
        if let deviceName = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? String, tableSource[deviceName] == nil {
            //print("Data device name: \(deviceName)")
            if deviceName.contains("MI") {
                tableSource[deviceName] = peripheral as Any
                reloadTableOnMainThread()
            }
            
        } else {
            let deviceUUID: String = peripheral.name ?? peripheral.identifier.description
            if tableSource[deviceUUID] == nil {
                //print("Device UUID: \(deviceUUID)")
                if deviceUUID.contains("MI") {
                    tableSource[deviceUUID] = peripheral as Any
                    reloadTableOnMainThread()
                }
            }
        }
    }
    
    // Connected to peripheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
        debugPrint("Getting services ...")
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        debugPrint("Connection failed")
    }
    
    // Peripheral disconnected
    // Potentially hide relevant interface
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        debugPrint("Disconnected.")
        
        navigationItem.rightBarButtonItem?.isEnabled = false
        self.peripheral = nil
        
        tableSource.removeAll()
        reloadTableOnMainThread()
        
        currentState = .devicesMode
        
        // Start scanning again
        central.scanForPeripherals(withServices: nil, options: nil)
    }
}

extension BluetoothVC: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = Array(tableSource.keys)[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("select row")
        
        let key = Array(tableSource.keys)[indexPath.row]
        
        switch currentState {
        case .searching:
            break
            
        case .devicesMode:
            setPeripheral(tableSource[key] as! CBPeripheral)
            
        case .servicesMode:
            selectService(tableSource[key] as! CBService)
            
        case .characteristicsMode:
            peripheral.setNotifyValue(true, for: tableSource[key] as! CBCharacteristic)
        }
    }
}


