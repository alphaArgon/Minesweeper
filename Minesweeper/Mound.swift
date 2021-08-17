import AppKit

protocol MoundDelegate: class {
    func moundCanAct(_: Mound) -> Bool
    func moundDidDig(_: Mound)
    func moundNeedDigVicinities(_: Mound)
    func moundMineStyle(_: Mound) -> Mound.MineStyle
    func mound(_: Mound, shouldFlagAs mark: Mound.Flag) -> Bool
}

class Mound: NSView {
    enum MineStyle: Int {
        case bomb
        case flower
        
        var description: String {
            switch self {
            case .bomb:     return "mine-style-bomb".localized
            case .flower:   return "mine-style-flower".localized
            }
        }
    }
    
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
    static let flowerImage: NSImage = NSImage(named: "Flower")!
    static let coveredBezel: NSImage = NSImage(named: "MoundCovered")!
    static let pressedBezel: NSImage = NSImage(named: "MoundPressed")!
    static let exposedBezel: NSImage = NSImage(named: "MoundExposed")!
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
                    .systemOrange, .systemYellow, .accentRed, .accentGold, .accentPurple, .accentGreen, .accentBlue, .textColor]
        } else if hue < 0.2 {
            return [.accentYellow,
                    .systemYellow, .systemOrange, .accentGold, .accentRed, .accentGreen, .accentBlue, .accentPurple, .textColor]
        } else if hue < 0.5 {
            return [greenComponent < 0.5 ? .accentConifer : .accentGreen,
                    .accentGreen, .systemYellow, .accentBlue, .systemOrange, .accentCyan, .accentGold, .accentRed, .textColor]
        } else if hue < 0.6 {
            return [blueComponent < 0.5 ? .accentOcean : .accentBlue,
                    .accentBlue, .accentGreen, .accentPurple, .systemYellow, .systemOrange, .accentGold, .accentRed, .textColor]
        } else if hue < 0.7 {
            return [blueComponent < 0.5 ? .accentIndigo : .accentVoilet,
                    .accentVoilet, .accentPurple, .accentGreen, .accentRed, .systemYellow, .systemOrange, .accentGold, .textColor]
        } else if hue < 0.85 {
            return [.accentPurple,
                    .accentPurple, .accentBlue, .accentRed, .systemOrange, .systemYellow, .accentCyan, .accentOrange, .textColor]
        } else {
            return [.accentPink,
                    .accentPink, .accentPurple, .accentVoilet, .accentGold, .accentRed, .accentOrange, .accentYellow, .textColor]
        }
    }
    
    private static var areCachesInvalid: Bool = true
    @objc static func invalidCaches() {areCachesInvalid = true} // will be called by a minefield
    
    static func buildCaches() {
        areCachesInvalid = false
        
        let accentTester: NSColor
        if #available(OSX 10.14, *) {
            accentTester = NSColor.controlAccentColor
        } else {
            accentTester = NSColor.selectedTextBackgroundColor
        }
        
        let hintColors = getHintColors(ofAccent: NSColor(cgColor: accentTester.cgColor)!)
        _hintImages = []
        
        for hint in 1...8 {
            let image = NSImage(named: "Hint\(hint)")!.copy() as! NSImage
            image.lockFocus()
            let rect = NSRect(origin: .zero, size: image.size)
            hintColors[hint].blended(withFraction: 0.3, of: .labelColor)?.set()
            rect.fill(using: .sourceIn)
            image.unlockFocus()
            _hintImages.append(image)
        }
        
        let backgroundColor: NSColor
        
        if #available(OSX 10.14, *),
           NSAppearance.current.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            backgroundColor = hintColors[0].blended(withFraction: 0.31, of: NSColor.darkGray)!
        } else {
            backgroundColor = hintColors[0].blended(withFraction: 0.12, of: NSColor.lightGray)!
        }
        
        var blends: [CGImage?] = []
        let bezels: [(NSImage, NSColor, NSCompositingOperation)]
        if #available(OSX 10.16, *) {
            bezels = [(coveredBezel, backgroundColor, .overlay),
                      (pressedBezel, backgroundColor, .overlay),
                      (exposedBezel, hintColors[0].blended(withFraction: 0.68, of: .gray)!, .luminosity)];
        } else {
            bezels = [(coveredBezel, backgroundColor, .hardLight),
                      (pressedBezel, backgroundColor, .hardLight),
                      (exposedBezel, hintColors[0].blended(withFraction: 0.75, of: .gray)!, .luminosity)];
        }
        
        for (image, color, blendMode) in bezels {
            let blend = NSImage(size: image.size)
            blend.lockFocus()
            color.setFill()
            NSRect(origin: .zero, size: image.size).fill()
            image.draw(at: .zero, from: .zero, operation: blendMode, fraction: 1)
            blend.unlockFocus()
            blends.append(blend.cgImage)
        }
        
        _coveredCGBezel = blends[0]
        _pressedCGBezel = blends[1]
        _exposedCGBezel = blends[2]
    }
    
    private static var _exposedCGBezel: CGImage?
    private static var _coveredCGBezel: CGImage?
    private static var _pressedCGBezel: CGImage?
    private static var _hintImages: [NSImage] = []
    
    static var coveredCGBezel: CGImage? {
        if areCachesInvalid {buildCaches()}
        return _coveredCGBezel
    }
    static var pressedCGBezel: CGImage? {
        if areCachesInvalid {buildCaches()}
        return _pressedCGBezel
    }
    static var exposedCGBezel: CGImage? {
        if areCachesInvalid {buildCaches()}
        return _exposedCGBezel
    }
    
    static var hintImages: [NSImage] {
        if areCachesInvalid {buildCaches()}
        return _hintImages
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
    
    var bezelInsets: NSEdgeInsets = NSEdgeInsets() {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            bezelLayer.frame = layer!.bounds.insetBy(bezelInsets)
            CATransaction.commit()
        }
    }

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
        
        var sublayers = [glyphLayer, flashLayer, mineLayer]
        
        for sublayer in sublayers {
            sublayer.frame = layer.bounds
            sublayer.contentsScale = layer.contentsScale
        }
        
        bezelLayer.frame = layer.bounds.insetBy(bezelInsets)
        bezelLayer.contentsScale = layer.contentsScale
        
        sublayers.insert(bezelLayer, at: 0)
        
        layer.sublayers = sublayers
        
        CATransaction.commit()
    }

    override func updateLayer() {
        super.updateLayer()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if state == .exposed {
            bezelLayer.contents = Self.exposedCGBezel
            bezelLayer.compositingFilter = nil
        } else {
            layer?.backgroundColor = CGColor(gray: 0.43 + 0.1 * luminosity, alpha: 1)
            bezelLayer.contents = isPressed ? Self.pressedCGBezel : Self.coveredCGBezel
            bezelLayer.compositingFilter = "hardLightBlendMode"
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
            switch delegate?.moundMineStyle(self) ?? .bomb {
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
        if showsMine {return}
        
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
