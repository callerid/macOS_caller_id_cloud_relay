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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        // Start UDP receiver
        startServer()
        
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
    
    
    @IBAction func rbBasicUnit_click(_ sender: Any) {
        rbBasicUnit.state = NSOnState
        rbDeluxeUnit.state = NSOffState
    }
    @IBAction func rbDeluxeUnit_click(_ sender: Any) {
        rbBasicUnit.state = NSOffState
        rbDeluxeUnit.state = NSOnState
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
        
    }
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
        
    }
    
    
    // -------------------------------------------------------------------------
    //                     Posting code
    // -------------------------------------------------------------------------
    
    @IBOutlet weak var tbServer: NSTextField!
    @IBOutlet weak var lbPasteStatus: NSTextField!
    
    @IBAction func btnPaste_click(_ sender: Any) {
        paste_to_url()
    }
    
    // Gets clipboard text and paste into program
    func paste_to_url(){
        
        let clipboardText = clipboardContent()
        
        if(clipboardText == nil){
            
            lbPasteStatus.stringValue = "Failed to Paste"
            return
            
        }
        
        let urlParts = clipboardText?.components(separatedBy: "?")
        
        if(urlParts?.count != 2){
            
            lbPasteStatus.stringValue = "Failed to Paste"
            return
            
        }
        
        let urlString = urlParts?[0]
        let params = urlParts?[1]
        
        tbServer.stringValue = urlString!
        
        if(parseParams(params: params!)){
            
            lbPasteStatus.stringValue = "Pasted"
            return
            
        }
        
        lbPasteStatus.stringValue = "Paste Failed"
        
    }
    
    func parseParams(params:String) -> Bool{
        
        let paras = params.components(separatedBy: "&")
        
        if(paras.count<1){
            return false
        }
        
        
        
        return true
        
    }
    
    func post_url(urlPost:String)
    {
        
        let urlParts = urlPost.components(separatedBy: "?")
        let urlString = urlParts[0]
        let params = urlParts[1]
        
        let url:NSURL = NSURL(string: urlString)!
        let session = URLSession.shared
        
        let request = NSMutableURLRequest(url: url as URL)
        request.httpMethod = "POST"
        
        let paramString = params
        request.httpBody = paramString.data(using: String.Encoding.utf8)
        
        let task = session.dataTask(with: request as URLRequest) {
            (
            data, response, error) in
            
            guard let _:NSData = data as NSData?, let _:URLResponse = response, error == nil else {
                print("error")
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
            var inboundOrOutbound = "n/a"
            var duration = "n/a"
            var ckSum = "B"
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
                
                let textToLog = (udpRecieved as String).getCompleteMatch(regex: callRecordPattern)
                addToLog(text: textToLog)
                
            }
            
            let detailMatches = (udpRecieved as String).capturedGroups(withRegex: detailedPattern)
            
            if(detailMatches.count>0){
                
                lineNumber = detailMatches[0]
                detailedType = detailMatches[1]
                callTime = detailMatches[2]
                
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
