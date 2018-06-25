//
//  ViewController.swift
//  url_send
//
//  Created by mac on 8/28/17.
//  Copyright © 2017 CallerId.com. All rights reserved.
//

import Cocoa
import CocoaAsyncSocket

class ViewController: NSViewController, GCDAsyncUdpSocketDelegate {

    // define CallerID.com regex strings used for parsing CallerID.com hardware formats
    let callRecordPattern = "(\\d\\d) ([IO]) ([ES]) (\\d{4}) ([GB]) (.)(\\d) (\\d\\d/\\d\\d \\d\\d:\\d\\d [AP]M) (.{8,15})(.*)"
    let detailedPattern = "(\\d\\d) ([NFR]) {13}(\\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d)"
    
    // --------------------------------------------------------------------------------------
    
    let sDataSuppliedUrl = "supplied_url"
    let sDataUsingSuppliedUrl = "using_supplied_url"
    let sDataUsingDeluxeUnit = "using_deluxe_unit"
    let sDataServer = "server"
    
    let sDataParamLine = "param_line"
    let sDataParamTime = "param_time"
    let sDataParamPhone = "param_phone"
    let sDataParamName = "param_name"
    let sDataParamIO = "param_io"
    let sDataParamSE = "param_se"
    let sDataParamStatus = "param_status"
    let sDataParamDuration = "param_duration"
    let sDataParamRingNumber = "param_ring_number"
    let sDataParamRingType = "param_ring_type"
    
    let sDataUsingAuth = "using_auth"
    let sDataUsername = "username"
    let sDataPassword = "password"
    
    let sDataGenUrl = "generated_url"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Create database if not already created
        _ = DBManager.shared.createDatabase()
        
        // Start UDP receiver
        startServer()
        
        // Load up previous values
        let defaults = UserDefaults.standard
        
        // If first run
        if(defaults.string(forKey: sDataUsingSuppliedUrl) == nil){
            return
        }
        
        // Supplied URL
        tbSuppliedUrl.stringValue = defaults.string(forKey: sDataSuppliedUrl)!
        
        // Supplied vs Custom
        let usingSupplied = defaults.bool(forKey: sDataUsingSuppliedUrl)
        if(usingSupplied){
            rbPastedUrl.state = NSOnState
            rbCustomUrl.state = NSOffState
            btnTestUrl.stringValue = "Test Supplied URL"
        }
        else{
            rbPastedUrl.state = NSOffState
            rbCustomUrl.state = NSOnState
            btnTestUrl.stringValue = "Test Built URL"
        }
        
        // Deluxe or Basic
        let usingDeluxe = defaults.bool(forKey: sDataUsingDeluxeUnit)
        if(usingDeluxe){
            
            rbDeluxeUnit.state = NSOnState
            rbBasicUnit.state = NSOffState
            
            tbIO.isEnabled = true
            tbSE.isEnabled = true
            tbStatus.isEnabled = true
            tbDuration.isEnabled = true
            tbRings.isEnabled = true
            tbRingType.isEnabled = true
            
            tbIO.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbSE.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbStatus.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbDuration.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbRings.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbRingType.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
        }
        else{
            
            rbBasicUnit.state = NSOnState
            rbDeluxeUnit.state = NSOffState
            
            tbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
        }
        
        tbServer.stringValue = defaults.string(forKey: sDataServer)!
        
        tbLine.stringValue = defaults.string(forKey: sDataParamLine)!
        tbDateTime.stringValue = defaults.string(forKey: sDataParamTime)!
        tbNumber.stringValue = defaults.string(forKey: sDataParamPhone)!
        tbName.stringValue = defaults.string(forKey: sDataParamName)!
        tbIO.stringValue = defaults.string(forKey: sDataParamIO)!
        tbSE.stringValue = defaults.string(forKey: sDataParamSE)!
        tbStatus.stringValue = defaults.string(forKey: sDataParamStatus)!
        tbDuration.stringValue = defaults.string(forKey: sDataParamDuration)!
        tbRings.stringValue = defaults.string(forKey: sDataParamRingNumber)!
        tbRingType.stringValue = defaults.string(forKey: sDataParamRingType)!
        
        // Using auth.
        let usingAuth = defaults.bool(forKey: sDataUsingAuth)
        if(usingAuth){
            ckbUseAuth.state = NSOnState
        }
        else{
            ckbUseAuth.state = NSOffState
        }
        
