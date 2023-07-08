import Cocoa
import AVFoundation
import AVKit
import QuickLook

class ViewController: NSViewController {
    var document: Document? {
        return self.view.window?.windowController?.document as? Document
    }
    
    var viewMIDIPlayer: AVMIDIPlayer? {
        return document?.theMIDIPlayer
    }
    
    var myTimer: Timer?
    
    @IBOutlet var currentTimeField: NSTextField!
    @IBOutlet var theSlider: NSSlider!
    @IBOutlet var endTimeField: NSTextField!
    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var loopCheckbox: NSButton!  // Outlet for the loop checkbox
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        currentTimeField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        endTimeField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard let midiPlayer = viewMIDIPlayer else {
            print("Error: MIDI Player is not available")
            return
        }
        
        theSlider.maxValue = midiPlayer.duration
        midiPlayer.prepareToPlay()
        
        let time = midiPlayer.duration
        let timeString = formattedTimeString(time)
        endTimeField.stringValue = timeString
        
        myTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateDisplay), userInfo: nil, repeats: true)
    }
    
    @IBAction func playSwitch(_ sender: NSButton) {
        guard let midiPlayer = viewMIDIPlayer else { return }
        
        if midiPlayer.isPlaying {
            midiPlayer.stop()
        } else {
            midiPlayer.play {
                self.completed()
            }
        }
    }
    
    @IBAction func moveSlider(_ sender: Any) {
        guard let midiPlayer = viewMIDIPlayer else { return }
        
        midiPlayer.stop()
        midiPlayer.currentPosition = theSlider.doubleValue
        updateDisplay()
        playButton.state = .on
        midiPlayer.prepareToPlay()
        midiPlayer.play {
            self.completed()
        }
    }
    
    @IBAction func backToStart(_ sender: Any) {
        guard let midiPlayer = viewMIDIPlayer else { return }
        
        midiPlayer.stop()
        midiPlayer.currentPosition = 0
        playButton.state = .on
        midiPlayer.prepareToPlay()
        midiPlayer.play {
            self.completed()
        }
    }
    
    func completed() {
        if let midiPlayer = viewMIDIPlayer {
            if midiPlayer.currentPosition >= (midiPlayer.duration - 1) {
                if self.loopCheckbox.state == .on {
                    midiPlayer.currentPosition = 0
                    midiPlayer.prepareToPlay()
                    midiPlayer.play {
                        self.completed()
                    }
                } else {
                    self.playButton.state = .off
                }
            } else {
                self.playButton.state = .off
            }
        }
    }
    
    @objc func updateDisplay() {
        guard let midiPlayer = viewMIDIPlayer else { return }
        
        if midiPlayer.currentPosition <= midiPlayer.duration {
            theSlider.doubleValue = midiPlayer.currentPosition
            let timeString = formattedTimeString(midiPlayer.currentPosition)
            currentTimeField.stringValue = timeString
        }
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        document?.theMIDIPlayer = nil
        myTimer?.invalidate()
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    private func formattedTimeString(_ time: TimeInterval) -> String {
        let hours = Int(floor(time / 3600))
        let minutes = Int(floor((time.truncatingRemainder(dividingBy: 3600)) / 60))
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
