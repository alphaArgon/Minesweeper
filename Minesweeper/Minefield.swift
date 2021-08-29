import AppKit

protocol MinefieldDelegate: class {
    func minefieldWindowShouldClose(_ minefield: Minefield) -> Bool
    func minefieldWindowDidResize(_ minefield: Minefield)
}

class Minefield: NSView {
    enum MineStyle: Int {
        case bomb
        case flower
        
        var description: String {
            switch self {
            case .bomb: return "mine-style-bomb".localized
            case .flower: return "mine-style-flower".localized
            }
        }
    }
    
    enum FieldStyle: Int {
        case solid
        case sheet
    }
    
    struct Difficulty: Equatable {
        var numberOfColumns: Int
        var numberOfRows: Int
        var numberOfMines: Int
        
        static let beginner: Difficulty = Difficulty(numberOfColumns: 9, numberOfRows: 9, numberOfMines: 10)
        static let intermediate: Difficulty = Difficulty(numberOfColumns: 16, numberOfRows: 16, numberOfMines: 40)
        static let advanced: Difficulty = Difficulty(numberOfColumns: 30, numberOfRows: 16, numberOfMines: 99)
        
        var rawValues: [Int] {[numberOfColumns, numberOfRows, numberOfMines]}
        
        init(numberOfColumns: Int, numberOfRows: Int, numberOfMines: Int) {
            self.numberOfColumns = numberOfColumns
            self.numberOfRows = numberOfRows
            self.numberOfMines = numberOfMines
        }
        
        init(rawValues: [Int]) {
            self.numberOfColumns = rawValues[0]
            self.numberOfRows = rawValues[1]
            self.numberOfMines = rawValues[2]
        }
        
        init?(tag: Int) {
            switch tag {
            case 1: self = .beginner
            case 2: self = .intermediate
            case 3: self = .advanced
            default: return nil
            }
        }
    }
    
    weak var delegate: MinefieldDelegate?
    
    var difficulty: Difficulty
    var moundMatrix: MoundMatrix!
    var moundDelegate: MoundDelegate
    
    var numberOfColumns: Int {difficulty.numberOfColumns}
    var numberOfRows: Int {difficulty.numberOfRows}
    var numberOfMounds: Int {difficulty.numberOfColumns * difficulty.numberOfRows}
    var numberOfMines: Int {difficulty.numberOfMines}
    
    var mineStyle: MineStyle
    var fieldStyle: FieldStyle
    
    var standardMoundSize: CGFloat {fieldStyle == .sheet ? 26 : 24}
    var minMoundSize: CGFloat {fieldStyle == .sheet ? 24 : 22}
    var maxMoundSize: CGFloat {36}
    var moundSize: CGFloat
    
    var contentInsets: NSEdgeInsets {
        fieldStyle == .sheet
            ? NSEdgeInsets(top: -1, left: 1, bottom: 1, right: 1)
            : NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    var hasDeployed: Bool = false
    
    let animationSeparatingDuration: Double = 0.2
    let delayAfterFirstSubanimation: Double = 0.4
    
    var animationSignature: TimeInterval = 0
    
    var isAnimatingResizing: Bool = false
    
    var states: String {
        get {
            var states = ""
            moundMatrix.forEach {mound in
                states.append("\(mound.state.rawValue) ")
                states.append("\(mound.hint) ")
            }
            return states
        }
        set {
            let split = newValue.split(separator: " ").map {Int(String($0))!}
            moundMatrix.forEach {mound, _, rawIndex in
                mound.state = Mound.State(rawValue: split[rawIndex * 2])
                mound.hint = split[rawIndex * 2 + 1]
            }
        }
    }
    
    init(mineStyle: MineStyle?, fieldStyle: FieldStyle?, moundSize: CGFloat?, difficulty: Difficulty?, moundDelegate: MoundDelegate) {
        if fieldStyle != nil {
            self.fieldStyle = fieldStyle!
        } else if #available(OSX 10.16, *) {
            self.fieldStyle = .sheet
        } else {
            self.fieldStyle = .solid
        }
        
        self.mineStyle = mineStyle ?? .bomb
        self.moundSize = 0
        self.difficulty = difficulty ?? .beginner
        self.moundDelegate = moundDelegate
        super.init(frame: .zero)
        self.moundSize = max(minMoundSize, round(moundSize ?? standardMoundSize))
        
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        moundMatrix = MoundMatrix(
            numberOfColumns: self.difficulty.numberOfColumns,
            numberOfRows: self.difficulty.numberOfRows,
            delegate: self
        )
    }
    
