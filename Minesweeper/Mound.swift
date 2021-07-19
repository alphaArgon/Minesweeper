import AppKit

protocol MoundDelegate: class {
    func moundCanAct(_: Mound) -> Bool
    func moundDidDig(_: Mound)
    func moundNeedDigVicinities(_: Mound)
    func mound(_: Mound, shouldFlagAs mark: Mound.Flag) -> Bool
}

class Mound: NSView {
    enum Flag: Int, Equatable {
        static let count = 3
        
        case none
        case certain
        case uncertain
    }
    
    enum State: Equatable {
        case covered(withFlag: Flag)
        case exposed
        
        var rawValue: Int {
            switch self {
            case .covered(let flag):
                return flag.rawValue
            case .exposed:
                return Flag.count
            }
        }
        
        init(rawValue: Int) {
            if rawValue < Flag.count {
                self = .covered(withFlag: Flag(rawValue: rawValue)!)
            } else {
                self = .exposed
            }
        }
    }
    
    static let mineImage: NSImage = NSImage(named: "Mine")!
    static let exposedBezel: NSImage = NSImage(named: "MoundExposed")!
    static let coveredBezel: NSImage = NSImage(named: "MoundCovered")!
    static let pressedBezel: NSImage = NSImage(named: "MoundPressed")!
    static let certainFlagGlyph: NSImage = NSImage(named: "FlagCertain")!
    static let uncertainFlagGlyph: NSImage = NSImage(named: "FlagUncertain")!
    
    static func getHintColors(ofAccent accentColor: NSColor) -> [NSColor] {
        let brightness = accentColor.brightnessComponent
        if abs(accentColor.redComponent - brightness) < 0.05,
           abs(accentColor.blueComponent - brightness) < 0.05,
           abs(accentColor.greenComponent - brightness) < 0.05 {
            return [.systemGray, .systemBlue, .systemPurple, .systemGreen, .systemOrange, .systemYellow, .systemRed, .labelColor]
        }
        
        let hue = accentColor.hueComponent
        if hue < 0.05 || hue > 0.95 { // red
            return [accentColor, .systemOrange, .systemBrown, .systemPurple, .systemYellow, .systemGreen, .systemBlue, .labelColor]
        } else if hue < 0.1 { // orange
            return [accentColor, .systemYellow, .systemRed, .systemBrown, .systemPurple, .systemGreen, .systemBlue, .labelColor]
        } else if hue < 0.2{ // yellow
            return [accentColor, .systemOrange, .systemBrown, .systemRed, .systemGreen, .systemBlue, .systemPurple, .labelColor]
        } else if hue < 0.5 { // green
            return [accentColor, .systemYellow, .systemBlue, .systemOrange, .systemPurple, .systemBrown, .systemRed, .labelColor]
        } else if hue < 0.7 { // blue
            return [accentColor, .systemGreen, .systemPurple, .systemYellow, .systemOrange, .systemBrown, .systemRed, .labelColor]
        } else if hue < 0.85 { // purple
            return [accentColor, .systemBlue, .systemRed, .systemOrange, .systemYellow, .systemTeal, .systemOrange, .labelColor]
        } else { // pink
            return [accentColor, .systemPurple, .systemBlue, .systemBrown, .systemRed, .systemOrange, .systemYellow, .labelColor]
        }
    }
    
    private static var areCachesInvalid: Bool = true
    @objc static func invalidCaches() {areCachesInvalid = true} // will be called by a minefield
    
    static func buildCaches() {
        areCachesInvalid = false
        
        _exposedCGBezel = exposedBezel.cgImage
        _coveredCGBezel = coveredBezel.cgImage
        _pressedCGBezel = pressedBezel.cgImage
        
        var staticalized: NSColor
        if #available(OSX 10.14, *) {
            staticalized = NSColor.controlAccentColor
        } else {
            staticalized = NSColor.keyboardFocusIndicatorColor.withAlphaComponent(1)
        }
        staticalized = NSColor(cgColor: staticalized.cgColor)!
        
        let hintColors = getHintColors(ofAccent: staticalized)
        _coveredBackgroundColor = hintColors[0]
        _exposedBackgroundColor = _coveredBackgroundColor.blended(withFraction: 0.75, of: .windowBackgroundColor)!
        
        _hintImages = []
        
