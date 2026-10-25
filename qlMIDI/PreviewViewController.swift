//
//  PreviewViewController.swift
//  qlMIDI
//
//  SwiftUI rewrite: no .xib or IBOutlets needed.
//  Requires macOS 11+ (SF Symbols, ProgressView, Logger) and Xcode 14+ (Swift 5.7).
//
//  Diagnostics: all log lines use subsystem "qlMIDI". Watch them with
//    log stream --predicate 'subsystem == "qlMIDI"'
//  or in Console.app (search: subsystem:qlMIDI).
//

import Cocoa
import Quartz
import SwiftUI
import AVFoundation
import os

// private let log = Logger(subsystem: "qlMIDI", category: "preview")

// MARK: - Mode heuristic

/// Quick Look gives its window the extension's preferredContentSize (800 x 350),
/// whereas the Finder preview pane is as wide as the pane happens to be.
/// There is no documented API to tell the two apart, so we judge by the
/// width of our own view (not the window's frame).
enum PreviewMode {
    static let preferredSize = NSSize(width: 800, height: 350)
    static let compactThreshold: CGFloat = 600

    static func isCompact(width: CGFloat) -> Bool { width < compactThreshold }
}

// MARK: - Model

final class MIDIPlayerModel: ObservableObject {
    @Published private(set) var filename = ""
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var isPlaying = false

    private var player: AVMIDIPlayer?
    private var timer: Timer?
    /// Incremented on every start/stop so stale completion handlers can be ignored.
    private var playToken = 0
    /// Right after play() the engine may not report isPlaying yet; don't resync before this.
    private var resyncNotBefore = Date.distantPast

    deinit { timer?.invalidate() }

    func load(url: URL) throws {
        let p = try AVMIDIPlayer(contentsOf: url, soundBankURL: nil)
        p.prepareToPlay()
        player = p
        filename = url.lastPathComponent
        duration = p.duration
        position = 0
        isPlaying = false
        startTimer()
    }

    // MARK: Transport

    /// Decides from the *engine's* state, not our own flag, so a stale UI
    /// state can never turn a press into a no-op.
    func togglePlay() {
        guard let player = player else {
            return
        }
        if player.isPlaying { pause() } else { play() }
    }

    func play() {
        guard let player = player, !player.isPlaying else { return }

        // After a finished run the position sits at the end; starting from
        // there would "play" nothing.
        if player.currentPosition >= max(duration - 0.05, 0) {
            player.currentPosition = 0
        }
        player.prepareToPlay()

        playToken += 1
        let token = playToken
        isPlaying = true
        resyncNotBefore = Date().addingTimeInterval(0.5)

        // The completion handler arrives on a non-main thread.
        player.play { [weak self] in
            DispatchQueue.main.async { self?.playbackEnded(token: token) }
        }
    }

    func pause() {
        guard let player = player else { return }
        playToken += 1                 // invalidates any pending completion handler
        isPlaying = false
        player.stop()
        position = min(player.currentPosition, duration)
    }

    func restart() {
        guard let player = player else { return }
        playToken += 1
        isPlaying = false
        player.stop()
        player.currentPosition = 0
        position = 0
        play()
    }

    /// Release everything (call when the controller is going away for good).
    func tearDown() {
        playToken += 1
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        isPlaying = false
    }

    // MARK: Click routing

    /// Frames of the on-screen buttons, in the hosting view's top-left coordinate
    /// space. Filled in by the SwiftUI layout; deliberately not @Published.
    var buttonFrames: [TransportButton: CGRect] = [:]

    /// Called from the hosting view's mouseDown. Returns true if a button took the click.
    func handleClick(at point: CGPoint) -> Bool {
        for (button, frame) in buttonFrames where frame.insetBy(dx: -6, dy: -6).contains(point) {
            switch button {
            case .playPause:   togglePlay()
            case .restart:     restart()
            case .progressBar: beginScrub(at: point)
            }
            return true
        }
        return false
    }