    required init?(coder: NSCoder) {nil}
    
    override func viewDidChangeEffectiveAppearance() {
        Mound.invalidCaches()
        setWindowBackground()
    }
    
    func layoutMounds() {
        moundMatrix.forEach {mound, index in
            moundMatrix(moundMatrix, update: mound, at: index)
        }
    }
    
    func reuse(undeploys: Bool, extraAction: ((Mound) -> Void)? = nil) {
        if undeploys {
            hasDeployed = false
            moundMatrix.forEach {mound in
                mound.state = .covered(withFlag: .none)
                mound.hint = 0
                extraAction?(mound)
            }
        } else {
            moundMatrix.forEach {mound in
                mound.state = .covered(withFlag: .none)
                if mound.hasMine {
                    mound.showsMine = false
                }
                extraAction?(mound)
            }
        }
    }
    
    func fittingSize(numberOfColumns: Int? = nil, numberOfRows: Int? = nil, moundSize: CGFloat? = nil) -> NSSize {
        let theNumberOfColumns = numberOfColumns ?? self.numberOfColumns
        let theNumberOfRows = numberOfRows ?? self.numberOfRows
        let theMoundSize = moundSize ?? self.moundSize
        return NSSize(
            width: CGFloat(theNumberOfColumns) * theMoundSize + contentInsets.left + contentInsets.right,
            height: CGFloat(theNumberOfRows) * theMoundSize + contentInsets.top + contentInsets.bottom
        )
    }
    
    func moundSize(frame: NSRect? = nil, numberOfColumns: Int? = nil, numberOfRows: Int? = nil, rounds: Bool = true) -> CGFloat {
        let theFrame = frame ?? self.frame
        let theNumberOfColumns = numberOfColumns ?? self.numberOfColumns
        let moundSize = (theFrame.width - contentInsets.left - contentInsets.right) / CGFloat(theNumberOfColumns)
        if rounds {
            return round(moundSize)
        } else {
            return moundSize
        }
    }
    
    func resizeToMatchDifficulty() {
        if moundMatrix.numberOfColumns == numberOfColumns, moundMatrix.numberOfRows == numberOfRows {
            return reuse(undeploys: true)
        }
        
        hasDeployed = false
        
        let oldContentSize = frame.size
        let newContentSize = fittingSize()
        
        let newWindowFrameSize = window!.frameRect(forContentRect: NSRect(origin: .zero, size: newContentSize)).size
        let newWindowFrame = NSRect(
            origin: NSPoint(
                x: round(window!.frame.minX - (newWindowFrameSize.width - window!.frame.width) / 2),
                y: window!.frame.minY - (newWindowFrameSize.height - window!.frame.height)
            ),
            size: newWindowFrameSize
        )
        
        let duration = window!.animationResizeTime(newWindowFrame)
        
        let oldCache = bitmapImageRepForCachingDisplay(in: bounds)!
        cacheDisplay(in: bounds, to: oldCache)
        
        moundMatrix.setSize(numberOfColumns: numberOfColumns, numberOfRows: numberOfRows)
        reuse(undeploys: true) {$0.layout()}
        
        setFrameSize(newContentSize)
        
        let newCache = bitmapImageRepForCachingDisplay(in: bounds)!
        cacheDisplay(in: bounds, to: newCache)
        
        subviews.forEach {$0.isHidden = true}
        setFrameSize(oldContentSize)
        
        let contentAnimation = CABasicAnimation(keyPath: "contents")
        contentAnimation.fromValue = oldCache.cgImage
        contentAnimation.duration = duration
        contentAnimation.delegate = self
        layer!.contents = newCache.cgImage
        layer!.add(contentAnimation, forKey: nil)

        window!.setFrame(newWindowFrame, display: false, animate: true)
        isAnimatingResizing = true
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + duration) {
            self.isAnimatingResizing = false
        }
        
