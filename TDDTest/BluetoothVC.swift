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

class BluetoothVC: UIViewController, UITableViewDataSource, UITableViewDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var currentState = PeripheralState.searching
    
    var tableSource = [String: Any]()
    
    var manager: CBCentralManager!
    var peripheral: CBPeripheral!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setNavigationBar()

        self.manager = CBCentralManager(delegate: self, queue: DispatchQueue(label: "bluetooth"))
    }
    
    func setNavigationBar() {
        let disconnectButton = UIBarButtonItem(title: "Disconnect", style: .plain, target: self, action: #selector(disconnect(_:)))
        disconnectButton.isEnabled = false
        navigationItem.rightBarButtonItem = disconnectButton
    }
    
    @objc func disconnect(_ sender: UIBarButtonItem) {
        navigationItem.rightBarButtonItem?.isEnabled = false
        cancelConnection()
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
    
    // MARK: - Bluetooth delegates
    
    func centralManagerDidUpdateState(_ central:CBCentralManager) {
        
        // Is Bluetooth even on
        if central.state == CBManagerState.poweredOn {
            // Start looking
            central.scanForPeripherals(withServices: nil, options: nil)
            
            // If we know nessesary service uuid
            //manager?.scanForPeripherals(withServices: [CBUUID.init(string: MYServiceUUID)], options: nil)
            
            // Debug
            debugPrint("Searching ...")
        } else {
            // Bzzt!
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
            print("Data device name: \(deviceName)")
            tableSource[deviceName] = peripheral as Any
            reloadTableOnMainThread()
            
        } else {
            let deviceUUID: String = peripheral.name ?? peripheral.identifier.description
            if tableSource[deviceUUID] == nil {
                print("Device UUID: \(deviceUUID)")
                tableSource[deviceUUID] = peripheral as Any
                reloadTableOnMainThread()
            }
        }
        
    }
    
    func reloadTableOnMainThread() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
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
    
    // Discovered peripheral services
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services! {
            tableSource[service.uuid.description] = service as Any
            debugPrint("Service: ", service.uuid.description)
        }
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        debugPrint("Enabling ...")
        
        // Look at provided characteristics
        for characteristic in service.characteristics! {
            tableSource[characteristic.uuid.uuidString] = characteristic as Any
            debugPrint("Characteristic: ", characteristic.uuid)
            debugPrint("Properties: ", characteristic.getProperties())
            peripheral.readValue(for: characteristic)
        }
        DispatchQueue.main.async {
            self.tableView.reloadData()
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
    
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        if error != nil {
            print("Error writing value: " + error!.localizedDescription)
        } else {
            peripheral.readValue(for: descriptor.characteristic)
        }
    }
    
    // Data arrived from peripheral
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        print("_________________________")
        
        print(characteristic.value ?? "Characteristic has no value")
        
        if let value = characteristic.value {
            
            // Get bytes into string
            print("String: \(String(bytes: value, encoding: String.Encoding.utf8) ?? "Can't convert into string")")
            
            print("Hexa string: \( value.map{ String(format: "%02x", $0) }.joined(separator: ""))")
            
            var bytesArray = [UInt8](repeating: 0, count: value.count)
            value.copyBytes(to: &bytesArray, count: value.count)
            print("Bytes array: \(bytesArray)")
            
            let characters = bytesArray.map { Character(UnicodeScalar($0)) }
            print("UInt8 string: \(String(Array(characters)))")

//            let bigEndianValue = bytesArray.withUnsafeBufferPointer {
//                ($0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0 })
//                }.pointee
//            let integerValue = UInt32(bigEndian: bigEndianValue)
            
            if !bytesArray.isEmpty {
                let data = Data(bytes: bytesArray)
                let integerValue = UInt32(bigEndian: data.withUnsafeBytes { $0.pointee })
                print("IntegerValue: \(integerValue)")
            }
        }
    }
    
    // Peripheral disconnected
    // Potentially hide relevant interface
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        debugPrint("Disconnected.")
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        tableSource.removeAll()
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
        
        currentState = .devicesMode
        
        // Start scanning again
        central.scanForPeripherals(withServices: nil, options: nil)
    }
    
    // MARK: - UITableView delegates
    
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


