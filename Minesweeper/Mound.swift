import AppKit

protocol MoundDelegate: class {
    func moundCanAct(_: Mound) -> Bool
    func moundDidDig(_: Mound)
    func moundNeedDigVicinities(_: Mound)
    func mound(_: Mound, shouldFlagAs mark: Mound.Flag) -> Bool
    var mineStyle: Minefield.MineStyle {get}
    var fieldStyle: Minefield.FieldStyle {get}
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
    
    struct EdgingMask: OptionSet {
        let rawValue: Int
        
        static let top = EdgingMask(rawValue: 1)
        static let left = EdgingMask(rawValue: 2)
        static let bottom = EdgingMask(rawValue: 4)
        static let right = EdgingMask(rawValue: 8)
    }
    
    static let mineImage: NSImage = NSImage(named: "Mine")!
    static let flowerImage: NSImage = NSImage(named: "Flower")!
    static let certainFlagGlyph: NSImage = NSImage(named: "FlagCertain")!
    static let uncertainFlagGlyph: NSImage = NSImage(named: "FlagUncertain")!
    
    static func getHintColors(ofAccent accentColor: NSColor) -> [NSColor] {
        let brightness = accentColor.brightnessComponent
        let redComponent = accentColor.redComponent
        let blueComponent = accentColor.blueComponent
        let greenComponent = accentColor.greenComponent
        if abs(redComponent - brightness) < 0.05,
           abs(blueComponent - brightness) < 0.05,
           abs(greenComponent - brightness) < 0.05 {
            return [.accentGraphite, .accentGraphite, .accentBlue, .accentPurple, .accentGreen, .accentOrange, .accentYellow, .accentRed, .textColor]
        }
        
        let hue = accentColor.hueComponent
        if hue < 0.04 || hue > 0.95 {
            return [redComponent < 0.81 ? .accentBlood : .accentRed,
                    .accentRed, .systemOrange, .accentGold, .accentPurple, .systemYellow, .accentGreen, .accentBlue, .textColor]
        } else if hue < 0.1 {
            return [hue < 0.055 ? .accentCopper : .accentOrange,
                    .accentOrange, .systemYellow, .accentRed, .accentGold, .accentPurple, .accentGreen, .accentBlue, .textColor]
        } else if hue < 0.2 {
            return [.accentYellow,
                    .systemYellow, .accentOrange, .accentGold, .accentRed, .accentGreen, .accentBlue, .accentPurple, .textColor]
        } else if hue < 0.5 {
            return [greenComponent < 0.5 ? .accentConifer : .accentGreen,
                    .accentGreen, .systemYellow, .accentBlue, .accentOrange, .accentCyan, .accentGold, .accentRed, .textColor]
        } else if hue < 0.62 {
            return [blueComponent < 0.5 ? .accentOcean : .accentBlue,
                    .accentBlue, .accentGreen, .accentPurple, .systemYellow, .accentOrange, .accentGold, .accentRed, .textColor]
        } else if hue < 0.7 {
            return [blueComponent < 0.5 ? .accentIndigo : .accentVoilet,
                    .accentVoilet, .accentPurple, .accentGreen, .accentRed, .systemYellow, .accentOrange, .accentGold, .textColor]
        } else if hue < 0.85 {
            return [.accentPurple,
                    .accentPurple, .accentBlue, .accentRed, .accentOrange, .systemYellow, .accentCyan, .accentOrange, .textColor]
        } else {
            return [.accentPink,
                    .accentPink, .accentPurple, .accentVoilet, .accentGold, .accentRed, .accentOrange, .accentYellow, .textColor]
        }
    }
    
    private static var areCachesInvalid: Bool = true
    static func invalidCaches() {areCachesInvalid = true} // will be called by a minefield
    
    static func buildCaches(fieldStyle: Minefield.FieldStyle) {
        areCachesInvalid = false
        
        let accentTester: NSColor
        if #available(OSX 10.14, *) {
            accentTester = NSColor.controlAccentColor
        } else {
            accentTester = NSColor.alternateSelectedControlColor
        }
        
        let hintColors = getHintColors(ofAccent: NSColor(cgColor: accentTester.cgColor)!)
        _hintImages[fieldStyle] = []
        