        for hint in 1...8 {
            let image = NSImage(named: "Hint\(hint)")!.copy() as! NSImage
            image.lockFocus()
            hintColors[hint - 1].blended(withFraction: 0.25, of: .textColor)?.set()
            NSRect(origin: .zero, size: image.size).fill(using: .sourceIn)
            image.unlockFocus()
            _hintImages.append(image)
        }
    }
    
    private static var _exposedCGBezel: CGImage?
    private static var _coveredCGBezel: CGImage?
    private static var _pressedCGBezel: CGImage?
    private static var _coveredBackgroundColor: NSColor = .clear
    private static var _exposedBackgroundColor: NSColor = .clear
    private static var _hintImages: [NSImage] = []
    
    static var exposedCGBezel: CGImage? {
        if areCachesInvalid {buildCaches()}
        return _exposedCGBezel
    }
    static var coveredCGBezel: CGImage? {
        if areCachesInvalid {buildCaches()}
        return _coveredCGBezel
    }
    static var pressedCGBezel: CGImage? {
        if areCachesInvalid {buildCaches()}
        return _pressedCGBezel
    }
    
    static var coveredBackgroundColor: NSColor {
        if areCachesInvalid {buildCaches()}
        return _coveredBackgroundColor
    }
    static var exposedBackgroundColor: NSColor {
        if areCachesInvalid {buildCaches()}
        return _exposedBackgroundColor
    }
    static var hintImages: [NSImage] {
        if areCachesInvalid {buildCaches()}
        return _hintImages
    }
    
    
    weak var delegate: MoundDelegate?
    
    var state: State = .covered(withFlag: .none) {
        didSet {setNeedsDisplay(bounds)}
    }
    
    var isPressing: Bool = false
    var luminosity: CGFloat = 0
    var timeOfLastMouseDown: TimeInterval?
    
    var hint: Int = 0
    var hasMine: Bool {
        set {hint = newValue ? -1 : 0}
        get {hint <= -1}
    }
    
    var showsMine: Bool {
        set {
            hint = newValue ? -2 : -1
            setNeedsDisplay(bounds)
        }
        get {hint == -2}
    }
    
    var mineOpacity: CGFloat = 1
    var flashes: Bool = false
    
    var bezelInsets: NSEdgeInsets = NSEdgeInsets()
    
    let illuminationLayer: CALayer = {
        let layer = CALayer()
        layer.compositingFilter = "softLightBlendMode"
        return layer
    }()

    let bezelLayer: CALayer = {
        let layer = CALayer()
        layer.contentsGravity = .resize
        layer.contentsCenter = CGRect(x: 0, y: 0, width: 1, height: 1).insetBy(dx: 0.1, dy: 0.1)
        return layer
    }()

    let glyphLayer: CALayer = {
        let layer = CALayer()
        layer.contentsGravity = .center
        return layer
    }()

    let mineLayer: CALayer = {
        let layer = CALayer()
        layer.contentsGravity = .center
        return layer
    }()

    let flashLayer: CALayer = {
        let layer = CALayer()
        layer.compositingFilter = "softLightBlendMode"
        return layer
    }()
    
    override var isOpaque: Bool {true}
    
    override var wantsUpdateLayer: Bool {wantsLayer}
    
    override func layout() {
        super.layout()
        
        guard let layer = layer else {return}
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        layer.sublayers = [illuminationLayer, bezelLayer, glyphLayer, flashLayer, mineLayer]
        
        for sublayer in layer.sublayers! {
            sublayer.frame = layer.bounds
            sublayer.contentsScale = layer.contentsScale
        }
        
        bezelLayer.frame = layer.bounds.insetBy(bezelInsets)
        
        CATransaction.commit()
    }

    override func updateLayer() {
        super.updateLayer()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if state == .exposed {
            layer!.backgroundColor = Self.exposedBackgroundColor.cgColor
            illuminationLayer.isHidden = true
            bezelLayer.contents = Self.exposedCGBezel
            if #available(OSX 10.16, *) {
                bezelLayer.compositingFilter = "softLightBlendMode"
            } else {
                bezelLayer.compositingFilter = "overlayBlendMode"
            }
        } else {
            layer!.backgroundColor = Self.coveredBackgroundColor.cgColor
            illuminationLayer.isHidden = false
            illuminationLayer.backgroundColor = CGColor(gray: 0.43 + 0.2 * luminosity, alpha: 1)
            bezelLayer.contents = isPressing ? Self.pressedCGBezel : Self.coveredCGBezel
            if #available(OSX 10.16, *) {
                bezelLayer.compositingFilter = "overlayBlendMode"
            } else {
                bezelLayer.compositingFilter = "hardLightBlendMode"
            }
        }

        var glyph: NSImage?
        switch state {
        case .exposed:
            guard hint > 0 else {break}
            glyph =  Self.hintImages[hint - 1]

        case .covered(withFlag: .certain):
            glyph = Self.certainFlagGlyph

        case .covered(withFlag: .uncertain):
            glyph = Self.uncertainFlagGlyph
        default:
            break
        }

        glyphLayer.contents = glyph

        if hint == -2 {
            if flashes {
                flashLayer.isHidden = false
                flashLayer.backgroundColor = CGColor(gray: 1, alpha: (1 - cos(2 * .pi * mineOpacity)) / 2)
            } else {
                flashLayer.isHidden = true
            }
            mineLayer.isHidden = false
            mineLayer.contents = Self.mineImage
            mineLayer.compositingFilter = state == .exposed ? nil : "softLightBlendMode"
            mineLayer.opacity = Float((1 - cos(.pi * mineOpacity)) / 2)
        } else {
            mineLayer.isHidden = true
        }

        CATransaction.commit()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        if state == .exposed {
            Self.exposedBackgroundColor.set()
            bounds.fill()
            if #available(OSX 10.16, *) {
                Self.exposedBezel.draw(in: bounds.insetBy(bezelInsets), from: .zero, operation: .softLight, fraction: 1)
            } else {
                Self.exposedBezel.draw(in: bounds.insetBy(bezelInsets), from: .zero, operation: .overlay, fraction: 1)
            }
        } else {
            Self.coveredBackgroundColor.set()
            bounds.fill()
            NSColor(white: 0.5 + 0.2 * luminosity, alpha: 1).set()
            bounds.fill(using: .softLight)
            let bezel = isPressing ? Self.pressedBezel : Self.coveredBezel
            if #available(OSX 10.16, *) {
                bezel.draw(in: bounds.insetBy(bezelInsets), from: .zero, operation: .overlay, fraction: 1)
            } else {
                bezel.draw(in: bounds.insetBy(bezelInsets), from: .zero, operation: .hardLight, fraction: 1)
            }
        }

        var glyph: NSImage?
        switch state {
        case .exposed:
            guard hint > 0 else {break}
            glyph = Self.hintImages[hint - 1]

        case .covered(withFlag: .certain):
            glyph = Self.certainFlagGlyph

        case .covered(withFlag: .uncertain):
            glyph = Self.uncertainFlagGlyph
        default:
            break
        }

        glyph?.draw(in: NSRect(origin: NSPoint(
            x: bounds.midX - glyph!.size.width / 2,
            y: bounds.midY - glyph!.size.height / 2
        ), size: glyph!.size))

        if hint == -2 {
            let drawRect = NSRect(origin: NSPoint(
                x: bounds.midX - Self.mineImage.size.width / 2,
                y: bounds.midY - Self.mineImage.size.height / 2
            ), size: Self.mineImage.size)

            if mineOpacity == 1 {
                Self.mineImage.draw(in: drawRect, from: .zero, operation: state == .exposed ? .sourceOver : .softLight, fraction: 1)
            } else {
                if flashes {
                    NSColor(white: (1 - cos(2 * .pi * mineOpacity)) / 2, alpha: 1).setFill()
                    bounds.fill(using: .softLight)
                }
                Self.mineImage.draw(in: drawRect, from: .zero, operation: .overlay, fraction: (1 - cos(.pi * mineOpacity)) / 2)
            }
        }
    }
    
    override var frame: NSRect {
        didSet {
            isPressing = false
            setNeedsDisplay(bounds)
        }
    }
    
    func showMine(animates: Bool, flashes: Bool = false, duration: TimeInterval = 0.75) {
        if animates {
            self.flashes = flashes
            mineOpacity = 0
            animateMineOpacity(duration: duration, startTime: Date().timeIntervalSince1970)
        } else if mineOpacity != 1 {
            mineOpacity = 1
        }
        showsMine = true
    }
    
    func animateMineOpacity(duration: TimeInterval, startTime: TimeInterval) {
        if mineOpacity < 1 {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.015) {
                self.mineOpacity = CGFloat(((Date().timeIntervalSince1970 - startTime)) / duration)
                self.setNeedsDisplay(self.bounds)
                self.animateMineOpacity(duration: duration, startTime: startTime)
            }
        } else {
            mineOpacity = 1
            flashes = false
        }
    }
}

