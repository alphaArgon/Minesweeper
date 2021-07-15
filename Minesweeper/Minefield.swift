import AppKit

protocol MinefieldDelegate: class {
    func minefieldWindowShouldClose(_ minefield: Minefield) -> Bool
    func minefieldWindowDidResize(_ minefield: Minefield)
}

class Minefield: NSView {
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
            case 1: self = Self.beginner
            case 2: self = Self.intermediate
            case 3: self = Self.advanced
            default: return nil
            }
        }
    }
    
    weak var delegate: MinefieldDelegate?
    
    var difficulty: Difficulty
    var moundMatrix: MoundMatrix
    
    var numberOfColumns: Int {difficulty.numberOfColumns}
    var numberOfRows: Int {difficulty.numberOfRows}
    var numberOfMounds: Int {difficulty.numberOfColumns * difficulty.numberOfRows}
    var numberOfMines: Int {difficulty.numberOfMines}
    
    static let standardMoundSize: CGFloat = 24
    static let minMoundSize: CGFloat = 21
    static let maxMoundSize: CGFloat = 36
    var moundSize: CGFloat
    
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
    
    init(moundSize: CGFloat?, difficulty: Difficulty?, moundDelegate: MoundDelegate) {
        self.moundSize = round(moundSize ?? Self.standardMoundSize)
        self.difficulty = difficulty ?? .beginner
        self.moundMatrix = MoundMatrix(
            numberOfColumns: self.difficulty.numberOfColumns,
            numberOfRows: self.difficulty.numberOfRows,
            delegate: moundDelegate
        )
        super.init(frame: NSRect(
            x: 0, y: 0,
            width: CGFloat(self.difficulty.numberOfColumns) * self.moundSize,
            height: CGFloat(self.difficulty.numberOfRows) * self.moundSize
        ))
        
        canDrawSubviewsIntoLayer = true
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        layoutMounds()
    }
    
    required init?(coder: NSCoder) {nil}
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setWindowRatio()
    }
    
    func layoutMounds() {
        moundMatrix.forEach {mound, index in
            mound.luminosity = CGFloat(index.row) / CGFloat(numberOfRows - 1) * 2 - 1
            mound.frame = NSRect(
                x: CGFloat(index.column) * moundSize,
                y: CGFloat(index.row) * moundSize,
                width: moundSize, height: moundSize
            )
            if subviews.count < numberOfMounds{
                addSubview(mound)
            }
        }
    }
    
    func setWindowRatio() {
        window!.contentAspectRatio = frame.size
    }
    
    func reuse(undeploys: Bool) {
        if undeploys {
            hasDeployed = false
            moundMatrix.forEach {mound in
                mound.state = .covered(withFlag: .none)
                mound.hint = 0
            }
        } else {
            moundMatrix.forEach {mound in
                mound.state = .covered(withFlag: .none)
                if mound.hasMine {
                    mound.showsMine = false
                }
            }
        }
    }
    
    func resizeToMatchDifficulty() {
        if moundMatrix.numberOfColumns == numberOfColumns, moundMatrix.numberOfRows == numberOfRows {
            return reuse(undeploys: true)
        }
        
        moundMatrix.setSize(numberOfColumns: numberOfColumns, numberOfRows: numberOfRows)
        
        hasDeployed = false
        
        let oldContentSize = frame.size
        let newContentSize = NSSize(
            width: CGFloat(numberOfColumns) * moundSize,
            height: CGFloat(numberOfRows) * moundSize
        )
        
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
        
        subviews.removeAll()
        
        reuse(undeploys: true)
        
        moundMatrix.forEach {mound, index in
            mound.luminosity = CGFloat(index.row) / CGFloat(numberOfRows - 1) * 2 - 1
            mound.frame = NSRect(
                x: CGFloat(index.column) * moundSize,
                y: CGFloat(index.row) * moundSize,
                width: moundSize, height: moundSize
            )
            addSubview(mound)
        }
        
        setFrameSize(newContentSize)
        
        let newCache = bitmapImageRepForCachingDisplay(in: bounds)!
        cacheDisplay(in: bounds, to: newCache)
        
        setFrameSize(oldContentSize)
        
        let contentAnimation = CABasicAnimation(keyPath: "contents")
        contentAnimation.fromValue = oldCache.cgImage
        contentAnimation.toValue = newCache.cgImage
        contentAnimation.duration = duration * 1.25
        
        layer!.add(contentAnimation, forKey: nil)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.commit()
        
        window!.setFrame(newWindowFrame, display: false, animate: true)
        isAnimatingResizing = true
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + duration) {
            self.isAnimatingResizing = false
        }
        
        setWindowRatio()
    }
    
    func deployMines(indicesOfSafeMounds: Set<MoundMatrix.Index>) {
        var mineArray: [Bool] = []
        for _ in 0..<numberOfMines {mineArray.append(true)}
        for _ in numberOfMines..<(numberOfColumns * numberOfRows - indicesOfSafeMounds.count) {mineArray.append(false)}
        mineArray.shuffle()
        
        var offset = 0
        moundMatrix.forEach {mound, index, internalIndex in
            if indicesOfSafeMounds.contains(index) {return offset += 1}
            if !mineArray[internalIndex - offset] {return}
            
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
        subanimationWillStart: @escaping (Mound) -> Void,
        delaysAfterFirstSubanimation: Bool,
        then callback: @escaping () -> Void
    ) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            moundMatrix.forEach {mound, index in
                if mound.hasMine {
                    mound.showMine(animates: true, duration: 0.5)
                }
            }
            return DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: callback)
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
                
                subanimationWillStart(mound)
                
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
            subanimationWillStart: {mound in
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
            subanimationWillStart: {mound in
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (mound == centerMound ? 0 : delay)) {
                    mound.showMine(animates: false)
                }
            },
            delaysAfterFirstSubanimation: true,
            then: callback
        )
    }
    
    func stopAllAnimationsIfNeeded() {
        window?.childWindows?.forEach {window in
            if window is AnimationWindow {
                closeAnimationWindow(window as! AnimationWindow)
            }
        }
    }
    
    func closeAnimationWindow(_ animationWindow: AnimationWindow) {
        animationSignature = Date().timeIntervalSince1970
        
        moundMatrix.forEach {mound in
            if mound.hasMine, !mound.showsMine {
                mound.showsMine = true
            }
        }
        
        animationWindow.orderOut(nil)
        window!.removeChildWindow(animationWindow)
    }
    
    override func mouseDown(with event: NSEvent) {
        stopAllAnimationsIfNeeded()
    }
}

