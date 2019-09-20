//
//  Document.swift
//  APPlayMIDI
//
//  Created by Ben on 20/08/2019.
//  Copyright © 2019 Ben. All rights reserved.
//

import Cocoa
import AVFoundation
import AppKit

// Create a PasteboardType for MIDI data
extension NSPasteboard.PasteboardType {
    static let typeMidi = NSPasteboard.PasteboardType(rawValue: "public.midi-audio")
}

class Document: NSDocument {
    var theMIDIPlayer: AVMIDIPlayer?
    var myData: Data?

    override init() {
        super.init()
    }

    override class var autosavesInPlace: Bool {
        return false
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        self.addWindowController(windowController)
    }
    
    @IBAction func copy(_: Any)  {
      let pboard = NSPasteboard.general
        pboard.clearContents()
        pboard.setData(myData, forType: .typeMidi)
    }

 //   override func data(ofType typeName: String) throws -> Data {
  //      throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
 //   }
    
    override func read(from data: Data, ofType typeName: String) throws {
        self.theMIDIPlayer = try AVMIDIPlayer.init(data: data, soundBankURL: nil)
        self.myData = data
        if self.theMIDIPlayer == nil {
             throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
    }
}
