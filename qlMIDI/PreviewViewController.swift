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
    
    override func loadView() {
        super.loadView()
    }

    @IBAction func playSwitch(_ sender: NSButton) {
        guard let midiPlayer = viewMIDIPlayer else { return }
              if (midiPlayer.isPlaying) {
            midiPlayer.stop()
        } else {
        midiPlayer.play(self.completed())
        }
    }
    
    @IBAction func backToStart(_ sender: Any) {
        guard let midiPlayer = viewMIDIPlayer else { return }

            midiPlayer.currentPosition = TimeInterval(0)
          playButton.state = .on
            midiPlayer.prepareToPlay()
        midiPlayer.play (
            self.completed()
        )
    }
    
    func completed() -> AVMIDIPlayerCompletionHandler {
        return {
            self.playButton.state = .off
            
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
            viewMIDIPlayer = try AVMIDIPlayer(contentsOf: url, soundBankURL: nil)
            viewMIDIPlayer?.prepareToPlay()
            theSlider.maxValue = Double(viewMIDIPlayer?.duration ?? 0.0)
            
            myTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateDisplay), userInfo: nil, repeats: true)
            
            
            handler(nil) // Call handler with nil to indicate success
        } catch {
            handler(error) // Call handler with the caught error
        }
    }
    
    override func viewWillDisappear() {
        if (viewMIDIPlayer!.isPlaying) {
      viewMIDIPlayer!.stop()
        }
        viewMIDIPlayer = nil
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
    
