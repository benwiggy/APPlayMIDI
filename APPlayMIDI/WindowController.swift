//
//  WindowController.swift
//  APPlayMIDI
//
//  Created by Ben Byram-Wigfield on 22/10/2019.
//  Copyright © 2019 Ben. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {

    required init?(coder: NSCoder) {
      super.init(coder: coder)
      shouldCascadeWindows = true
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }

}
