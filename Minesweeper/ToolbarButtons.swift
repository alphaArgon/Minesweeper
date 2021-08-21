import AppKit

class ToolbarButton: NSButton {
    var isDisabled: Bool = false
    
    override var acceptsFirstResponder: Bool {false}
    
    override func mouseDown(with event: NSEvent) {
        if isDisabled {
            nextResponder?.mouseDown(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
}

class ImagedButton: ToolbarButton {
    var width: CGFloat?
    var attributes: [NSAttributedString.Key: Any]
    
    init(widthOfTitle title: String, attributes anAttributes: [NSAttributedString.Key: Any]) {
        attributes = anAttributes
        attributes[.font] = attributes[.font] ?? NSFont.systemFont(ofSize: -1)
        let attributedTitle = NSAttributedString(string: title, attributes: attributes)
        let size = attributedTitle.size()
        width = ceil(size.width)
        super.init(frame: .zero)
        image = NSImage(size: NSSize(width: width!, height: size.height))
    }
    
    required init?(coder: NSCoder) {nil}
    
    override var title: String {
        set {
            let attributedTitle = NSAttributedString(string: newValue, attributes: attributes)
            let textWidth = ceil(attributedTitle.size().width)
            let capHeight = round((attributes[.font] as! NSFont).capHeight)
            let heightInset = -ceil((attributes[.font] as! NSFont).descender)
            let textImage = NSImage(size: NSSize(width: ceil(max(width ?? textWidth, textWidth)), height: capHeight + 2 * heightInset))
            textImage.isTemplate = true
            textImage.lockFocus()
            NSGraphicsContext.current!.cgContext.setAllowsFontSmoothing(false)
            attributedTitle.draw(with: NSRect(x: max(0, (textImage.size.width - textWidth) / 2), y: heightInset, width: textWidth, height: capHeight))
            textImage.unlockFocus()
            image = textImage
        }
        get {""}
    }
}

class SmileyButton: ToolbarButton {
    enum Emotion {
        case sad
        case happy
    }
    
    enum HappyType {
        case really
        case barely
        case hardly
    }
    
    enum SadType {
        case deadly
        case jokingly
    }
    
    static let sadMac = NSImage(named: "SadMac")!
    static let annoyedMac = NSImage(named: "AnnoyedMac")!
    static let happyMacEyes = NSImage(named: "HappyMacEyes")!
    static let happyMacCheek = NSImage(named: "HappyMacCheek")!
    static let stonyMacCheek = NSImage(named: "StonyMacCheek")!
    static let sadMacCheek = NSImage(named: "SadMacCheek")!
    
    static func sadMac(_ sadness: SadType) -> NSImage {
        switch sadness {
        case .deadly: return sadMac
        case .jokingly: return annoyedMac
        }
    }
    
    static func happyMac(_ happyness: HappyType, eyesOffset: NSPoint = .zero) -> NSImage {
        let image = NSImage(size: happyMacCheek.size)
        image.isTemplate = true
        image.lockFocusFlipped(true)
        
        let cheek: NSImage
        switch happyness {
        case .really: cheek = happyMacCheek
        case .barely: cheek = stonyMacCheek
        case .hardly: cheek = sadMacCheek
        }
        cheek.draw(in: NSRect(origin: .zero, size: image.size))
        
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
        let linearRawOffset = hypot(rawOffset.x, rawOffset.y)
        if linearRawOffset == 0 {return .zero}
        let linearOffset = attenuate(value: linearRawOffset, byLimit: 1.5, smoothing: 10)
        return NSPoint(x: rawOffset.x * linearOffset / linearRawOffset,
                       y: rawOffset.y * linearOffset / linearRawOffset)
    }
    
    var emotion: Emotion = .happy {didSet {updateImage()}}
    var happyType: HappyType = .really
    var sadType: SadType = .deadly
    
    private var transitionProgress: CGFloat = 1
    private var transitionOrigin: NSPoint = .zero
    private var transitionDestination: NSPoint = .zero
    private var transitionPresent: NSPoint = .zero {
        didSet {updateImage()}
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
    
    func updateImage() {
        let currentAppearance = NSAppearance.current
        NSAppearance.current = effectiveAppearance
        image = emotion == .happy
            ? Self.happyMac(happyType, eyesOffset: Self.eyesOffset(from: transitionPresent))
            : Self.sadMac(sadType)
        NSAppearance.current = currentAppearance
    }
    
    override func mouseEntered(with event: NSEvent) {
        transitionOrigin = transitionPresent
        if transitionProgress == 1 {
            startTransition()
        }
        transitionProgress = 0
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            happyType = .really
        } else if let closeButton = window?.standardWindowButton(.closeButton),
                  closeButton.bounds.contains(closeButton.convert(event.locationInWindow, from: nil)) {
            happyType = .hardly
        } else if let zoomButton = window?.standardWindowButton(.zoomButton),
                  zoomButton.bounds.contains(zoomButton.convert(event.locationInWindow, from: nil)) {
            happyType = .really
        } else {
            happyType = .barely
        }
        transitionDestination = NSPoint(x: location.x - bounds.midX, y: location.y - bounds.midY)
        if transitionProgress == 1 {
            transitionPresent = transitionDestination
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        happyType = .really
        transitionOrigin = transitionPresent
        transitionDestination = .zero
        if transitionProgress == 1 {
            startTransition()
        }
        transitionProgress = 0
    }
    
    override func viewDidChangeEffectiveAppearance() {
        updateImage()
    }
    
    override func updateTrackingAreas() {
        trackingAreas.forEach {removeTrackingArea($0)}
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
                                       owner: self,
                                       userInfo: nil))
        if let closeButton = window?.standardWindowButton(.closeButton),
           let zoomButton = window?.standardWindowButton(.zoomButton) {
            let closeButtonRect = convert(closeButton.bounds, from: closeButton)
            let zoomButtonRect = convert(zoomButton.bounds, from: zoomButton)
            addTrackingArea(NSTrackingArea(rect: closeButtonRect.union(zoomButtonRect),
                                           options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
                                           owner: self,
                                           userInfo: nil))
        }
    }
}
