//
//  PreviewViewController.swift
//  qlMIDI
//
//  Created by Ben on 04/07/2022.
//  Copyright © 2022 Ben. All rights reserved.
//

import Cocoa
import Quartz
import AVFoundation

class PreviewViewController: NSViewController, QLPreviewingController {
    
    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    var viewMIDIPlayer: AVMIDIPlayer!
    
    var myTimer: Timer?
    
    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var theSlider: NSProgressIndicator!
    
   

    @IBAction func playSwitch(_ sender: NSButton) {
              if (viewMIDIPlayer!.isPlaying) {
            viewMIDIPlayer!.stop()
        } else {
        viewMIDIPlayer!.play(self.completed())
        }
    }
    
    @IBAction func backToStart(_ sender: Any) {
        if viewMIDIPlayer != nil {
           self.viewMIDIPlayer!.stop()
            viewMIDIPlayer!.currentPosition = TimeInterval(0)
          playButton.state=NSControl.StateValue.on
            viewMIDIPlayer!.prepareToPlay()
            viewMIDIPlayer!.play(self.completed())
    }
    }
    
    func completed() -> AVMIDIPlayerCompletionHandler {
        return {
            if self.viewMIDIPlayer!.isPlaying == false {
                self.playButton.state=NSControl.StateValue.off
            }
         }
    }
    
    /*
     * Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.
     *
    func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler handler: @escaping (Error?) -> Void) {
        // Perform any setup necessary in order to prepare the view.
        
        // Call the completion handler so Quick Look knows that the preview is fully loaded.
        // Quick Look will display a loading spinner while the completion handler is not called.
        handler(nil)
     */
    
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        
        do {
        viewMIDIPlayer = try AVMIDIPlayer.init(contentsOf: url, soundBankURL: nil)
            
            viewMIDIPlayer?.prepareToPlay()
           theSlider.maxValue = Double(self.viewMIDIPlayer?.duration ?? 0.0)
    } catch {
        NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
    
        // Add the supported content types to the QLSupportedContentTypes array in the Info.plist of the extension.
        
        // Perform any setup necessary in order to prepare the view.
        
        // Call the completion handler so Quick Look knows that the preview is fully loaded.
        // Quick Look will display a loading spinner while the completion handler is not called.
       
        myTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateDisplay), userInfo: nil, repeats: true)
        
        handler(nil)
    }
    
    override func viewWillDisappear() {
        if (viewMIDIPlayer!.isPlaying) {
      viewMIDIPlayer!.stop()
        }
        // viewMIDIPlayer = nil
        myTimer?.invalidate()
        super.viewWillDisappear()
    }

    
    @objc func updateDisplay(){
        if viewMIDIPlayer != nil {
            if viewMIDIPlayer!.currentPosition <= viewMIDIPlayer!.duration {
                theSlider.doubleValue = Double((viewMIDIPlayer!.currentPosition))
            }
            }
    }
    }
    