        setWindowRatio()
    }
    
    func deployMines(skip skippedIndices: Set<MoundMatrix.Index>) {
        var mineArray: [Bool] = []
        for _ in 0..<numberOfMines {mineArray.append(true)}
        for _ in numberOfMines..<(numberOfColumns * numberOfRows - skippedIndices.count) {mineArray.append(false)}
        mineArray.shuffle()
        
        var offset = 0
        moundMatrix.forEach {mound, index, rawIndex in
            if skippedIndices.contains(index) {return offset += 1}
            if !mineArray[rawIndex - offset] {return}
            
            mound.hasMine = true
            index.vicinities.forEach {vicinityIndex in
                if let vicinityMound = moundMatrix[vicinityIndex], !vicinityMound.hasMine {
                    vicinityMound.hint += 1
                }
            }
        }
        
        hasDeployed = true
    }
    
    private func beginAnimationWindow(
        from centerMound: Mound, animationViewType AnimationView: AnimationView.Type,
        subanimationWillStart: @escaping (Mound, TimeInterval) -> Void,
        delaysAfterFirstSubanimation: Bool,
        then callback: @escaping () -> Void
    ) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            moundMatrix.forEach {mound, index in
                if mound.hasMine {
                    mound.showMine(animates: true, flashes: true, duration: 0.5)
                }
            }
            return DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: callback)
        }
        
        let animationWindow = AnimationWindow(frame: window!.frame, viewType: AnimationView, didClose: callback)
        let centerIndex = moundMatrix.indexOf(centerMound)!
        
        var minedMounds: [(Mound, Double)] = []
        
        moundMatrix.forEach {mound, index in
            if mound.hasMine {
                let distance = sqrt(pow(Double(index.column - centerIndex.column), 2) + pow(Double(index.row - centerIndex.row), 2))
                minedMounds.append((mound, distance))
            }
        }
        
        var numberOfRemained = minedMounds.count
        
        let animationSignature = Date().timeIntervalSince1970
        self.animationSignature = animationSignature
        
        for (mound, distance) in minedMounds {
            let delay = 0.01 + distance * animationSeparatingDuration + (distance != 0 && delaysAfterFirstSubanimation
                ? delayAfterFirstSubanimation
                : 0
            )
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay) {
                guard animationSignature == self.animationSignature else {return}
                
                subanimationWillStart(mound, animationSignature)
                
                let animationView = AnimationView.init(
                    center: NSPoint(x: mound.frame.midX, y: mound.frame.midY),
                    moundFrameSize: mound.frame.size
                )
                
                animationWindow.contentView!.addSubview(animationView)
                animationView.startAnimation {
                    animationView.removeFromSuperview()
                    numberOfRemained -= 1
                    if numberOfRemained == 0, animationWindow.isVisible {
                        self.closeAnimationWindow(animationWindow)
                    }
                }
            }
        }
        
        window!.addChildWindow(animationWindow, ordered: .above)
    }
    
    func radiate(from centerMound: Mound, then callback: @escaping () -> Void) {
        beginAnimationWindow(
            from: centerMound,
            animationViewType: ShineView.self,
            subanimationWillStart: {mound, _ in
                mound.showMine(animates: true, flashes: true)
            },
            delaysAfterFirstSubanimation: false,
            then: callback
        )
    }
    
    func explode(from centerMound: Mound, then callback: @escaping () -> Void) {
        let delay = Double(BoomView.indexOfMaxContentFrame) * BoomView.frameDuration
        
        beginAnimationWindow(
            from: centerMound,
            animationViewType: BoomView.self,
            subanimationWillStart: {mound, animationSignature in
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (mound == centerMound ? 0 : delay)) {
                    if animationSignature == self.animationSignature {
                        mound.showMine(animates: false)
                    }
                }
            },
            delaysAfterFirstSubanimation: true,
            then: callback
        )
    }
    
    func disturb(from centerMound: Mound, then callback: @escaping () -> Void) {
        let delay = Double(SpinView.indexOfMaxContentFrame) * SpinView.frameDuration
        
        beginAnimationWindow(
            from: centerMound,
            animationViewType: SpinView.self,
            subanimationWillStart: {mound, animationSignature  in
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay) {
                    if animationSignature == self.animationSignature {
                        mound.showMine(animates: true, duration: 0.25)
                    }
                }
            },
            delaysAfterFirstSubanimation: true,
            then: callback
        )
    }
    
    @discardableResult
    func stopAllAnimationsIfNeeded() -> Bool {
        if let childWindows = window?.childWindows, childWindows.count > 0 {
            childWindows.forEach {window in
                if window is AnimationWindow {
                    closeAnimationWindow(window as! AnimationWindow)
                }
            }
            return true
            
        } else {
            return false
        }
    }
    
    func closeAnimationWindow(_ animationWindow: AnimationWindow) {
        animationSignature = Date().timeIntervalSince1970
        
        moundMatrix.forEach {mound in
            if mound.hasMine {mound.showMine(animates: false)}
        }
        
        animationWindow.orderOut(nil)
        window!.removeChildWindow(animationWindow)
    }
    
    override func mouseDown(with event: NSEvent) {
        stopAllAnimationsIfNeeded()
    }
}