        for hint in 1...8 {
            let image = NSImage(named: "Hint\(hint)")!.copy() as! NSImage
            image.lockFocus()
            let rect = NSRect(origin: .zero, size: image.size)
            hintColors[hint].blended(withFraction: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 0.5 : 0.3,
                                     of: .labelColor)?.setFill()
            rect.fill(using: .sourceIn)
            image.unlockFocus()
            _hintImages[fieldStyle]!.append(image)
        }
        
        let bezels: [(NSImage, NSColor, NSCompositingOperation)]
        _cgBezels[fieldStyle] = []
        
        if fieldStyle == .sheet {
            if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
                let mask = NSImage(size: NSSize(width: 20, height: 20))
                mask.lockFocus()
                let backgroundColor = NSColor(red: hintColors[0].redComponent - 0.2,
                                              green: hintColors[0].greenComponent - 0.2,
                                              blue: hintColors[0].blueComponent - 0.2,
                                              alpha: 1)
                backgroundColor.setFill()
                NSBezierPath(roundedRect: NSRect(origin: .zero, size: mask.size).insetBy(dx: 1, dy: 1),
                             xRadius: 1.5, yRadius: 1.5).fill()
                mask.unlockFocus()
                
                bezels = [(mask, .white, .sourceIn),
                          (mask, backgroundColor.blended(withFraction: 0.25, of: .black)!.withAlphaComponent(0.75), .destinationIn),
                          (mask, backgroundColor.withAlphaComponent(0.25), .destinationIn)]
                
            } else {
                let mask = NSImage(size: NSSize(width: 20, height: 20))
                mask.lockFocus()
                
                NSGradient(colors: [hintColors[0].blended(withFraction: 0.04, of: .white)!,
                                    hintColors[0].blended(withFraction: 0.03, of: .black)!])?
                    .draw(in: NSBezierPath(roundedRect: NSRect(origin: .zero, size: mask.size).insetBy(dx: 1, dy: 1),
                                           xRadius: 1.5, yRadius: 1.5),
                          angle: -90)
                
                mask.unlockFocus()
                
                bezels = [(mask, NSColor(white: 1, alpha: 0.8), .sourceIn),
                          (mask, hintColors[0].blended(withFraction: 0.25, of: .darkGray)!.withAlphaComponent(0.75), .destinationIn),
                          (mask, hintColors[0].withAlphaComponent(0.25), .destinationIn)]
            }
        } else {
            var backgroundColor: NSColor
            
            if #available(OSX 10.14, *),
               NSAppearance.current.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                backgroundColor = hintColors[0].blended(withFraction: 0.31, of: NSColor.darkGray)!
            } else {
                backgroundColor = hintColors[0].blended(withFraction: 0.12, of: NSColor.lightGray)!
            }
            
            if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
                backgroundColor = NSColor(hue: backgroundColor.hueComponent,
                                          saturation: backgroundColor.saturationComponent + 0.2,
                                          brightness: backgroundColor.brightnessComponent - 0.2,
                                          alpha: 1)
            }
            
            bezels = [(NSImage(named: "MoundCovered")!, backgroundColor, .hardLight),
                      (NSImage(named: "MoundPressed")!, backgroundColor, .hardLight),
                      (NSImage(named: "MoundExposed")!, hintColors[0].blended(withFraction: 0.75, of: .gray)!, .luminosity)];
        }
        
        for i in 0..<3 {
            let (image, color, blendMode) = bezels[i]
            let blend = NSImage(size: image.size)
            blend.lockFocus()
            color.setFill()
            NSRect(origin: .zero, size: image.size).fill()
            image.draw(at: .zero, from: .zero, operation: blendMode, fraction: 1)
            blend.unlockFocus()
            _cgBezels[fieldStyle]!.append(blend.cgImage)
        }
    }
    
    private static var _cgBezels: [Minefield.FieldStyle: [CGImage?]] = [:]
    private static var _hintImages: [Minefield.FieldStyle: [NSImage]] = [:]
    
    static func coveredCGBezel(fieldStyle: Minefield.FieldStyle) -> CGImage? {
        if areCachesInvalid {buildCaches(fieldStyle: fieldStyle)}
        return _cgBezels[fieldStyle]![0]
    }
    static func pressedCGBezel(fieldStyle: Minefield.FieldStyle) -> CGImage? {
        if areCachesInvalid {buildCaches(fieldStyle: fieldStyle)}
        return _cgBezels[fieldStyle]![1]
    }
    static func exposedCGBezel(fieldStyle: Minefield.FieldStyle) -> CGImage? {
        if areCachesInvalid {buildCaches(fieldStyle: fieldStyle)}
        return _cgBezels[fieldStyle]![2]
    }
    
    static func hintImages(fieldStyle: Minefield.FieldStyle) -> [NSImage] {
        if areCachesInvalid {buildCaches(fieldStyle: fieldStyle)}
        return _hintImages[fieldStyle]!
    }
    
    weak var delegate: MoundDelegate?
    
    var state: State = .covered(withFlag: .none) {
        didSet {setNeedsDisplay(bounds)}
    }
    
    var isPressed: Bool = false
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
    
    var edgingMask: EdgingMask = []
    
    override var allowsVibrancy: Bool {state == .exposed}
    
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
    
    override var isOpaque: Bool {true}
    
    override var wantsUpdateLayer: Bool {true}
    
    override func layout() {
        super.layout()
        
        guard let layer = layer else {return}
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        layer.sublayers = [bezelLayer, glyphLayer, mineLayer]
        
        for sublayer in layer.sublayers! {
            sublayer.frame = layer.bounds
            sublayer.contentsScale = layer.contentsScale
        }
        
        CATransaction.commit()
    }
    
    override func updateLayer() {
        super.updateLayer()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let fieldStyle = delegate?.fieldStyle ?? .solid
        
        if fieldStyle == .solid {
            bezelLayer.frame = layer!.bounds.insetBy(NSEdgeInsets(
                top: state == .exposed && edgingMask.contains(.top) ? -0.5 : 0,
                left: edgingMask.contains(.left) ? -1 : 0,
                bottom: edgingMask.contains(.bottom) ? -1 : 0,
                right: edgingMask.contains(.right) ? -1 : 0))
        }
        
        if state == .exposed {
            bezelLayer.contents = Self.exposedCGBezel(fieldStyle: fieldStyle)
            bezelLayer.compositingFilter = nil
            layer!.backgroundColor = nil
        } else {
            bezelLayer.contents = isPressed ? Self.pressedCGBezel(fieldStyle: fieldStyle) : Self.coveredCGBezel(fieldStyle: fieldStyle)
            if fieldStyle == .solid {
                bezelLayer.compositingFilter = "hardLightBlendMode"
                layer!.backgroundColor = CGColor(gray: 0.43 + 0.1 * luminosity, alpha: 1)
            }
        }
        
        var glyph: NSImage?
        switch state {
        case .exposed:
            guard hint > 0 else {break}
            glyph =  Self.hintImages(fieldStyle: fieldStyle)[hint - 1]

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
                mineLayer.backgroundColor = CGColor(gray: 1, alpha: (1 - cos(2 * .pi * mineOpacity)) / 2)
            }
            mineLayer.isHidden = false
            switch delegate?.mineStyle ?? .bomb {
            case .bomb: mineLayer.contents = Self.mineImage
            case .flower: mineLayer.contents = Self.flowerImage
            }
            mineLayer.compositingFilter = state == .exposed ? nil : "softLightBlendMode"
            mineLayer.opacity = Float((1 - cos(.pi * mineOpacity)) / 2)
        } else {
            mineLayer.isHidden = true
        }
        
        CATransaction.commit()
    }
    
    override var frame: NSRect {
        didSet {
            isPressed = false
            setNeedsDisplay(bounds)
        }
    }
    
    func showMine(animates: Bool, flashes: Bool = false, duration: TimeInterval = 0.75) {
        if showsMine {return mineOpacity = 1}
        
        showsMine = true
        if animates {
            self.flashes = flashes
            mineOpacity = 0
            animateMineOpacity(duration: duration, startTime: Date().timeIntervalSince1970)
        } else if mineOpacity != 1 {
            mineOpacity = 1
        }
    }
    
    func animateMineOpacity(duration: TimeInterval, startTime: TimeInterval) {
        if mineOpacity < 1 {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.015) {
                self.setNeedsDisplay(self.bounds)
                if self.mineOpacity < 1 {
                    self.mineOpacity = CGFloat(((Date().timeIntervalSince1970 - startTime)) / duration)
                    self.animateMineOpacity(duration: duration, startTime: startTime)
                }
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
            isPressed = true
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
            if isPressed != isMouseInBounds {
                isPressed = isMouseInBounds
                setNeedsDisplay(bounds)
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if isPressed {
            isPressed = false
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