extension Mound {
    func dig() {
        if state != .exposed {
            state = .exposed
            delegate?.moundDidDig(self)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        guard delegate?.moundCanAct(self) ?? true == true else {return super.mouseDown(with: event)}

        if event.modifierFlags.contains(.control) {
            return rightMouseDown(with: event)
        }
        
        switch state {
        case .covered(withFlag: .none), .covered(withFlag: .uncertain):
            isPressing = true
            setNeedsDisplay(bounds)
        case .exposed:
            if timeOfLastMouseDown == nil || event.timestamp - timeOfLastMouseDown! > NSEvent.doubleClickInterval {
                timeOfLastMouseDown = event.timestamp
            } else {
                delegate?.moundNeedDigVicinities(self)
                timeOfLastMouseDown = nil
            }
        default:
            break
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        if state == .covered(withFlag: .none) || state == .covered(withFlag: .uncertain), delegate?.moundCanAct(self) ?? true {
            let isMouseInBounds = self.bounds.contains(convert(event.locationInWindow, from: nil))
            if isPressing != isMouseInBounds {
                isPressing = isMouseInBounds
                setNeedsDisplay(bounds)
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if isPressing {
            isPressing = false
            dig()
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        guard delegate?.moundCanAct(self) ?? true == true, case .covered(withFlag: let flag) = state else {return}
        
        let nextFlag = Flag(rawValue: flag.rawValue + 1) ?? Flag(rawValue: 0)!
        if delegate?.mound(self, shouldFlagAs: nextFlag) ?? true {
            state = .covered(withFlag: nextFlag)
        }
    }
}
