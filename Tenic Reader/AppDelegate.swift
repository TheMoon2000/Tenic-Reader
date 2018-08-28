//
//  AppDelegate.swift
//  Tenic Reader
//
//  Created by Jia Rui Shan on 3/13/17.
//  Copyright © 2017 Jerry Shan. All rights reserved.
//

/* Encryption Procedure

1. Gzip Compression
2. AES-256 encryption
3. Group data into dictionary

*/

import Cocoa

let key = "Tenic"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var chooseButton: NSButton!
    @IBOutlet weak var filePath: NSTextField!
    @IBOutlet weak var infoWindow: NSWindow!
    @IBOutlet weak var filenameField: NSTextField!
    @IBOutlet weak var totalSize: NSTextField!
    @IBOutlet weak var numberOfFiles: NSTextField!
    @IBOutlet weak var filesTable: NSTableView!
    @IBOutlet weak var fileManagerWindow: NSWindow!
    @IBOutlet weak var fileManagerFilename: NSTextField!
    
    let byteFormatter = ByteCountFormatter()
        
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        infoWindow.standardWindowButton(.zoomButton)!.isHidden = true
        infoWindow.standardWindowButton(.miniaturizeButton)!.isHidden = true
        fileManagerWindow.standardWindowButton(.zoomButton)!.isHidden = true
        fileManagerWindow.standardWindowButton(.miniaturizeButton)!.isHidden = true
        byteFormatter.countStyle = .binary
        
        let fileCellNib = NSNib(nibNamed: "FileView", bundle: Bundle.main)
        filesTable.register(fileCellNib, forIdentifier: "File View")
        
        let menu = NSMenu()
        filesTable.menu = menu
        menu.delegate = self
        menu.addItem(withTitle: "Save", action: nil, keyEquivalent: "")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
   
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        
        filePath.stringValue = filename
        
        return true
    }
    
    func application(_ sender: Any, openFileWithoutUI filename: String) -> Bool {
        
        filePath.stringValue = filename
        
        return true
    }
    
    func application(_ sender: NSApplication, openFiles filenames: [String]) {

        if filenames.count == 1 {
            filePath.stringValue = filenames[0]
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @IBAction func openFile(_ sender: NSMenuItem) {
        self.selectFile(chooseButton)
    }
    
    @IBAction func dismissInfo(_ sender: NSButton) {
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
            var uncompressedData = NSKeyedUnarchiver.unarchiveObject(withFile: self.filePath.stringValue) as? [String: Data]! ?? [String: Data]()
            if uncompressedData?.count != 0 {
                uncompressedData?["._info_."] = self.filenameField.stringValue.data(using: String.Encoding.utf8)!
                NSKeyedArchiver.archiveRootObject(uncompressedData!, toFile: self.filePath.stringValue)
            }
            
            DispatchQueue.main.async {
                sender.window?.orderOut(nil)
                NSApplication.shared().stopModal()
                self.window.makeKeyAndOrderFront(nil)
                self.window.title = self.filenameField.stringValue
            }
        })
    }
    
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared().stopModal()
    }
    
    
    @IBAction func getInfo(_ sender: NSButton) {
        if NSKeyedUnarchiver.unarchiveObject(withFile: filePath.stringValue) == nil || !filePath.stringValue.hasSuffix(".tenic") {return}
        let data = getDecryptedDataFromFile(filePath.stringValue)
        numberOfFiles.integerValue = data.main.count - 1 // Because "._info_." doesn't count as a file
        totalSize.stringValue = byteFormatter.string(fromByteCount: Int64(data.size))
        filenameField.stringValue = data.title
        NSApplication.shared().runModal(for: infoWindow)
    }
    
    @IBAction func selectFile(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.title = "Please select a file:"
        panel.prompt = "Import"
        panel.showsHiddenFiles = true
        panel.treatsFilePackagesAsDirectories = true
        if panel.runModal() == 1 {
            filePath.stringValue = panel.url!.path
            if filePath.stringValue.hasSuffix(".tenic") {
                let compressedData = NSKeyedUnarchiver.unarchiveObject(withFile: filePath.stringValue) as? [String: Data] ?? ["Tenic Reader": Data()]
                window.title = String(data: compressedData["._info_."]!, encoding: String.Encoding.utf8) ?? "Untitled"
            }
        } else {
            print("cancelled")
        }
    }

    @IBAction func encrypt(_ sender: NSButton) {
        if let uncompressedData = try? Data(contentsOf: URL(fileURLWithPath: filePath.stringValue)) { // Getting data from the input
            let gzipData = (NSData.compressedData(with: uncompressedData)!) as! Data
            let data = (gzipData as NSData).aes256Encrypt(withKey: key)
            let panel = NSSavePanel()
            panel.prompt = "Export"
            panel.allowedFileTypes = ["tenic"]
            panel.nameFieldStringValue = "Archive.tenic"
            panel.title = "Export as .tenic"
            if panel.runModal() == 1 {
                let lpc = NSString(string: filePath.stringValue).lastPathComponent // Get file name
                
                let exportData = [
                "._info_.": lpc.data(using: String.Encoding.utf8),
                NSString(string: lpc).aes256Encrypt(withKey: key): data]
                
                NSKeyedArchiver.archiveRootObject(exportData, toFile: panel.url!.path) // Write data to disk
                let alert = NSAlert()
                alert.messageText = "Successfully Exported"
                alert.informativeText = "File has been saved to \(panel.url!.path)."
                alert.addButton(withTitle: "OK").keyEquivalent = "\r"
                alert.runModal()
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "File does not exist."
            alert.informativeText = "Please check the file you have specified."
            alert.addButton(withTitle: "OK").keyEquivalent = "\r"
            alert.runModal()
        }
    }
    
    func getDecryptedDataFromFile(_ filename: String) -> (main: [String: Data], title: String, size: Int) {
        let compressedData = NSKeyedUnarchiver.unarchiveObject(withFile: filename) as? [String: Data] ?? [String: Data]()
        var size = 0
        for i in Array(compressedData.values) {
            size += i.count
        }
        return (compressedData, String(data: compressedData["._info_."]!, encoding: String.Encoding.utf8)!, size)
    }
    
    @IBAction func decrypt(_ sender: NSButton) {
        if let compressedData = NSKeyedUnarchiver.unarchiveObject(withFile: filePath.stringValue) as? [String: Data] {
            
            let panel = NSSavePanel()
            panel.prompt = "Export"
            panel.nameFieldStringValue = String(data: compressedData["._info_."]!, encoding: String.Encoding.utf8) ?? "Untitled"
            panel.title = "Extract .tenic file(s)"
            
            
            if panel.runModal() == 1 {
                
                do {
                    try FileManager().createDirectory(atPath: panel.url!.path, withIntermediateDirectories: false, attributes: nil)
                } catch let error as NSError {
                    print(error)
                }
                print(Array(compressedData.keys))
                for i in Array(compressedData.keys).filter({$0 != "._info_."}) {
                    let data = (compressedData[i]! as NSData).aes256Decrypt(withKey: key)
                    let decompressedData = (NSData.data(withCompressedData: data)!) as! Data
                    let outPath = panel.url!.path + "/" + NSString(string: i).aes256Decrypt(withKey: key)
                    print(outPath)
                    try? decompressedData.write(to: URL(fileURLWithPath: outPath), options: [.atomic])
                }
                let alert = NSAlert()
                alert.messageText = "Successfully Exported"
                alert.informativeText = "File has been saved to \(panel.url!.path)."
                alert.addButton(withTitle: "OK").keyEquivalent = "\r"
                alert.runModal()
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "File does not exist."
            alert.informativeText = "Please check the file you have specified."
            alert.addButton(withTitle: "OK").keyEquivalent = "\r"
            alert.runModal()
        }
    }
    
    
    var data = [String: Data]()
    var rightclickRowIndexes = [Int]()
    
    @IBAction func presentFileManager(_ sender: NSButton) {
        if !filePath.stringValue.hasSuffix(".tenic") {return}
        data.removeAll()
        filesTable.reloadData()
        fileManagerFilename.stringValue = "Files in '" + NSString(string: filePath.stringValue).lastPathComponent + "':"
        NSApplication.shared().runModal(for: fileManagerWindow)
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if filePath.stringValue == "" {return 0}
        if data.count == 0 {
            data = NSKeyedUnarchiver.unarchiveObject(withFile: filePath.stringValue) as! [String: Data]
        }
        print(data.count - 1)
        return data.count - 1
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        rightclickRowIndexes.removeAll()
        filesTable.menu?.removeAllItems()
        let cursor = NSEvent.mouseLocation()
        let cursorInWindow = NSPoint(x: cursor.x - fileManagerWindow.frame.origin.x, y: cursor.y - fileManagerWindow.frame.origin.y)
        let currentRow = filesTable.row(at: filesTable.convert(cursorInWindow, from: fileManagerWindow.contentView!))
        if filesTable.selectedRowIndexes.contains(currentRow) && filesTable.selectedRowIndexes.count > 1 {
            filesTable.menu?.addItem(withTitle: "Export \(filesTable.selectedRowIndexes.count) items", action: #selector(AppDelegate.export(_:)), keyEquivalent: "")
            rightclickRowIndexes = Array(filesTable.selectedRowIndexes)
        } else {
            let cell = filesTable.view(atColumn: filesTable.column(withIdentifier: "File Name"), row: currentRow, makeIfNecessary: false) as! FileView
            filesTable.menu?.addItem(withTitle: "Export \"" + cell.title.stringValue + "\"", action: #selector(AppDelegate.export(_:)), keyEquivalent: "")
            rightclickRowIndexes = [currentRow]
        }
    }
    
    func export(_ sender: NSMenuItem) {
        
        let panel = NSSavePanel()
        panel.prompt = "Export"
        panel.nameFieldStringValue = String(data: data["._info_."]!, encoding: String.Encoding.utf8) ?? "Untitled"
        panel.title = "Extract .tenic file(s)"
        
        
        if panel.runModal() == 1 {
            
            do {
                try FileManager().createDirectory(atPath: panel.url!.path, withIntermediateDirectories: false, attributes: nil)
            } catch let error as NSError {
                print(error)
            }
            for i in rightclickRowIndexes {
                let cell = filesTable.view(atColumn: filesTable.column(withIdentifier: "File Name"), row: i, makeIfNecessary: false) as! FileView
                let aesKey = NSString(string: cell.title.stringValue).aes256Encrypt(withKey: key)
                let filedata = (data[aesKey!]! as NSData).aes256Decrypt(withKey: key)
                let decompressedData = (NSData.data(withCompressedData: filedata)!) as! Data
                let outPath = panel.url!.path + "/" + cell.title.stringValue
                print(outPath)
                try? decompressedData.write(to: URL(fileURLWithPath: outPath), options: [.atomic])
            }
            let alert = NSAlert()
            alert.messageText = "Successfully Exported"
            alert.informativeText = "File(s) has been saved to \(panel.url!.path)."
            alert.addButton(withTitle: "OK").keyEquivalent = "\r"
            alert.runModal()
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.make(withIdentifier: "File View", owner: self) as! FileView
        let encTitles = Array(data.keys).filter({$0 != "._info_."})
        let titles = encTitles.map({NSString(string: $0).aes256Decrypt(withKey: key)}).sorted(by: {$0 < $1}) // First decrypt titles, then sort them
        if tableColumn?.title == "File Name" {
            cell.title.stringValue = titles[row]
        } else {
            let aesKey = NSString(string: titles[row]).aes256Encrypt(withKey: key)
            let bytes = data[aesKey!]!.count
            cell.title.stringValue = byteFormatter.string(fromByteCount: Int64(bytes))
        }
        
        return cell
    }
    
    @IBAction func addFiles(_ sender: NSButton) {
        if !filePath.stringValue.hasSuffix(".tenic") {return}
        let panel = NSOpenPanel()
        panel.title = "Please select the file(s) to add:"
        panel.prompt = "Add"
        panel.showsHiddenFiles = true
        panel.treatsFilePackagesAsDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == 1 {
            var oldData = NSKeyedUnarchiver.unarchiveObject(withFile: filePath.stringValue) as? [String: Data] ?? ["._info_.": "Untitled".data(using: String.Encoding.utf8)!]
            for i in panel.urls.map({$0.path}) {
                let rawfiledata = try! Data(contentsOf: URL(fileURLWithPath: i))
                let filedata = ((NSData.compressedData(with: rawfiledata) as! Data) as NSData).aes256Encrypt(withKey: key)
                oldData[NSString(string: NSString(string: i).lastPathComponent).aes256Encrypt(withKey: key)] = filedata
            }
            data = oldData
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
                NSKeyedArchiver.archiveRootObject(oldData, toFile: self.filePath.stringValue)
            })
            filesTable.reloadData()
            let alert = NSAlert()
            alert.messageText = "Updated Tenic file " + NSString(string: filePath.stringValue).lastPathComponent + "."
            alert.informativeText = "\(panel.urls.count) file\(panel.urls.count == 1 ? " has" : "s have") been added."
            alert.addButton(withTitle: "OK").keyEquivalent = "\r"
            alert.runModal()
        } else {
            print("cancelled")
        }
    }

    @IBAction func removeFiles(_ sender: NSButton) {
        let rows = filesTable.selectedRowIndexes
        for i in rows {
            let cell = filesTable.view(atColumn: filesTable.column(withIdentifier: "File Name"), row: i, makeIfNecessary: false) as! FileView
            let aesKey = NSString(string: cell.title.stringValue).aes256Encrypt(withKey: key)
            data.removeValue(forKey: aesKey!)
        }
        filesTable.removeRows(at: rows, withAnimation: .effectFade)
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
            NSKeyedArchiver.archiveRootObject(self.data, toFile: self.filePath.stringValue)
        })
    }
    
    
}