    // MARK: Scrubbing

    /// True between mouse-down and mouse-up on the progress bar. Not @Published.
    private(set) var isScrubbing = false
    private var resumeAfterScrub = false

    /// Pauses playback (remembering whether it was running) and jumps to the click.
    func beginScrub(at point: CGPoint) {
        guard let player = player, buttonFrames[.progressBar] != nil else { return }
        isScrubbing = true
        resumeAfterScrub = player.isPlaying
        if resumeAfterScrub { pause() }
        scrub(to: point)
    }

    func scrub(to point: CGPoint) {
        guard isScrubbing, let player = player,
              let bar = buttonFrames[.progressBar], bar.width > 0 else { return }
        let fraction = min(max((point.x - bar.minX) / bar.width, 0), 1)
        // Stay just short of the very end so releasing there doesn't restart the file.
        let target = min(Double(fraction) * duration, max(duration - 0.1, 0))
        player.currentPosition = target
        position = target
    }

    /// Resumes playback if it was running when the scrub began.
    func endScrub() {
        guard isScrubbing else { return }
        isScrubbing = false
        let resume = resumeAfterScrub
        resumeAfterScrub = false
        if resume { play() }
    }

    // MARK: Internals

    private func playbackEnded(token: Int) {
        guard token == playToken, isPlaying, let player = player else {
            return
        }
        isPlaying = false
        // Rewind only if we genuinely reached the end.
        if player.currentPosition >= duration - 0.25 {
            player.currentPosition = 0
            player.prepareToPlay()
            position = 0
        }
    }

    /// Runs for the lifetime of the loaded file: updates the position and
    /// corrects the UI if the engine has silently stopped.
    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)   // keeps ticking while the UI is tracking
        timer = t
    }

    private func tick() {
        guard let player = player, !isScrubbing else { return }
        let newPosition = min(player.currentPosition, duration)
        if newPosition != position { position = newPosition }

        if isPlaying && !player.isPlaying && Date() > resyncNotBefore {
            playbackEnded(token: playToken)
            if isPlaying { isPlaying = false }
        }
    }
}

// MARK: - Helpers

private func formatTime(_ t: TimeInterval) -> String {
    let total = Int(max(t, 0))
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - Button hit regions

enum TransportButton: Hashable {
    case playPause
    case restart
    case progressBar
}

struct ButtonFramesKey: PreferenceKey {
    static var defaultValue: [TransportButton: CGRect] = [:]
    static func reduce(value: inout [TransportButton: CGRect], nextValue: () -> [TransportButton: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marks a view as a button whose clicks are handled by the hosting view's
    /// mouseDown (see FirstMouseHostingView), reporting its frame for hit-testing.
    func transportButton(_ id: TransportButton) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: ButtonFramesKey.self,
                                       value: [id: geo.frame(in: .named("player"))])
            }
        )
    }
}

// MARK: - Views

struct PlayerView: View {
    @ObservedObject var model: MIDIPlayerModel

    var body: some View {
        GeometryReader { geo in
            Group {
                if PreviewMode.isCompact(width: geo.size.width) {
                    CompactPlayerView(model: model)
                } else {
                    WidePlayerView(model: model)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(name: "player")
            .onPreferenceChange(ButtonFramesKey.self) { model.buttonFrames = $0 }
        }
    }
}

/// Finder preview pane: circular progress ring around a play/pause button.
struct CompactPlayerView: View {
    @ObservedObject var model: MIDIPlayerModel

    private var fraction: Double {
        model.duration > 0 ? min(model.position / model.duration, 1) : 0
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(model.filename)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(fraction))
                    .stroke(Color.accentColor,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26))
                    .frame(width: 60, height: 60)
                    .transportButton(.playPause)
            }
            .frame(width: 84, height: 84)

