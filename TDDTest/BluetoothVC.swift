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
    
    var peripherals = [CBPeripheral]()
    
    var manager: CBCentralManager!
    var peripheral: CBPeripheral?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setNavigationBar()

        self.manager = CBCentralManager(delegate: self, queue: DispatchQueue(label: "bluetooth"))
    }
    
    func setNavigationBar() {
        title = "Searching MiBands"
        
        let disconnectButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(disconnect(_:)))
        disconnectButton.isEnabled = false
        navigationItem.rightBarButtonItem = disconnectButton
    }
    
    func setPeripheral(_ peripheral: CBPeripheral) {
        navigationItem.rightBarButtonItem?.isEnabled = true

        self.manager.stopScan()
        self.peripheral = peripheral
        
        manager.connect(peripheral, options: nil)
        
        debugPrint("Connecting ...")
    }
    
    func cancelConnection() {
        
        if let peripheral = peripheral {
            manager.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
        }
        
        peripherals.removeAll()
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
    
    // MARK: - Segue
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showHeartRate" {
            let vc = segue.destination as! HeartRateVC
            vc.manager = manager
            vc.miBand = peripheral
        }
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
        
        guard !peripherals.contains(peripheral) else { return }
        
        if let deviceName = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? String {
            //print("Data device name: \(deviceName)")
            if deviceName.contains("MI") {
                peripherals.append(peripheral)
                reloadTableOnMainThread()
            }
            
        } else {
            let deviceUUID: String = peripheral.name ?? peripheral.identifier.description
            //print("Device UUID: \(deviceUUID)")
            if deviceUUID.contains("MI") {
                peripherals.append(peripheral)
                reloadTableOnMainThread()
            }
        }
    }
    
    // Connected to peripheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        debugPrint("Connected!")
        self.peripheral = peripheral
        
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "showHeartRate", sender: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        debugPrint("Connection failed")
        cancelConnection()
    }
    
    // Peripheral disconnected
    // Potentially hide relevant interface
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        debugPrint("Disconnected.")
        
        navigationItem.rightBarButtonItem?.isEnabled = false
        self.peripheral = nil
        
        peripherals.removeAll()
        reloadTableOnMainThread()
        
        currentState = .devicesMode
        
        // Start scanning again
        central.scanForPeripherals(withServices: nil, options: nil)
    }
}

extension BluetoothVC: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let peripheral = peripherals[indexPath.row]
        cell.textLabel?.text = peripheral.name ?? peripheral.identifier.uuidString
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        print("select row")
        
        switch currentState {
        case .devicesMode:
            setPeripheral(peripherals[indexPath.row])
        default:
            break
        }
    }
}


