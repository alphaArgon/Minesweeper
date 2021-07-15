import AppKit

class SmileyButton: NSButton {
    enum Emotion {
        case sad
        case happy
    }
    
    static let sadMac = NSImage(named: "SadMac")!
    static let happyMacEyes = NSImage(named: "HappyMacEyes")!
    static let happyMacCheek = NSImage(named: "HappyMacCheek")!
    static func happyMac(eyesOffset: NSPoint = .zero) -> NSImage {
        let image = Self.happyMacCheek.copy() as! NSImage
        image.lockFocusFlipped(true)
        
        var operation = NSCompositingOperation.sourceOver
        if #available(OSX 10.14, *), NSAppearance.current.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            operation = .destinationOut
        }
        Self.happyMacEyes.draw(in: NSRect(
            origin: eyesOffset, size: image.size
        ), from: .zero, operation: operation, fraction: 1, respectFlipped: true, hints: nil)
        image.unlockFocus()
        
        return image
    }
    
    static func convert(transitionProgress progress: CGFloat) -> CGFloat {
        return pow(sin(0.5 * .pi * progress), 2)
    }
    
    static func attenuate(value: CGFloat, byLimit limit: CGFloat, smoothing: CGFloat) -> CGFloat {
        return limit * tanh(value / limit / smoothing)
    }
    
    static func eyesOffset(from rawOffset: NSPoint) -> NSPoint {
        NSPoint(
            x: attenuate(value: rawOffset.x, byLimit: 1.3, smoothing: 10),
            y: attenuate(value: rawOffset.y, byLimit: 1.8, smoothing: 5)
        )
    }
    
    var emotion: Emotion = .happy {
        didSet {setNeedsDisplay()}
    }
    
    private var trackingArea : NSTrackingArea?
    
    private var transitionProgress: CGFloat = 1
    private var transitionOrigin: NSPoint = .zero
    private var transitionDestination: NSPoint = .zero
    private var transitionPresent: NSPoint = .zero {
        didSet {setNeedsDisplay()}
    }
    
    init(target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.target = target
        self.action = action
        self.image = Self.sadMac
    }
    
    required init?(coder: NSCoder) {nil}
    
    func startTransition() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.03) {
            self.transitionProgress = min(1, self.transitionProgress + 0.1)
            let progress = Self.convert(transitionProgress: self.transitionProgress)
            self.transitionPresent = NSPoint(
                x: progress * self.transitionDestination.x + (1 - progress) * self.transitionOrigin.x,
                y: progress * self.transitionDestination.y + (1 - progress) * self.transitionOrigin.y
            )
            
            if self.transitionProgress < 1 {
                self.startTransition()
            }
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        guard emotion == .happy else {return}
        
        transitionOrigin = transitionPresent
        if transitionProgress == 1 {
            startTransition()
        }
        transitionProgress = 0
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        transitionDestination = NSPoint(x: location.x - bounds.midX, y: location.y - bounds.midY)
        if transitionProgress == 1 || emotion != .happy {
            transitionPresent = transitionDestination
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard emotion == .happy else {return}
        
        transitionOrigin = transitionPresent
        transitionDestination = .zero
        if transitionProgress == 1 {
            startTransition()
        }
        transitionProgress = 0
    }
    
    override func updateTrackingAreas() {
        if trackingArea != nil {removeTrackingArea(trackingArea!)}
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        switch emotion {
        case .sad:
            image = Self.sadMac
        case .happy:
            image = Self.happyMac(eyesOffset: Self.eyesOffset(from: transitionPresent))
        }
        super.draw(dirtyRect)
    }
}
