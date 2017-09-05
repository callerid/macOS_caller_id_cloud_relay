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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Create database if not already created
        if(DBManager.shared.createDatabase()){
            // Database created
            print("database created")
        }
        else{
            // Database failed to create
            print("failed to create database")
        }
        
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
        }
        else{
            rbPastedUrl.state = NSOffState
            rbCustomUrl.state = NSOnState
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
            
        }
        else{
            rbDeluxeUnit.state = NSOffState
            rbBasicUnit.state = NSOnState
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
        
        // Load up log
        let results = DBManager.shared.getPreviousLog()
        
        for entry in results {
            addToLog(text: entry)
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
    
    @IBAction func rbBasicUnit_click(_ sender: Any) {
        
        rbBasicUnit.state = NSOnState
        rbDeluxeUnit.state = NSOffState
        
        tbIO.isEnabled = false
        tbSE.isEnabled = false
        tbStatus.isEnabled = false
        tbDuration.isEnabled = false
        tbRings.isEnabled = false
        tbRingType.isEnabled = false
        
    }
    @IBAction func rbDeluxeUnit_click(_ sender: Any) {
        
        rbBasicUnit.state = NSOffState
        rbDeluxeUnit.state = NSOnState
        
        tbIO.isEnabled = true
        tbSE.isEnabled = true
        tbStatus.isEnabled = true
        tbDuration.isEnabled = true
        tbRings.isEnabled = true
        tbRingType.isEnabled = true
        
    }
    @IBAction func rbPastedUrl_click(_ sender: Any) {
        
        rbCustomUrl.state = NSOffState
        rbPastedUrl.state = NSOnState
        
        tbLine.isEnabled = false
        tbIO.isEnabled = false
        tbSE.isEnabled = false
        tbDuration.isEnabled = false
        tbRingType.isEnabled = false
        tbRings.isEnabled = false
        tbDateTime.isEnabled = false
        tbNumber.isEnabled = false
        tbName.isEnabled = false
        tbStatus.isEnabled = false
        
        btnTestUrl.stringValue = "Test Supplied URL"
        lbGeneratedUrl.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        
    }
    @IBOutlet weak var lbGeneratedUrl: NSTextField!
    @IBAction func rbCustomURL_click(_ sender: Any) {
        
        rbCustomUrl.state = NSOnState
        rbPastedUrl.state = NSOffState
        
        tbLine.isEnabled = true
        tbIO.isEnabled = true
        tbSE.isEnabled = true
        tbDuration.isEnabled = true
        tbRingType.isEnabled = true
        tbRings.isEnabled = true
        tbDateTime.isEnabled = true
        tbNumber.isEnabled = true
        tbName.isEnabled = true
        tbStatus.isEnabled = true
        
        btnTestUrl.stringValue = "Test Custom URL"
        lbGeneratedUrl.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
        
    }
    
    // -------------------------------------------------------------------------
    //                     Test POSTing code
    // -------------------------------------------------------------------------
    
    @IBAction func btnTestUrl_Click(_ sender: Any) {
        
        let usingSupplied:Bool = rbPastedUrl.state == NSOnState
        
        if(usingSupplied){
            
            post_url(urlPost: tbSuppliedUrl.stringValue, line: "01", time: "01/01 12:00 PM", phone: "770-263-7111", name: "CallerID.com", io: "I", se: "S", status: "x", duration: "0030", ringNumber: "03", ringType: "A")
            
        }
        else{
            
            post_url(urlPost: lbGeneratedUrl.stringValue, line: "01", time: "01/01 12:00 PM", phone: "770-263-7111", name: "CallerID.com", io: "I", se: "S", status: "x", duration: "0030", ringNumber: "03", ringType: "A")
            
        }
        
    }
    
    
    // -------------------------------------------------------------------------
    //                     Posting code
    // -------------------------------------------------------------------------
    
    @IBOutlet weak var tbServer: NSTextField!
    @IBOutlet weak var tbSuppliedUrl: NSTextField!
    
    @IBAction func btnPaste_click(_ sender: Any) {
        paste_to_url()
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
        var line_variableName = "not used"
        var time_variableName = "not used"
        var phone_variableName = "not used"
        var name_variableName = "not used"
        var io_variableName = "not used"
        var se_variableName = "not used"
        var status_variableName = "not used"
        var duration_variableName = "not used"
        var ringNumber_variableName = "not used"
        var ringType_variableName = "not used"
        
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
    
    // --------------------------------------------------------------------------------------
    
    // -------------------------------------------------------------------------
    //                     Receive data from a UDP broadcast
    // -------------------------------------------------------------------------
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
                post_url(urlPost: postToThisUrl, line: lineNumber, time: callTime, phone: phoneNumber, name: callerId, io: inboundOrOutbound, se: startOrEnd, status: detailedType, duration: duration, ringNumber: ringN, ringType: ringT)
                
                let textToLog = (udpRecieved as String).getCompleteMatch(regex: callRecordPattern)
                addToLog(text: textToLog)
                
            }
            
            let detailMatches = (udpRecieved as String).capturedGroups(withRegex: detailedPattern)
            
            if(detailMatches.count>0){
                
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
                
                // POST to Cloud
                post_url(urlPost: postToThisUrl, line: lineNumber, time: callTime, phone: "", name: "", io: "", se: "", status: detailedType, duration: "", ringNumber: "", ringType: "")
                
                addToLog(text: udpRecieved as String)
                
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
