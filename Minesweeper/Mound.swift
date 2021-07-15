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
    
    static func getHintColors(ofAccent accentColor: NSColor) -> [NSColor] {
        let brightness = accentColor.brightnessComponent
        if abs(accentColor.redComponent - brightness) < 0.05,
           abs(accentColor.blueComponent - brightness) < 0.05,
           abs(accentColor.greenComponent - brightness) < 0.05 {
            return [coveredBackgroundColor, .systemBlue, .systemPurple, .systemGreen, .systemOrange, .systemYellow, .systemRed, .labelColor]
        }
        
        let hue = accentColor.hueComponent
        if hue < 0.05 || hue > 0.95 { // red
            return [coveredBackgroundColor, .systemOrange, .systemBrown, .systemPurple, .systemYellow, .systemGreen, .systemBlue, .labelColor]
        } else if hue < 0.1 { // orange
            return [coveredBackgroundColor, .systemYellow, .systemRed, .systemBrown, .systemPurple, .systemGreen, .systemBlue, .labelColor]
        } else if hue < 0.2{ // yellow
            return [coveredBackgroundColor, .systemOrange, .systemBrown, .systemRed, .systemGreen, .systemBlue, .systemPurple, .labelColor]
        } else if hue < 0.5 { // green
            return [coveredBackgroundColor, .systemYellow, .systemBlue, .systemOrange, .systemPurple, .systemBrown, .systemRed, .labelColor]
        } else if hue < 0.7 { // blue
            return [coveredBackgroundColor, .systemGreen, .systemPurple, .systemYellow, .systemOrange, .systemBrown, .systemRed, .labelColor]
        } else if hue < 0.85 { // purple
            return [coveredBackgroundColor, .systemBlue, .systemRed, .systemOrange, .systemYellow, .systemTeal, .systemOrange, .labelColor]
        } else { // pink
            return [coveredBackgroundColor, .systemPurple, .systemBlue, .systemBrown, .systemRed, .systemOrange, .systemYellow, .labelColor]
        }
    }
    
    static let mineImage: NSImage = NSImage(named: "Mine")!
    static let exposedBezel: NSImage = NSImage(named: "MoundExposed")!
    static let coveredBezel: NSImage = NSImage(named: "MoundCovered")!
    static let pressedBezel: NSImage = NSImage(named: "MoundPressed")!
    static let certainFlagGlyph: NSImage = NSImage(named: "FlagCertain")!
    static let uncertainFlagGlyph: NSImage = NSImage(named: "FlagUncertain")!
    
    static var coveredBackgroundColor: NSColor {
        if #available(OSX 10.14, *) {
            return NSColor.controlAccentColor
        } else {
            return NSColor.keyboardFocusIndicatorColor.withAlphaComponent(1)
        }
    }
    
    static var exposedBackgroundColor: NSColor {coveredBackgroundColor.withAlphaComponent(0.25)}
    
    private static var _accentColor: NSColor = .clear
    private static var _hintImages: [NSImage] = []
    
    static var hintImages: [NSImage] {
        let staticalized = NSColor(cgColor: NSColor.keyboardFocusIndicatorColor.cgColor)!
        if _accentColor != staticalized {
            _accentColor = staticalized
            _hintImages = []
            let hintColors = getHintColors(ofAccent: _accentColor)
            
            for hint in 1...8 {
                let image = NSImage(named: "Hint\(hint)")!.copy() as! NSImage
                image.lockFocus()
                hintColors[hint - 1].blended(withFraction: 0.25, of: .textColor)?.set()
                NSRect(origin: .zero, size: image.size).fill(using: .sourceIn)
                image.unlockFocus()
                _hintImages.append(image)
            }
        }
        
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

extension Mound {
    override func draw(_ dirtyRect: NSRect) {
        if state == .exposed {
            Self.exposedBackgroundColor.set()
            bounds.fill()
            Self.exposedBezel.draw(in: bounds, from: .zero, operation: .softLight, fraction: 1)
        } else {
            Self.coveredBackgroundColor.set()
            bounds.fill()
            NSColor(white: 0.5 + 0.2 * luminosity, alpha: 1).set()
            bounds.fill(using: .softLight)
            let bezel = isPressing ? Self.pressedBezel : Self.coveredBezel
            if #available(OSX 10.16, *) {
                bezel.draw(in: bounds, from: .zero, operation: .softLight, fraction: 1)
                bezel.draw(in: bounds, from: .zero, operation: .hardLight, fraction: 0.5)
            } else {
                bezel.draw(in: bounds)
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
                Self.mineImage.draw(in: drawRect, from: .zero, operation: .softLight, fraction: 1)
            } else {
                if flashes {
                    NSColor(white: 1, alpha: (1 - cos(2 * .pi * mineOpacity)) / 2).setFill()
                    bounds.fill(using: .softLight)
                }
                Self.mineImage.draw(in: drawRect, from: .zero, operation: .softLight, fraction: (1 - cos(.pi * mineOpacity)) / 2)
            }
        }
    }
    
///-  It works weird that it doesn't vary with system appearance changing
    
//    override var wantsUpdateLayer: Bool {wantsLayer}
//
//    override func updateLayer() {
//        let rootLayer = self.layer!
//
//        let highlightLayer = rootLayer.sublayers?.first {$0.name == "highlight"} ?? {
//            let layer = CALayer()
//            layer.name = "highlight"
//            layer.frame = rootLayer.bounds
//            layer.compositingFilter = "softLightBlendMode"
//            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
//            rootLayer.addSublayer(layer)
//            return layer
//        }()
//
//        let bezelLayer = rootLayer.sublayers?.first {$0.name == "bezel"} ?? {
//            let layer = CALayer()
//            layer.name = "bezel"
//            layer.contentsGravity = .resizeAspectFill
//            layer.frame = rootLayer.bounds
//            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
//            rootLayer.addSublayer(layer)
//            return layer
//        }()
//
//        let glyphLayer = rootLayer.sublayers?.first {$0.name == "glyph"} ?? {
//            let layer = CALayer()
//            layer.name = "glyph"
//            layer.contentsGravity = .center
//            layer.frame = rootLayer.bounds
//            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
//            rootLayer.addSublayer(layer)
//            return layer
//        }()
//
//        let mineLayer = rootLayer.sublayers?.first {$0.name == "mine"} ?? {
//            let layer = CALayer()
//            layer.name = "mine"
//            layer.contents = Self.mineImage
//            layer.contentsGravity = .center
//            layer.frame = rootLayer.bounds
//            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
//            rootLayer.addSublayer(layer)
//            return layer
//        }()
//
//        CATransaction.begin()
//        CATransaction.setDisableActions(true)
//
//        if state == .exposed {
//            rootLayer.backgroundColor = Self.exposedBackgroundColor.cgColor
//            highlightLayer.isHidden = true
//            bezelLayer.contents = Self.exposedBezel
//        } else {
//            rootLayer.backgroundColor = Self.coveredBackgroundColor.cgColor
//            highlightLayer.contentsScale = rootLayer.contentsScale
//            highlightLayer.isHidden = false
//            highlightLayer.backgroundColor = CGColor(gray: 0.5 + 0.2 * luminosity, alpha: 1)
//            bezelLayer.contents = isPressing ? Self.pressedBezel : Self.coveredBezel
//        }
//
//        bezelLayer.contentsScale = rootLayer.contentsScale
//        bezelLayer.contentsCenter = CGRect(x: 0, y: 0, width: 1, height: 1).insetBy(dx: 0.1, dy: 0.1)
//
//        var glyph: NSImage?
//        switch state {
//        case .exposed:
//            guard hint > 0 else {break}
//            glyph =  Self.hintImages[hint - 1]
//
//        case .covered(withFlag: .certain):
//            glyph = Self.certainFlagGlyph
//
//        case .covered(withFlag: .uncertain):
//            glyph = Self.uncertainFlagGlyph
//        default:
//            break
//        }
//
//        glyphLayer.contents = glyph
//        glyphLayer.contentsScale = rootLayer.contentsScale
//
//        if hint == -2 {
//            mineLayer.isHidden = false
//            mineLayer.compositingFilter = state == .exposed ? nil : "softLightBlendMode"
//            mineLayer.backgroundColor = CGColor(gray: 1, alpha: (1 - cos(2 * .pi * mineOpacity)) / 2)
//            mineLayer.contentsScale = rootLayer.contentsScale
//        } else {
//            mineLayer.isHidden = true
//        }
//
//        CATransaction.commit()
//    }
}