extension Minefield: NSWindowDelegate {
    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
        let contentRect = window.contentRect(forFrameRect: NSRect(
            x: 0, y: 0,
            width: CGFloat(numberOfColumns) * Self.standardMoundSize,
            height: -CGFloat(numberOfRows) * Self.standardMoundSize
        ))
        
        return NSRect(
            x: window.frame.minX,
            y: window.frame.maxY,
            width: contentRect.width,
            height: -contentRect.height
        ).standardized
    }
    
    func windowWillResize(_ window: NSWindow, to frameSize: NSSize) -> NSSize {
        guard !isAnimatingResizing else {return frameSize}
        
        let contentRect = window.contentRect(forFrameRect: NSRect(origin: .zero, size: frameSize))
        let moundSize = min(Self.maxMoundSize, max(Self.minMoundSize,
            round(contentRect.width / CGFloat(numberOfColumns))
        ))
        
        return window.frameRect(forContentRect: NSRect(origin: .zero, size: NSSize(
            width: CGFloat(numberOfColumns) * moundSize,
            height: CGFloat(numberOfRows) * moundSize)
        )).size
    }
    
    func windowDidResize(_: Notification) {
        guard !isAnimatingResizing else {return}
        moundSize = frame.width / CGFloat(numberOfColumns)
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
