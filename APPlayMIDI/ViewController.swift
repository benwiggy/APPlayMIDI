//
//  ViewController.swift
//  APPlayMIDI
//
//  Created by Ben on 20/08/2019.
//  Copyright © 2019 Ben. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit
import QuickLook

class ViewController: NSViewController {
    var document: Document? {
        return self.view.window?.windowController?.document as? Document
    }
    
    var viewMIDIPlayer: AVMIDIPlayer? {
        return document?.theMIDIPlayer!
    }
    
    var myTimer: Timer?
    
    @IBOutlet var currentTimeField: NSTextField!
    @IBOutlet var theSlider: NSSlider!    
    @IBOutlet var endTimeField: NSTextField!
    @IBOutlet weak var playButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear() {
        theSlider.maxValue = Double(document!.theMIDIPlayer!.duration)
        viewMIDIPlayer!.prepareToPlay()
        if let time = document!.theMIDIPlayer?.duration {
            let hours = Int(floor(time / 3600))
            let minutes = Int(floor(time / 60))
            let seconds = Int((time)) % 60
            let timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        endTimeField.stringValue = timeString
        }
        
        myTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateDisplay), userInfo: nil, repeats: true)
    }
    
    @IBAction func playSwitch(_ sender: NSButton) {
              if (viewMIDIPlayer!.isPlaying) {
            viewMIDIPlayer!.stop()
              } else {
        viewMIDIPlayer!.play(self.completed())
        }
    }
    
    
    @IBAction func moveSlider(_ sender: Any) {
        viewMIDIPlayer!.stop()
        viewMIDIPlayer!.currentPosition = TimeInterval(theSlider.doubleValue)
       updateDisplay()
        playButton.state=NSControl.StateValue.on
        viewMIDIPlayer!.prepareToPlay()
        viewMIDIPlayer!.play(self.completed())
    }
    
    @IBAction func backToStart(_ sender: Any){
        viewMIDIPlayer!.stop()
        viewMIDIPlayer!.currentPosition = TimeInterval(0)
        playButton.state=NSControl.StateValue.on
        viewMIDIPlayer!.prepareToPlay()
        viewMIDIPlayer!.play(self.completed())
    
    }
    
    
    func completed() -> AVMIDIPlayerCompletionHandler {
        return {

            if self.viewMIDIPlayer!.isPlaying == false {
            self.playButton.state=NSControl.StateValue.off
         }
        }
        }
    
    
    @objc func updateDisplay(){
        if viewMIDIPlayer != nil {
        if viewMIDIPlayer!.currentPosition <= viewMIDIPlayer!.duration {
            theSlider.doubleValue = Double((viewMIDIPlayer!.currentPosition))
            let time = viewMIDIPlayer!.currentPosition
                let hours = Int(floor(time / 3600))
                let minutes = Int(floor(time / 60))
                let seconds = Int((time)) % 60
                let timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        currentTimeField.stringValue = timeString
            }
            }
    }
    
    override func viewDidDisappear() {
          document!.theMIDIPlayer = nil
          myTimer?.invalidate()
          super.viewDidDisappear()
      }



    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

