import AppKit

class AnimationWindow: NSWindow {
    var didClose: () -> Void
    
    init(frame parentFrame: NSRect, viewType: AnimationView.Type, didClose: @escaping () -> Void) {
        self.didClose = didClose
        
        let fullFrame = parentFrame.insetBy(
            dx: -viewType.frameSize.width / 2,
            dy: -viewType.frameSize.height / 2
        )
        let intersectedFrame = NSScreen.main!.visibleFrame.intersection(fullFrame)
        
        super.init(
            contentRect: NSRect(
                x: fullFrame.minX,
                y: intersectedFrame.minY,
                width: fullFrame.width,
                height: intersectedFrame.height
            ),
            styleMask: .borderless, backing: .nonretained, defer: true
        )
        
        contentView!.setBoundsOrigin(NSPoint(x: 0, y: intersectedFrame.minY - fullFrame.minY))
        
        backgroundColor = .clear
        isReleasedWhenClosed = true
        ignoresMouseEvents = true
    }
    
    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        didClose()
    }
}

class AnimationView: NSImageView {
    class var frames: [NSImage] {[]}
    class var frameDuration: TimeInterval {0}
    class var frameSize: NSSize {frames[0].size}
    
    var frameIndex: Int = 0
    
    required init(center: NSPoint, moundFrameSize: NSSize) {
        super.init(frame: NSRect(origin: center, size: Self.frameSize))
    }
    
    required init?(coder: NSCoder) {nil}
    
    func stopAnimation() {
        frameIndex = Self.frames.count
    }
    
    func startAnimation(then callback: @escaping () -> Void) {
        frameIndex = 0
        animate(then: callback)
    }
    
    func animate(then callback: @escaping () -> Void) {
        if frameIndex < Self.frames.count {
            image = Self.frames[frameIndex]
            frameIndex += 1
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Self.frameDuration) {
                self.animate(then: callback)
            }
        } else {
            callback()
        }
    }
}

final class BoomView: AnimationView {
    static let indexOfMaxContentFrame: Int = 4
    static let _frames: [NSImage] = {
        var frames: [NSImage] = []
        for i in 1...14 {
            frames.append(NSImage(named: "Boom\(i)")!)
        }
        return frames
    }()
    
    override class var frames: [NSImage] {_frames}
    override class var frameDuration: TimeInterval {0.05}
}

final class ShineView: AnimationView {
    static let initialMoundFrameSize: NSSize = NSSize(width: 22, height: 22)
    static let _frames: [NSImage] = {
        let indexOfMiddleFrame: Int = 8
        
        var frames: [NSImage] = []
        for i in 1...14 {
            let image = NSImage(named: "Shine\(i)")!
            
            let topInset = round(image.size.height / 2 + CGFloat(i - 1 - indexOfMiddleFrame) / 14 * (initialMoundFrameSize.height / 2 - 1))
            image.capInsets = NSEdgeInsets(
                top: topInset,
                left: 38,
                bottom: image.size.height - topInset - 1,
                right: 38
            )
            image.resizingMode = .stretch
            
            frames.append(image)
        }
        
        return frames
    }()
    
    override class var frames: [NSImage] {_frames}
    override class var frameDuration: TimeInterval {0.06}
    
    required init(center: NSPoint, moundFrameSize: NSSize) {
        super.init(center: center, moundFrameSize: moundFrameSize)
        
        frame = frame.insetBy(
            dx: (moundFrameSize.width - Self.initialMoundFrameSize.width) / -2,
            dy: (moundFrameSize.height - Self.initialMoundFrameSize.height) / -2
        )
        
        self.imageScaling = .scaleAxesIndependently
    }
    
    required init?(coder: NSCoder) {nil}
}