        tbUserName.stringValue = defaults.string(forKey: sDataUsername)!
        tbPassword.stringValue = defaults.string(forKey: sDataPassword)!
        
        lbGeneratedUrl.stringValue = defaults.string(forKey: sDataGenUrl)!
        
        changeToSuppliedOrCustom(supplied: rbPastedUrl.state==NSOnState)
        changeToDeluxeOrBasic(isDeluxed: rbDeluxeUnit.state==NSOnState)
        
        // Load up log
        let results = DBManager.shared.getPreviousLog(limit: 25)
        
        for entry in results.reversed() {
            addToLog(text: entry)
        }
        
        // Duplicate handling ticker
        _ = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(dups_timer_tick), userInfo: nil, repeats: true)
        
    }
    
    func dups_timer_tick(){
        
        if(previousReceived.isEmpty){
            return
        }
        
        // Create key list
        var keys_to_remove = [String]()
        var keys_to_inccrement = [String]()
        
        for (key, _) in previousReceived{
            
            if(previousReceived[key]! > 4){
                keys_to_remove.append(key)
            }
            else{
                keys_to_inccrement.append(key)
            }
        }
        
        for key in keys_to_inccrement{
            previousReceived[key] = previousReceived[key]! + 1
        }
        
        for key in keys_to_remove{
            previousReceived.removeValue(forKey: key)
        }
        
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        // Save all settings
        let defaults = UserDefaults.standard
        defaults.set(tbSuppliedUrl.stringValue, forKey: sDataSuppliedUrl)
        defaults.set(rbPastedUrl.state==NSOnState, forKey: sDataUsingSuppliedUrl)
        defaults.set(rbDeluxeUnit.state == NSOnState, forKey: sDataUsingDeluxeUnit)
        defaults.set(tbServer.stringValue, forKey: sDataServer)
        
        defaults.set(tbLine.stringValue, forKey: sDataParamLine)
        defaults.set(tbDateTime.stringValue, forKey: sDataParamTime)
        defaults.set(tbNumber.stringValue, forKey: sDataParamPhone)
        defaults.set(tbName.stringValue, forKey: sDataParamName)
        defaults.set(tbIO.stringValue, forKey: sDataParamIO)
        defaults.set(tbSE.stringValue, forKey: sDataParamSE)
        defaults.set(tbStatus.stringValue, forKey: sDataParamStatus)
        defaults.set(tbDuration.stringValue, forKey: sDataParamDuration)
        defaults.set(tbRings.stringValue, forKey: sDataParamRingNumber)
        defaults.set(tbRingType.stringValue, forKey: sDataParamRingType)
        
        defaults.set(ckbUseAuth.state==NSOnState, forKey: sDataUsingAuth)
        defaults.set(tbUserName.stringValue, forKey: sDataUsername)
        defaults.set(tbPassword.stringValue, forKey: sDataPassword)
        
        defaults.set(lbGeneratedUrl.stringValue, forKey: sDataGenUrl)
        
    }
    
    func showPopup(title:String, message:String){
      
        let myPopup: NSAlert = NSAlert()
        myPopup.messageText = title
        myPopup.informativeText = message
        myPopup.alertStyle = NSAlertStyle.informational
        myPopup.runModal()
        
    }
    

    // Log commands
    @IBOutlet weak var stv_log: NSScrollView!
    func addToLog(text:String) {
        
        if let textView = stv_log.documentView as? NSTextView {
        
            let textToAppend = NSMutableAttributedString(string:text + "\r\n")
            textView.textStorage?.append(textToAppend)
            
            
            let bottom = NSMakeRange((textView.textStorage?.characters.count)! - 1, 1)
            textView.scrollRangeToVisible(bottom)
            
        }
        
    }
    
    // SQL Log Commands
    // Send $_POST to Cloud server
    func insertIntoSql(line:String,
                  time:String,
                  phone:String,
                  name:String,
                  io:String,
                  se:String,
                  status:String,
                  duration:String,
                  ringNumber:String,
                  ringType:String,
                  checksum:String)
    {
        DBManager.shared.addToLog(dateTime: time, line: line, type: io, indicator: se, dur: duration, checksum: checksum, rings: ringNumber, num: phone, name: name)
        
    }
    
    // -------------------------------------------------------------------------
    //                     Interation Code
    // -------------------------------------------------------------------------
    
    @IBOutlet weak var rbBasicUnit: NSButton!
    @IBOutlet weak var rbDeluxeUnit: NSButton!
    @IBOutlet weak var rbPastedUrl: NSButton!
    @IBOutlet weak var rbCustomUrl: NSButton!
    
    @IBOutlet weak var tbLine: NSTextField!
    @IBOutlet weak var tbIO: NSTextField!
    @IBOutlet weak var tbSE: NSTextField!
    @IBOutlet weak var tbDuration: NSTextField!
    @IBOutlet weak var tbRingType: NSTextField!
    @IBOutlet weak var tbRings: NSTextField!
    @IBOutlet weak var tbDateTime: NSTextField!
    @IBOutlet weak var tbNumber: NSTextField!
    @IBOutlet weak var tbName: NSTextField!
    @IBOutlet weak var tbStatus: NSTextField!
    
    @IBOutlet weak var btnTestUrl: NSButton!
    @IBOutlet weak var lbTested: NSTextField!
    
    @IBAction func rbBasicUnit_click(_ sender: Any) {
        
        changeToDeluxeOrBasic(isDeluxed: false)
        
    }
    @IBAction func rbDeluxeUnit_click(_ sender: Any) {
        
        changeToDeluxeOrBasic(isDeluxed: true)
        
    }
    
    func changeToDeluxeOrBasic(isDeluxed:Bool){
        
        let isSupplied = rbPastedUrl.state == NSOnState
        
        if(isSupplied){
            
            if(isDeluxed){
                rbDeluxeUnit.state = NSOnState
                rbBasicUnit.state = NSOffState
            }
            else{
                rbDeluxeUnit.state = NSOffState
                rbBasicUnit.state = NSOnState
            }
            
            return
        }
        
        if(isDeluxed){
            
            rbDeluxeUnit.state = NSOnState
            rbBasicUnit.state = NSOffState
            
            tbIO.isEnabled = true
            tbSE.isEnabled = true
            tbStatus.isEnabled = true
            tbDuration.isEnabled = true
            tbRings.isEnabled = true
            tbRingType.isEnabled = true
            
            tbIO.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbSE.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbStatus.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbDuration.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbRings.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbRingType.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            lbIOD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbSED.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbStatusD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbDurationD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbRingsD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbRingTypeD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            lbIO.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbSE.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbStatus.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbDuration.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbRings.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbRingType.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
        }
        else{
            
            rbDeluxeUnit.state = NSOffState
            rbBasicUnit.state = NSOnState
            
            tbIO.isEnabled = false
            tbSE.isEnabled = false
            tbStatus.isEnabled = false
            tbDuration.isEnabled = false
            tbRings.isEnabled = false
            tbRingType.isEnabled = false
            
            tbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            lbIOD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbSED.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbStatusD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbDurationD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRingsD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRingTypeD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            lbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
        }
        
    }
    
    @IBOutlet weak var lbLine: NSTextField!
    @IBOutlet weak var lbTime: NSTextField!
    @IBOutlet weak var lbNumber: NSTextField!
    @IBOutlet weak var lbName: NSTextField!
    @IBOutlet weak var lbIO: NSTextField!
    @IBOutlet weak var lbSE: NSTextField!
    @IBOutlet weak var lbStatus: NSTextField!
    @IBOutlet weak var lbDuration: NSTextField!
    @IBOutlet weak var lbRings: NSTextField!
    @IBOutlet weak var lbRingType: NSTextField!
    
    @IBOutlet weak var lbLineD: NSTextField!
    @IBOutlet weak var lbTimeD: NSTextField!
    @IBOutlet weak var lbNumberD: NSTextField!
    @IBOutlet weak var lbNameD: NSTextField!
    @IBOutlet weak var lbIOD: NSTextField!
    @IBOutlet weak var lbSED: NSTextField!
    @IBOutlet weak var lbStatusD: NSTextField!
    @IBOutlet weak var lbDurationD: NSTextField!
    @IBOutlet weak var lbRingsD: NSTextField!
    @IBOutlet weak var lbRingTypeD: NSTextField!
    
    @IBOutlet weak var lbCIDVarsHeader: NSTextField!
    @IBOutlet weak var lbYourVarHeader: NSTextField!
    @IBOutlet weak var lbDesHeader: NSTextField!
    @IBOutlet weak var lbDevSection: NSTextField!
    @IBOutlet weak var lbServer: NSTextField!
    @IBOutlet weak var btnGenerateUrl: NSButton!
    
    func changeToSuppliedOrCustom(supplied:Bool){
        
        if(supplied){
            
            rbPastedUrl.state = NSOnState
            rbCustomUrl.state = NSOffState
            
            btnTestUrl.title = "Test Supplied URL"
            lbGeneratedUrl.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            lbDesHeader.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbCIDVarsHeader.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbYourVarHeader.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            tbLine.isEnabled = false
            tbDateTime.isEnabled = false
            tbNumber.isEnabled = false
            tbName.isEnabled = false
            tbIO.isEnabled = false
            tbSE.isEnabled = false
            tbStatus.isEnabled = false
            tbDuration.isEnabled = false
            tbRings.isEnabled = false
            tbRingType.isEnabled = false
            tbServer.isEnabled = false
            
            tbLine.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbDateTime.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbNumber.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbName.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbServer.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbDevSection.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            lbLine.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbTime.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbNumber.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbName.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            lbLineD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbTimeD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbNumberD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbNameD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbIOD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbSED.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbStatusD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbDurationD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRingsD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRingTypeD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            lbServer.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            btnGenerateUrl.isEnabled = false
        }
        else
        {
            
            rbPastedUrl.state = NSOffState
            rbCustomUrl.state = NSOnState
            
            btnTestUrl.title = "Test Built URL"
            lbGeneratedUrl.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
            
            lbDesHeader.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbCIDVarsHeader.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbYourVarHeader.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            tbLine.isEnabled = true
            tbDateTime.isEnabled = true
            tbNumber.isEnabled = true
            tbName.isEnabled = true
            tbServer.isEnabled = true
            
            let isDeluxed = rbDeluxeUnit.state == NSOnState
            
            if(isDeluxed){
                
                tbIO.isEnabled = true
                tbSE.isEnabled = true
                tbStatus.isEnabled = true
                tbDuration.isEnabled = true
                tbRings.isEnabled = true
                tbRingType.isEnabled = true
                
                tbIO.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                tbSE.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                tbStatus.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                tbDuration.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                tbRings.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                tbRingType.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                
                lbIOD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbSED.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbStatusD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbDurationD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbRingsD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbRingTypeD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                
                lbIO.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbSE.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbStatus.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbDuration.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbRings.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbRingType.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                
            }
            else{
                
                tbIO.isEnabled = false
                tbSE.isEnabled = false
                tbStatus.isEnabled = false
                tbDuration.isEnabled = false
                tbRings.isEnabled = false
                tbRingType.isEnabled = false
                
                tbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                tbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                tbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                tbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                tbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                tbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                
                lbIOD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbSED.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbStatusD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbDurationD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbRingsD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbRingTypeD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                
                lbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                
            }
            
            tbLine.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbDateTime.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbNumber.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbName.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            tbServer.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbDevSection.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            lbLine.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbTime.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbNumber.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbName.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            lbLineD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbTimeD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbNumberD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbNameD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            lbServer.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            btnGenerateUrl.isEnabled = true
            
            
        }
        
    }
    
    @IBAction func rbPastedUrl_click(_ sender: Any) {
        
        changeToSuppliedOrCustom(supplied: true)
        
    }
    @IBOutlet weak var lbGeneratedUrl: NSTextField!
    @IBAction func rbCustomURL_click(_ sender: Any) {
        
        changeToSuppliedOrCustom(supplied: false)
        
    }
    
    // -------------------------------------------------------------------------
    //                     Test POSTing code
    // -------------------------------------------------------------------------
    
    @IBAction func btnTestUrl_Click(_ sender: Any) {
        
        let usingSupplied:Bool = rbPastedUrl.state == NSOnState
        
        if(usingSupplied){
            
            lbTested.stringValue = "Sent to Supplied URL"
            post_url(urlPost: tbSuppliedUrl.stringValue, line: "01", time: "01/01 12:00 PM", phone: "770-263-7111", name: "CallerID.com", io: "I", se: "S", status: "x", duration: "0030", ringNumber: "03", ringType: "A")
            
        }
        else{
            
            lbTested.stringValue = "Sent to Built URL"
            post_url(urlPost: lbGeneratedUrl.stringValue, line: "01", time: "01/01 12:00 PM", phone: "770-263-7111", name: "CallerID.com", io: "I", se: "S", status: "x", duration: "0030", ringNumber: "03", ringType: "A")
            
        }
        
        // Duplicate handling ticker
        _ = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(resetTestedLable), userInfo: nil, repeats: false)
        
    }
    
    func resetTestedLable(){
        
        lbTested.stringValue = "idle"
        
    }
    
    
    // -------------------------------------------------------------------------
    //                     Posting code
    // -------------------------------------------------------------------------
    
    @IBOutlet weak var tbServer: NSTextField!
    @IBOutlet weak var tbSuppliedUrl: NSTextField!
    
    @IBAction func btnPaste_click(_ sender: Any) {
        paste_to_url()
    }
    
    // Generating functions
    
    
    @IBAction func btnGenerate_Click(_ sender: Any) {
        generate_web_url()
    }
    // Generating web address
    func generate_web_url()
    {
        
        var genUrl = tbServer.stringValue + "?"
        
        if(tbLine.stringValue != ""){
            genUrl = genUrl + tbLine.stringValue + "=%Line&"
        }
        
        if(tbDateTime.stringValue != ""){
            genUrl = genUrl + tbDateTime.stringValue + "=%Time&"
        }
        
        if(tbNumber.stringValue != ""){
            genUrl = genUrl + tbNumber.stringValue + "=%Phone&"
        }
        
        if(tbName.stringValue != ""){
            genUrl = genUrl + tbName.stringValue + "=%Name&"
        }
        if(tbIO.stringValue != ""){
            genUrl = genUrl + tbIO.stringValue + "=%IO&"
        }
        if(tbSE.stringValue != ""){
            genUrl = genUrl + tbSE.stringValue + "=%SE&"
        }
        if(tbStatus.stringValue != ""){
            genUrl = genUrl + tbStatus.stringValue + "=%Status&"
        }
        if(tbDuration.stringValue != ""){
            genUrl = genUrl + tbDuration.stringValue + "=%Duration&"
        }
        if(tbRings.stringValue != ""){
            genUrl = genUrl + tbRings.stringValue + "=%RingNumber&"
        }
        if(tbRingType.stringValue != ""){
            genUrl = genUrl + tbRingType.stringValue + "=%RingType&"
        }
        
        // Return generated string
        lbGeneratedUrl.stringValue = genUrl.substring(to: genUrl.index(before: genUrl.endIndex))
        
    }
    
    // Gets clipboard text and paste into program
    func paste_to_url(){
        
        let clipboardText = clipboardContent()
        
        if(clipboardText == nil){
            
            showPopup(title: "Failed", message: "No text found in Clipboard.")
            return
            
        }
        
        let urlParts = clipboardText?.components(separatedBy: "?")
        
        if(urlParts?.count != 2){
            
            showPopup(title: "Failed", message: "Text found on Clipboard is not in correct format.")
            return
            
        }
        
        let urlString = urlParts?[0]
        let params = urlParts?[1]
        
        tbServer.stringValue = urlString!
        
        if(parseParams(params: params!)){
            
            showPopup(title: "Success", message: "Pasted Successful")
            tbSuppliedUrl.stringValue = clipboardText!
            return
            
        }
        
        showPopup(title: "Failed", message: "Text found on Clipboard is not in correct format.")
        
    }
    
    // Patterns
    let linePattern = "([&]?([A-Za-z0-9_-]+)=%Line)"
    let ioPattern = "([&]?([A-Za-z0-9_-]+)=%IO)"
    let sePattern = "([&]?([A-Za-z0-9_-]+)=%SE)"
    let durationPattern = "([&]?([A-Za-z0-9_-]+)=%Duration)"
    let ringTypePattern = "([&]?([A-Za-z0-9_-]+)=%RingType)"
    let ringNumberPattern = "([&]?([A-Za-z0-9_-]+)=%RingNumber)"
    let timePattern = "([&]?([A-Za-z0-9_-]+)=%Time)"
    let phonePattern = "([&]?([A-Za-z0-9_-]+)=%Phone)"
    let namePattern = "([&]?([A-Za-z0-9_-]+)=%Name)"
    let statusPattern = "([&]?([A-Za-z0-9_-]+)=%Status)"
    
    func parseParams(params:String) -> Bool{
        
        // Setup varibles
        var line_variableName = ""
        var time_variableName = ""
        var phone_variableName = ""
        var name_variableName = ""
        var io_variableName = ""
        var se_variableName = ""
        var status_variableName = ""
        var duration_variableName = ""
        var ringNumber_variableName = ""
        var ringType_variableName = ""
        
        // Capture variables from params string
        let lineMatch = params.capturedGroups(withRegex: linePattern)
        if(lineMatch.count>1){
            line_variableName = lineMatch[1]
        }
        
        let timeMatch = params.capturedGroups(withRegex: timePattern)
        if(timeMatch.count>1){
            time_variableName = timeMatch[1]
        }
        
        let phoneMatch = params.capturedGroups(withRegex: phonePattern)
        if(phoneMatch.count>1){
            phone_variableName = phoneMatch[1]
        }
        
        let nameMatch = params.capturedGroups(withRegex: namePattern)
        if(nameMatch.count>1){
            name_variableName = nameMatch[1]
        }
        
        let ioMatch = params.capturedGroups(withRegex: ioPattern)
        if(ioMatch.count>1){
            io_variableName = ioMatch[1]
        }
        
        let seMatch = params.capturedGroups(withRegex: sePattern)
        if(seMatch.count>1){
            se_variableName = seMatch[1]
        }
        
        let statusMatch = params.capturedGroups(withRegex: statusPattern)
        if(statusMatch.count>1){
            status_variableName = statusMatch[1]
        }
        
        let durationMatch = params.capturedGroups(withRegex: durationPattern)
        if(durationMatch.count>1){
            duration_variableName = durationMatch[1]
        }
        
        let ringNumberMatch = params.capturedGroups(withRegex: ringNumberPattern)
        if(ringNumberMatch.count>1){
            ringNumber_variableName = ringNumberMatch[1]
        }
        
        let ringTypeMatch = params.capturedGroups(withRegex: ringTypePattern)
        if(ringTypeMatch.count>1){
            ringType_variableName = ringTypeMatch[1]
        }
        
        
        // Display variables
        tbLine.stringValue = line_variableName
        tbDateTime.stringValue = time_variableName
        tbNumber.stringValue = phone_variableName
        tbName.stringValue = name_variableName
        tbIO.stringValue = io_variableName
        tbSE.stringValue = se_variableName
        tbStatus.stringValue = status_variableName
        tbDuration.stringValue = duration_variableName
        tbRings.stringValue = ringNumber_variableName
        tbRingType.stringValue = ringType_variableName
        
        return true
        
    }
    
    @IBOutlet weak var ckbUseAuth: NSButton!
    @IBOutlet weak var tbUserName: NSTextField!
    @IBOutlet weak var tbPassword: NSTextField!
    
    // Send $_POST to Cloud server
    func post_url(urlPost:String,
                  line:String,
                  time:String,
                  phone:String,
                  name:String,
                  io:String,
                  se:String,
                  status:String,
                  duration:String,
                  ringNumber:String,
                  ringType:String)
    {
        
        let urlParts = urlPost.components(separatedBy: "?")
        let urlString = urlParts[0]
        var usingParams = urlParts[1]
        
        // Replace CallerID variables with actual data
        usingParams = usingParams.replacingOccurrences(of: "%Line", with: line)
        usingParams = usingParams.replacingOccurrences(of: "%Time", with: time)
        usingParams = usingParams.replacingOccurrences(of: "%Phone", with: phone)
        usingParams = usingParams.replacingOccurrences(of: "%Name", with: name)
        usingParams = usingParams.replacingOccurrences(of: "%IO", with: io)
        usingParams = usingParams.replacingOccurrences(of: "%SE", with: se)
        usingParams = usingParams.replacingOccurrences(of: "%Status", with: status)
        usingParams = usingParams.replacingOccurrences(of: "%Duration", with: duration)
        usingParams = usingParams.replacingOccurrences(of: "%RingNumber", with: ringNumber)
        usingParams = usingParams.replacingOccurrences(of: "%RingType", with: ringType)
        
        // Create request
        let fullUrl = urlString + "?" + usingParams
        let requestUrl = URL(string: fullUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
        let request = NSMutableURLRequest(url:requestUrl!)
        request.httpMethod = "POST"
        
        // Create session configuration (for authentication)
        let config = URLSessionConfiguration.default
        if(ckbUseAuth.state == NSOnState){
            let userPasswordString = "\(tbUserName.stringValue):\(tbPassword.stringValue)",
            userPasswordData = userPasswordString.data(using: String.Encoding.utf8),
            base64EncodedCredential = userPasswordData?.base64EncodedString(),
            authString = "Basic \(base64EncodedCredential ?? "none")"
            config.httpAdditionalHeaders = ["Authorization" : authString]
        }
        
        // Create session
        let session = URLSession(configuration: config)
        
        // Set up task for execution
        let task = session.dataTask(with: request as URLRequest) {
            (
            data, response, error) in
            
            guard let _:NSData = data as NSData?, let _:URLResponse = response, error == nil else {
                print("Error posting to Cloud.")
                return
            }
            
            if let dataString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            {
                print(dataString)
            }
        }
        
        task.resume()
    }
    
    // --------------------------------------------------------------------------------------
    //                    ALL UDP LOWER LEVEL CODE
    // --------------------------------------------------------------------------------------
    
    fileprivate var _socket: GCDAsyncUdpSocket?
    fileprivate var socket: GCDAsyncUdpSocket? {
        get {
            if _socket == nil {
                _socket = getNewSocket()
            }
            return _socket
        }
        set {
            if _socket != nil {
                _socket?.close()
            }
            _socket = newValue
        }
    }
    
    fileprivate func getNewSocket() -> GCDAsyncUdpSocket? {
        
        // set port to CallerID.com port --> 3520
        let port = UInt16(3520)
        
        // Bind to CallerID.com port (3520)
        let sock = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        do {
            
            try sock.bind(toPort: port)
            try sock.enableBroadcast(true)
            
        } catch _ as NSError {
            
            return nil
            
        }
        return sock
    }
    
    fileprivate func startServer() {
        
        do {
            try socket?.beginReceiving()
        } catch _ as NSError {
            
            return
            
        }
        
    }
    
    fileprivate func stopServer(_ sender: AnyObject) {
        if socket != nil {
            socket?.pauseReceiving()
        }
        
    }
    
    // -------------------------------------------------------------------------
    //                     Receive data from a UDP broadcast
    // -------------------------------------------------------------------------
    var previousReceived = [String: Int]()
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        
        if let udpRecieved = NSString(data: data, encoding: String.Encoding.ascii.rawValue) {
            
            // parse and handle udp data----------------------------------------------
            
            // declare used variables for matching
            var lineNumber = "n/a"
            var startOrEnd = "n/a"
            var ckSum = "n/a"
            var inboundOrOutbound = "n/a"
            var duration = "n/a"
            var callRing = "n/a"
            var callTime = "01/01 0:00:00"
            var phoneNumber = "n/a"
            var callerId = "n/a"
            var detailedType = "n/a"

            let callMatches = (udpRecieved as String).capturedGroups(withRegex: callRecordPattern)
            
            if(callMatches.count>0){
            
                // ----------------------------------------------------------------
                // Keep track of previous 30 to have ablitiy of ignoring duplicate
                // packets - even if they are out of order, which can happen
                //-----------------------------------------------------------------
                let found = previousReceived[udpRecieved as String] != nil
                if(found){
                    return
                }
                
                if(previousReceived.count>30){
                    previousReceived[udpRecieved as String] = 0
                    
                    var removal_key = ""
                    for key in previousReceived.keys{
                        removal_key = key
                        break
                    }
                    
                    previousReceived.removeValue(forKey: removal_key)
                    
                }
                else{
                    previousReceived[udpRecieved as String] = 0
                }
                
                lineNumber = callMatches[0]
                inboundOrOutbound = callMatches[1]
                startOrEnd = callMatches[2]
                duration = callMatches[3]
                ckSum = callMatches[4]
                callRing = callMatches[5] + callMatches[6]
                callTime = callMatches[7]
                phoneNumber = callMatches[8]
                callerId = callMatches[9]
                
                // Add to SQL
                insertIntoSql(line: lineNumber, time: callTime, phone: phoneNumber, name: callerId, io: inboundOrOutbound, se: startOrEnd, status: detailedType, duration: duration, ringNumber: callRing.getCharAtIndexAsString(i: 0), ringType: callRing.getCharAtIndexAsString(i: 1), checksum: ckSum)
                
                // Get URL to post to
                var postToThisUrl = ""
                if(rbPastedUrl.state == NSOnState){
                    postToThisUrl = tbSuppliedUrl.stringValue
                }
                else{
                    postToThisUrl = lbGeneratedUrl.stringValue
                }
                
                let ringT = callRing.getCharAtIndexAsString(i: 0)
                let ringN = callRing.getCharAtIndexAsString(i: 1)
                
                // POST to Cloud
                if(rbBasicUnit.state==NSOnState){
                    
                    if(startOrEnd == "S"){
                        post_url(urlPost: postToThisUrl, line: lineNumber, time: callTime, phone: phoneNumber, name: callerId, io: inboundOrOutbound, se: startOrEnd, status: detailedType, duration: duration, ringNumber: ringN, ringType: ringT)
                    }
                    
                }
                else{
                    post_url(urlPost: postToThisUrl, line: lineNumber, time: callTime, phone: phoneNumber, name: callerId, io: inboundOrOutbound, se: startOrEnd, status: detailedType, duration: duration, ringNumber: ringN, ringType: ringT)
                }
                
                let textToLog = (udpRecieved as String).getCompleteMatch(regex: callRecordPattern)
                addToLog(text: textToLog)
                
            }
            
            let detailMatches = (udpRecieved as String).capturedGroups(withRegex: detailedPattern)
            
            if(detailMatches.count>0){
                
                // ----------------------------------------------------------------
                // Keep track of previous 30 to have ablitiy of ignoring duplicate
                // packets - even if they are out of order, which can happen
                //-----------------------------------------------------------------
                let found = previousReceived[udpRecieved as String] != nil
                if(found){
                    return
                }
                
                if(previousReceived.count>30){
                    previousReceived[udpRecieved as String] = 0
                    
                    var removal_key = ""
                    for key in previousReceived.keys{
                        removal_key = key
                        break
                    }
                    
                    previousReceived.removeValue(forKey: removal_key)
                    
                }
                else{
                    previousReceived[udpRecieved as String] = 0
                }
                
                // If detailed then check to see if box is a Deluxe unit and also that the detailed
                // user parameter variable is setup
                if(tbStatus.stringValue != "" || rbBasicUnit.state == NSOnState){
                
                    lineNumber = detailMatches[0]
                    detailedType = detailMatches[1]
                    callTime = detailMatches[2]
                    
                    // Get URL to post to
                    var postToThisUrl = ""
                    if(rbPastedUrl.state == NSOnState){
                        postToThisUrl = tbSuppliedUrl.stringValue
                    }
                    else{
                        postToThisUrl = lbGeneratedUrl.stringValue
                    }
                    
                    // Add to SQL
                    DBManager.shared.addToLog(dateTime: callTime, line: lineNumber, type: "", indicator: detailedType, dur: "", checksum: "", rings: "", num: "", name: "")
                    
                    // POST to Cloud
                    post_url(urlPost: postToThisUrl, line: lineNumber, time: callTime, phone: "", name: "", io: "", se: "", status: detailedType, duration: "", ringNumber: "", ringType: "")
                    
                    let textToLog = (udpRecieved as String).getCompleteMatch(regex: detailedPattern)
                    if(lineNumber != "n/a"){
                        
                        addToLog(text: textToLog as String)
                        
                    }
                }
            }
        }

    }
    
    func clipboardContent() -> String?
    {
        return NSPasteboard.general().pasteboardItems?.first?.string(forType: "public.utf8-plain-text")
    }
}

extension String {
    
    func getCharAtIndexAsString(i:Int)->String{
        let index = self.index(self.startIndex, offsetBy: i)
        return "\(self [index])"
    }
    
    func capturedGroups(withRegex pattern: String) -> [String] {
        var results = [String]()
        
        var regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            return results
        }
        
        let matches = regex.matches(in: self, options: [], range: NSRange(location:0, length: self.characters.count))
        
        guard let match = matches.first else { return results }
        
        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else { return results }
        
        for i in 1...lastRangeIndex {
            let capturedGroupIndex = match.rangeAt(i)
            let matchedString = (self as NSString).substring(with: capturedGroupIndex)
            results.append(matchedString)
        }
        
        return results
    }
    func getCompleteMatch(regex: String) -> String {
        
        do {
            let regex = try NSRegularExpression(pattern: regex, options: [])
            let nsString = self as NSString
            let results = regex.matches(in: self,
                                                options: [], range: NSMakeRange(0, nsString.length))
            let groups = results.map { nsString.substring(with: $0.range)}
            return groups[0]
            
        } catch let error as NSError {
            print("invalid regex: \(error.localizedDescription)")
            return ""
        }
    }
}
