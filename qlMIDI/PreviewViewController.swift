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

    @IBOutlet weak var quickLookView: NSView!
    @IBOutlet weak var finderView: NSView!

    @IBOutlet weak var finderPlayButton: NSButton!
    @IBOutlet weak var finderRestartButton: NSButton!
    @IBOutlet weak var finderProgressCircle: NSProgressIndicator!

    @IBOutlet weak var totalTimeLabel: NSTextField!
    @IBOutlet weak var currentPlaybackTimeLabel: NSTextField!
    @IBOutlet weak var filenameLabel: NSTextField!
    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var restartButton: NSButton!
    @IBOutlet weak var theSlider: NSProgressIndicator!
    
    override func loadView() {
        super.loadView()
        preferredContentSize = CGSize(width: 800, height: 350)

        finderPlayButton.target = self
        finderPlayButton.action = #selector(self.playPause)
        finderRestartButton.target = self
        finderRestartButton.action = #selector(self.restart)

        playButton.target = self
        playButton.action = #selector(self.playPause)
        restartButton.target = self
        restartButton.action = #selector(self.restart)
    }

    @objc func playPause() {
        guard let midiPlayer = viewMIDIPlayer else { return }
        if (midiPlayer.isPlaying) {
            midiPlayer.stop()
        } else {
            midiPlayer.play(self.completed())
        }
    }

    @objc func restart() {
        guard let midiPlayer = viewMIDIPlayer else { return }

        midiPlayer.currentPosition = TimeInterval(0)
        playButton.state = NSControl.StateValue.on
        finderPlayButton.state = NSControl.StateValue.on
        midiPlayer.prepareToPlay()
        midiPlayer.play (
            self.completed()
        )
    }
    
    func completed() -> AVMIDIPlayerCompletionHandler {
        return {
            self.playButton.state = .off
            self.finderPlayButton.state = .off
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

            finderProgressCircle.maxValue = Double(self.viewMIDIPlayer?.duration ?? 0.0)
            filenameLabel.stringValue = url.lastPathComponent
            filenameLabel.frame.size.width = CGFloat(filenameLabel.stringValue.count * 13)
            currentPlaybackTimeLabel.stringValue = "0:00"

            if let time = self.viewMIDIPlayer?.duration {
                let minutes = Int(time / 60)
                let seconds = Int((time)) % 60
                totalTimeLabel.stringValue =  String(format: "%01d:%02d", minutes, seconds)
            }

            handler(nil) // Call handler with nil to indicate success
        } catch {
            handler(error) // Call handler with the caught error
        }
    }

    override func viewDidAppear() {
        if let width = self.view.window?.frame.width, width < 600.0 {
            //Finder View
            self.finderView.isHidden = false
            self.quickLookView.isHidden = true
        } else {
            // QuickLook Window
            self.finderView.isHidden = true
            self.quickLookView.isHidden = false

            self.viewMIDIPlayer?.play(self.completed())
            self.playButton.state = .on
        }

        super.viewDidAppear()
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
                if let currentPosition = self.viewMIDIPlayer?.currentPosition {
                    let minutes = Int(currentPosition / 60)
                    let seconds = Int((currentPosition)) % 60
                    currentPlaybackTimeLabel.stringValue =  String(format: "%01d:%02d", minutes, seconds)
                    finderProgressCircle.doubleValue = Double((viewMIDIPlayer!.currentPosition))
                }
            }
        }
    }
}

