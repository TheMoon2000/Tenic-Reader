//
//  FileView.swift
//  Tenic Reader
//
//  Created by Jia Rui Shan on 3/13/17.
//  Copyright © 2017 Jerry Shan. All rights reserved.
//

import Cocoa

class FileView: NSTableCellView {
    
    @IBOutlet weak var title: NSTextField!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
    }
    
    override var backgroundStyle: NSBackgroundStyle {
        didSet {
            if backgroundStyle == .dark {
                title.textColor = NSColor.white
            } else {
                title.textColor = NSColor.black
            }
        }
    }
    
}