struct MoundMatrix {
    struct Index: Equatable, Hashable {
        var column: Int
        var row: Int
        
        init(_ column: Int, _ row: Int) {
            self.column = column
            self.row = row
        }
        
        var vicinities: Set<Index> {Set(arrayLiteral:
            Index(column - 1,   row - 1),
            Index(column,       row - 1),
            Index(column + 1,   row - 1),
            Index(column - 1,   row    ),
            Index(column,       row    ),
            Index(column + 1,   row    ),
            Index(column - 1,   row + 1),
            Index(column,       row + 1),
            Index(column + 1,   row + 1)
        )}
    }
    
    var numberOfColumns: Int
    var numberOfRows: Int
    private var delegate: MoundDelegate?
    private var array: [Mound] = []
    
    init() {
        self.numberOfColumns = 0
        self.numberOfRows = 0
    }
    
    init(numberOfColumns: Int, numberOfRows: Int, delegate: MoundDelegate) {
        self.numberOfColumns = numberOfColumns
        self.numberOfRows = numberOfRows
        self.delegate = delegate
        for _ in 0..<(numberOfColumns * numberOfRows) {
            let mound = Mound()
            mound.delegate = delegate
            array.append(mound)
        }
    }
    
    subscript(_ index: Index) -> Mound? {
        guard contains(index: index) else {return nil}
        return array[index.row * numberOfColumns + index.column]
    }
    
    func contains(index: Index) -> Bool {
        return index.column >= 0 && index.column < numberOfColumns && index.row >= 0 && index.row < numberOfRows
    }
    
    func forEach(body callback: (Mound) throws -> Void) rethrows {
        try array.forEach(callback)
    }
    
    func forEach(body callback: (Mound, Index) throws -> Void) rethrows {
        for index in 0..<array.count {
            try callback(array[index], Index(index % numberOfColumns, index / numberOfColumns))
        }
    }
    
    func forEach(body callback: (Mound, Index, _ internalIndex: Int) throws -> Void) rethrows {
        for index in 0..<array.count {
            try callback(array[index], Index(index % numberOfColumns, index / numberOfColumns), index)
        }
    }
    
    func indexOf(_ mound: Mound) -> Index? {
        guard let index = (array.firstIndex {$0 == mound}) else {return nil}
        return Index(index % numberOfColumns, index / numberOfColumns)
    }
    
    mutating func setSize(numberOfColumns: Int, numberOfRows: Int) {
        self.numberOfColumns = numberOfColumns
        self.numberOfRows = numberOfRows
        
        let newArrayCount = numberOfColumns * numberOfRows
        
        var index = array.count
        while index < newArrayCount {
            let mound = Mound()
            mound.delegate = delegate
            array.append(mound)
            index += 1
        }
        while index > newArrayCount {
            array.removeLast()
            index -= 1
        }
    }
}