extension Minefield: MoundMatrixDelegate {
    func moundMatrix(_ moundMatrix: MoundMatrix, moundAt index: MoundMatrix.Index) -> Mound {
        let mound = Mound()
        mound.wantsLayer = wantsLayer
        mound.delegate = moundDelegate
        self.moundMatrix(moundMatrix, update: mound, at: index)
        addSubview(mound)
        return mound
    }
    
    func moundMatrix(_ moundMatrix: MoundMatrix, update mound: Mound, at index: MoundMatrix.Index) {
        mound.luminosity = CGFloat(index.row) / CGFloat(numberOfRows - 1) * 2 - 1
        mound.edgingMask = Mound.EdgingMask(rawValue:
            (index.row == numberOfRows - 1 ? Mound.EdgingMask.top.rawValue : 0) |
            (index.column == 0 ? Mound.EdgingMask.left.rawValue : 0) |
            (index.row == 0 ? Mound.EdgingMask.bottom.rawValue : 0) |
            (index.column == numberOfColumns - 1 ? Mound.EdgingMask.right.rawValue : 0)
        )
        
        mound.frame = NSRect(
            x: CGFloat(index.column) * moundSize + contentInsets.left,
            y: CGFloat(index.row) * moundSize + contentInsets.bottom,
            width: moundSize, height: moundSize
        )
    }
    
    func moundMatrix(_ moundMatrix: MoundMatrix, didRemove mound: Mound) {
        mound.removeFromSuperview()
    }
}

extension Minefield: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        subviews.forEach {$0.isHidden = false}
        layer!.contents = nil
    }
}

extension Minefield: NSWindowDelegate {
    func setWindowRatio() {
        window!.contentAspectRatio = NSSize(width: numberOfColumns, height: numberOfRows)
    }
    
    func setWindowBackground() {
        if fieldStyle == .sheet,
           let visualEffectView = window!.contentView!.superview!.subviews[0] as? NSVisualEffectView {
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.material = .sidebar
            visualEffectView.state = .followsWindowActiveState
        }
    }
    
    func windowWillAppear(_ window: NSWindow) {
        let newFrameSize = window.frameRect(forContentRect: NSRect(origin: window.frame.origin, size: fittingSize())).size
        window.setFrame(NSRect(origin: NSPoint(x: window.frame.minX + (window.frame.width - newFrameSize.width) / 2,
                                               y: window.frame.minY + (window.frame.height - newFrameSize.height)),
                               size: newFrameSize), display: false)
        setWindowBackground()
        setWindowRatio()
        
        if fieldStyle == .sheet {
            layer!.mask = CALayer()
            if #available(OSX 10.16, *) {
                layer!.mask!.cornerRadius = 8.5
                layer!.mask!.cornerCurve = .continuous
            } else {
                layer!.mask!.cornerRadius = 4
            }
            layer!.mask!.backgroundColor = .black
            layer!.mask!.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer!.mask!.frame = layer!.bounds.insetBy(NSEdgeInsets(top: -layer!.mask!.cornerRadius,
                                                                    left: contentInsets.left + 1,
                                                                    bottom: contentInsets.bottom + 1,
                                                                    right: contentInsets.right + 1))
        }
    }
    
    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
        let fittingSize = self.fittingSize(moundSize: standardMoundSize)
        let contentRect = window.contentRect(forFrameRect: NSRect(x: 0, y: 0, width: fittingSize.width, height: -fittingSize.height))
        
        return NSRect(x: window.frame.minX,
                      y: window.frame.maxY,
                      width: contentRect.width,
                      height: -contentRect.height).standardized
    }
    
    func windowWillResize(_ window: NSWindow, to frameSize: NSSize) -> NSSize {
        guard !isAnimatingResizing else {return frameSize}
        
        let contentRect = window.contentRect(forFrameRect: NSRect(origin: .zero, size: frameSize))
        let moundSize = min(maxMoundSize, max(minMoundSize, self.moundSize(frame: contentRect)))
        
        return window.frameRect(forContentRect: NSRect(origin: .zero, size: fittingSize(moundSize: moundSize))).size
    }
    
    func windowDidResize(_: Notification) {
        guard !isAnimatingResizing else {return}
        moundSize = moundSize(rounds: false)
        layoutMounds()
        stopAllAnimationsIfNeeded()
    }
    
    func windowDidEndLiveResize(_: Notification) {
        delegate?.minefieldWindowDidResize(self)
    }
    
    func windowWillClose(_: Notification) {
        stopAllAnimationsIfNeeded()
    }
    
    func windowShouldClose(_: NSWindow) -> Bool {
        delegate?.minefieldWindowShouldClose(self) ?? true
    }
}
