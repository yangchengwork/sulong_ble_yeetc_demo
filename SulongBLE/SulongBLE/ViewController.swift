//
//  ViewController.swift
//  SulongBLE
//
//  Created by YangGump on 2016/11/29.
//  Copyright © 2016年 YangGump. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var slButton: UIButton!
    
    // 添加属性
    var manager: CBCentralManager!
    var peripheral: CBPeripheral!
    var writeCharacteristic: CBCharacteristic!
    
    // 服务和特征的UUID
    var kServiceUUID = [CBUUID(string:"CC747268-008D-48C1-9541-E428C310B400")]
    var kWriteCharUUID: String = "CC747268-008D-48C1-9541-E428C310B401"
    var kNotifyCharUUID: String = "CC747268-008D-48C1-9541-E428C310B402"
    
    var count: Int = 0
    var step: Int = 0
    var dataArray: [UInt8] = Array<UInt8>()
    var dataStr: String = ""
    var batteryStr: String = ""
    
    var pmTimer : Timer?
    var batteryTimer : Timer?


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.manager = CBCentralManager(delegate: self, queue: nil);
        slButton.setTitle("扫描", for: .normal);
        self.count = 0;
        self.step = 0;
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onClick(_ sender: Any) {
        switch self.step {
            case 0:
                label.text = "开始扫描"
                self.step = 1
                self.manager.scanForPeripherals(withServices:kServiceUUID, options: [CBCentralManagerScanOptionAllowDuplicatesKey:true]);
            case 1:
                label.text = ""
                self.count = 0
                pmTimer = Timer(timeInterval: 1.0, target: self, selector:#selector(ViewController.pmUpdate), userInfo: nil, repeats: true)
                pmUpdate()
                RunLoop.main.add(pmTimer!, forMode: .commonModes)
            default:
                break
        }
    }
    
    func pmUpdate() {
        writeToPeripheral(cmd: 0x31)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if #available(iOS 10.0, *) {
            switch central.state {
            case .unauthorized:
                print("This app is not authorised to use Bluetooth low energy")
            case .poweredOff:
                print("Bluetooth is currently powered off.")
            case .poweredOn:
                print("Bluetooth is currently powered on and available to use.")
            default:break
            }
        } else {
            switch central.state {
            case .poweredOn:
                // 扫描周边蓝牙外设
                // 写nil表示扫描所有蓝牙外设，如果传上面的kServiceUUID，那么只能扫描出这个服务的外设。
                // CBCentralManagerScanOptionAllowDuplicatesKey表示是否可以重复扫描重名设备
                print("蓝牙已打开，请扫描外设");
                label.text = "蓝牙已打开，请扫描外设";
            case .unauthorized:
                print("这个应用程序是无权使用蓝牙低功耗")
                label.text = "这个应用程序是无权使用蓝牙低功耗"
            case .poweredOff:
                print("蓝牙目前关闭状态")
                label.text = "蓝牙目前关闭状态"
            default:
                print("中央管理器没有改变状态")
                label.text = "中央管理器没有改变状态"
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("有扫描到BLE设备 \(peripheral.description)")
        print("广播数据 \(advertisementData.description)")
        label.text = "扫描到我们的设备"
        self.manager.stopScan();
        self.peripheral = peripheral;
        self.manager = central;
        central.connect(self.peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("连接到设备")
        self.peripheral.delegate = self
        self.peripheral.discoverServices(self.kServiceUUID)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("发现对应的服务")
        
        for s in peripheral.services! {
            peripheral.discoverCharacteristics(nil, for: s)
            print(s.uuid.uuidString)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("进入特征查找")
        
        for c in service.characteristics! {
            print(c.uuid.uuidString);
            if c.uuid.uuidString == kNotifyCharUUID {
                peripheral.setNotifyValue(true, for: c)
            }
            if c.uuid.uuidString == kWriteCharUUID {
                self.writeCharacteristic = c
                label.text = "等待命令"
                slButton.setTitle("开始", for: .normal);
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("写入成功")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("打开监听")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid.uuidString == kNotifyCharUUID {
            let str = String(data: characteristic.value!, encoding: .utf8)
            self.onData(buf: str!)
        }
    }
    
    func writeToPeripheral(cmd:UInt8) {
        var b:[UInt8] = [0x74, 0x70, 0x3D, 0x31]
        b[3] = cmd
        let buf = NSData(bytes: b as [UInt8], length: 4)
        self.peripheral.writeValue(buf as Data, for: self.writeCharacteristic, type: .withResponse)
    }
    
    func onData(buf: String) {
        var size = buf.characters.count
        if size == 0 {
            return
        }
        self.dataStr += buf
        size = self.dataStr.characters.count
        let data: [UInt8] = Array(self.dataStr.utf8)
        if data[size-1] == 0x0d {
            if data[size] == 0x0a {
                if data[3] == 0x31 {
                    writeToPeripheral(cmd: 0x34)
                    self.count += 1
                    let pattern = "PM25=\\d+"
                    let regular = try! NSRegularExpression(pattern: pattern, options:.caseInsensitive)
                    let results = regular.matches(in: self.dataStr, options: .reportProgress , range: NSMakeRange(0, self.dataStr.characters.count))
                    let ret = (self.dataStr as NSString).substring(with: results[0].range)
                    label.text = "count:\(self.count) \(ret) \(self.batteryStr)"
                    print("end \(results.count) \(ret)")
                } else if data[3] == 0x34 {
                    let pattern = "v[c|b]=\\d+"
                    let regular = try! NSRegularExpression(pattern: pattern, options:.caseInsensitive)
                    let results = regular.matches(in: self.dataStr, options: .reportProgress , range: NSMakeRange(0, self.dataStr.characters.count))
                    let ret = (self.dataStr as NSString).substring(with: results[0].range)
                    self.batteryStr = ret
                    print("end \(results.count) \(ret)")
                }
                self.dataStr = ""
            }
        }
    }
}