            HStack(spacing: 14) {
                Image(systemName: "backward.end.fill")
                    .frame(width: 24, height: 24)
                    .transportButton(.restart)
                    .help("Restart")

                Text("\(formatTime(model.position)) / \(formatTime(model.duration))")
                    .font(Font.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Quick Look window: transport buttons and a horizontal bar with times at each end.
struct WidePlayerView: View {
    @ObservedObject var model: MIDIPlayerModel

    var body: some View {
        VStack(spacing: 24) {
            Text(model.filename)
                .font(.title2)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 28) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 22))
                    .frame(width: 36, height: 36)
                    .transportButton(.restart)
                    .help("Restart")

                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 34))
                    .frame(width: 44, height: 44)
                    .transportButton(.playPause)
            }

            HStack(spacing: 10) {
                Text(formatTime(model.position))
                ScrubBar(fraction: model.duration > 0 ? min(model.position / model.duration, 1) : 0)
                    .frame(height: 24)
                    .transportButton(.progressBar)
                Text(formatTime(model.duration))
            }
            .font(Font.callout.monospacedDigit())
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Horizontal track with a draggable-looking marker. Purely visual: the
/// hosting view's mouse events do the actual scrubbing.
struct ScrubBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            let x = geo.size.width * CGFloat(fraction)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: x, height: 4)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 14, height: 14)
                    .offset(x: x - 7)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Hosting

/// Lets the first click on a button act immediately, instead of just
/// activating/focusing the Quick Look or Finder preview view.
/// The log lines show whether AppKit consults us and whether clicks arrive.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    /// Receives the click point in top-left coordinates; returns true if handled.
    var onClick: ((CGPoint) -> Bool)?

    /// SwiftUI's own Button gesture proved unreliable here (mouseDown arrived
    /// but the action never fired), so transport clicks are handled directly.
    override func mouseDown(with event: NSEvent) {
        let topLeft = topLeftPoint(of: event)
        let handled = onClick?(topLeft) ?? false
        clickWasHandled = handled
        if !handled { super.mouseDown(with: event) }
    }

    /// Drag and release continue to be routed to the view that got the mouse-down,
    /// even when the pointer leaves it, which is what scrubbing needs.
    var onDrag: ((CGPoint) -> Void)?
    var onMouseUp: (() -> Void)?
    private var clickWasHandled = false

    override func mouseDragged(with event: NSEvent) {
        if clickWasHandled { onDrag?(topLeftPoint(of: event)) } else { super.mouseDragged(with: event) }
    }

    override func mouseUp(with event: NSEvent) {
        if clickWasHandled {
            onMouseUp?()
            clickWasHandled = false
        } else {
            super.mouseUp(with: event)
        }
    }

    private func topLeftPoint(of event: NSEvent) -> CGPoint {
        let p = convert(event.locationInWindow, from: nil)
        return CGPoint(x: p.x, y: isFlipped ? p.y : bounds.height - p.y)
    }
}

// MARK: - Controller

class PreviewViewController: NSViewController, QLPreviewingController {

    private let model = MIDIPlayerModel()
    private var hasAutoStarted = false

    override func loadView() {
        preferredContentSize = PreviewMode.preferredSize

        let container = NSView(frame: NSRect(origin: .zero, size: PreviewMode.preferredSize))
        let host = FirstMouseHostingView(rootView: PlayerView(model: model))
        host.onClick = { [model] point in model.handleClick(at: point) }
        host.onDrag = { [model] point in model.scrub(to: point) }
        host.onMouseUp = { [model] in model.endScrub() }
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        view = container
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            try model.load(url: url)
            handler(nil)
        } catch {
            handler(error)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Let the first layout pass finish so the width is the real one,
        // then auto-play only in the (wide) Quick Look window.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.hasAutoStarted else { return }
            self.hasAutoStarted = true
            if !PreviewMode.isCompact(width: self.view.bounds.width) {
                self.model.play()
            }
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        // Only silence playback here. If the host ever hides and re-shows
        // the same view, the player must still be usable.
        model.pause()
    }

    deinit {
        model.tearDown()
    }
}
