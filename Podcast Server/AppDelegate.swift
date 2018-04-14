//
//  AppDelegate.swift
//  Podcast Server
//
//  Created by Numeric on 4/14/18.
//  Copyright © 2018 Kenny. All rights reserved.
//

import Cocoa
import AVFoundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var folderPath: NSTextField!
    @IBOutlet weak var serverAddressTextField: NSTextField!
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var antiCachingField: NSTextField!
    @IBOutlet weak var addPodcastField: NSTextField!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        closePorts()
        let address = getIPV4IP()
        
        UserDefaults.standard.synchronize()
        if let fp = UserDefaults.standard.value(forKey: "FolderPath") as? String {
            folderPath.stringValue = fp
        }
        
        serverAddressTextField.stringValue = "\(address):8080"
//        if let sv = UserDefaults.standard.value(forKey: "ServerAddress") as? String {
//            serverAddressTextField.stringValue = sv
//        }
    }
    
    func shell(launchPath: String, arguments: [AnyObject]) -> String
    {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments as? [String]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String = String(data: data, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
        
        return output
    }

    
    func getIPV4IP() -> String {
        let addresses = getIFAddresses()
        for add in addresses {
            if (add.contains(".")) {
                return add
            }
        }
        return "127.0.0.1"
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        closePorts()
    }
    
    func closePorts() {
        let str = "tell application \"Terminal\" to do script \"lsof -ti:8080 | xargs kill\""
        let appleScript = NSAppleScript.init(source: str)
        var dict: NSDictionary?
        appleScript?.executeAndReturnError(&dict)
        print(dict ?? "No error")
    }
    
    func closeAllServers() {
        let str = "tell application \"Terminal\" to close (every window whose name contains \"\((folderPath.stringValue as NSString).lastPathComponent)\")"
        let appleScript = NSAppleScript.init(source: str)
        var dict: NSDictionary?
        appleScript?.executeAndReturnError(&dict)
        print(dict ?? "No error")
    }

    @IBAction func changeRootFolder(_ sender: Any) {
        let dialog = NSOpenPanel();
        
        dialog.title                   = "Choose a folder";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = true;
        dialog.canCreateDirectories    = true;
        dialog.allowsMultipleSelection = false;
        
        if (dialog.runModal() == .OK) {
            let result = dialog.url // Pathname of the file
            
            if (result != nil) {
                let path = result?.path
                folderPath.stringValue = path!
                UserDefaults.standard.set(path, forKey: "FolderPath")
                UserDefaults.standard.synchronize()
            }
        } else {
            // User clicked on "Cancel"
            return
        }

    }
    
    @IBAction func serverAddressChanged(_ sender: NSTextField) {
        UserDefaults.standard.set(sender.stringValue, forKey: "ServerAddress")
        UserDefaults.standard.synchronize()
        addPodcastField.stringValue = "\(serverAddressTextField.stringValue)/\(antiCachingField.stringValue)"
    }
    
    @IBAction func generatePodcastXML(_ sender: Any) {
        generateXML("podcast.xml")
    }
    
    func generateXML(_ fileName: String?) {
        let folderName = (folderPath.stringValue as NSString).lastPathComponent
        let template = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
        <channel>
        <title>\(folderName)</title>
        <link>"\(serverAddressTextField.stringValue)"</link>
        <language>en-us</language>
        <copyright>All rights reserved, \(NSFullUserName()).</copyright>
        <itunes:subtitle>\(folderName)</itunes:subtitle>
        <itunes:author>\(NSFullUserName())</itunes:author>
        <itunes:summary>\(folderName)</itunes:summary>
        <description>\(folderName)</description>
        <itunes:owner>
        <itunes:name>\(NSFullUserName())</itunes:name>
        <itunes:email>Sample@Me.com</itunes:email>
        </itunes:owner>
        <itunes:image href="https://i.imgur.com/VleTg2y.jpg"/>
        <itunes:category text="Technology">
        <itunes:category text="Gadgets"/>
        </itunes:category>
        <itunes:category text="TV &amp; Film"/>
        <itunes:category text="Arts">
        <itunes:category text="Food"/>
        </itunes:category>
        <itunes:explicit>no</itunes:explicit>
        """
        
        let endingTemplate = """
    \n
    </channel>
    </rss>
    """
        
        var text = "\(template)"
        var fileNames = try! FileManager.default.contentsOfDirectory(atPath: folderPath.stringValue)
        fileNames.sort { (name1, name2) -> Bool in
            return name1.trimmingCharacters(in: CharacterSet(charactersIn: "01234567890.").inverted) > name2.trimmingCharacters(in: CharacterSet(charactersIn: "01234567890.").inverted)
        }
        for fileName in fileNames {
            print(fileName)
            let normalizedFileName = fileName.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
            let nameWithoutExtension = (fileName as String).fileName()
            if normalizedFileName.contains("m4a") || normalizedFileName.contains("mp3") {
                do {
                    let attribute = try FileManager.default.attributesOfItem(atPath: "\(folderPath.stringValue)/\(fileName)") as NSDictionary
                    let date = attribute.fileCreationDate()
                    let byteSize = attribute.fileSize()
                    
                    let asset = AVURLAsset(url: URL(fileURLWithPath: "\(folderPath.stringValue)/\(fileName)"), options: nil)
                    let audioDuration = asset.duration
                    let audioDurationSeconds = CMTimeGetSeconds(audioDuration)
                    let lengthTuple = secondsToHoursMinutesSeconds(seconds: Int(audioDurationSeconds))
                    
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US")
                    dateFormatter.setLocalizedDateFormatFromTemplate("E, MMM d yyyy HH:mm:ss Z") // set template after setting locale
                    let podDate = dateFormatter.string(from: date!)
                    
                    let str = """
                    \n
                    <item>
                    <title>\(nameWithoutExtension)</title>
                    <itunes:author>\(NSFullUserName())</itunes:author>
                    <itunes:subtitle>\(nameWithoutExtension)</itunes:subtitle>
                    <itunes:summary><![CDATA[\(nameWithoutExtension)]]></itunes:summary>
                    <itunes:image href="https://i.imgur.com/VleTg2y.jpg"/>
                    <enclosure length="\(byteSize)" type="audio/x-m4a" url="\(serverAddressTextField.stringValue)/\(normalizedFileName)"/>
                    <guid>\(serverAddressTextField.stringValue)/\(normalizedFileName)</guid>
                    <pubDate>\(podDate)</pubDate>
                    <itunes:duration>\(lengthTuple.0):\(lengthTuple.1):\(lengthTuple.2)</itunes:duration>
                    <itunes:explicit>no</itunes:explicit>
                    </item>
                    """
                    text = text + str
                    
                } catch {print(error)}
                
            }
        }
        text = text + endingTemplate
        print(text)
        
        
        
        do {
            if let fn = fileName {
                antiCachingField.stringValue = fn
            } else {
                antiCachingField.stringValue = "\(generateRandomNumber(numDigits: 5)).xml"
            }
            let writeURL = URL(fileURLWithPath: "\(folderPath.stringValue)/\(antiCachingField.stringValue)")
            try text.write(to: writeURL, atomically: false, encoding: .utf8)
            
            if fileName != nil {
                let alert = NSAlert()
                alert.messageText = "Successfully generated XML!"
                alert.informativeText = "XML generated at \(folderPath.stringValue)/\(antiCachingField.stringValue)."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()

            }
            
        }
        catch {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "\(error)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    @IBAction func generateAndRunServer(_ sender: Any) {
        generateXML(nil)
        runServer(self)
    }
    
    @IBAction func runServer(_ sender: Any) {
        closePorts()
        let folder = folderPath.stringValue.replacingOccurrences(of: " ", with: "\\\\ ")
        let str = "tell application \"Terminal\" to do script \"cd \(folder);http-server\""
        let appleScript = NSAppleScript.init(source: str)
        var dict: NSDictionary?
        appleScript?.executeAndReturnError(&dict)
        print(dict ?? "No error")
        addPodcastField.stringValue = "Add podcast at: http://\(serverAddressTextField.stringValue)/\(antiCachingField.stringValue)"
    }
    
    func secondsToHoursMinutesSeconds (seconds : Int) -> (Int, Int, Int) {
        return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }
    
    func generateRandomNumber(numDigits: Int) -> Int {
        var place = 1
        var finalNumber = 0;
        for _ in 0..<numDigits {
            place *= 10
            let randomNumber = (Int)(arc4random_uniform(10))
            finalNumber += randomNumber * place
        }
        return finalNumber
    }
    
    func getIFAddresses() -> [String] {
        var addresses = [String]()
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        guard let firstAddr = ifaddr else { return [] }
        
        // For each interface ...
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            
            // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if (getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                        let address = String(cString: hostname)
                        addresses.append(address)
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return addresses
    }


}
extension String {
    
    func fileName() -> String {
        return NSURL(fileURLWithPath: self).deletingPathExtension?.lastPathComponent ?? ""
    }
    
    func fileExtension() -> String {
        return NSURL(fileURLWithPath: self).pathExtension ?? ""
    }
}

