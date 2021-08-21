import AppKit

class MinefieldController: NSViewController {
    enum SadMacBehavior: Int {
        case askEveryTime
        case redeploy
        case replay
        
        var description: String {
            switch self {
            case .askEveryTime: return "do-nothing".localized
            case .redeploy: return "start-a-new-game".localized
            case .replay: return "replay".localized
            }
        }
    }
    
    enum UserDefaultsKey: String {
        case moundSize = "MoundSize"
        case mineStyle = "MineStyle"
        case fieldStyle = "FieldStyle"
        case difficulty = "Difficulty"
        case sadMacBehavior = "SadMacBehavior"
        case states = "States"
        case timeInterval = "TimeInterval"
    }
    
    var minefield: Minefield {
        set {view = newValue}
        get {view as! Minefield}
    }
    
    static let monospacedDigitSystemFont: NSFont = {
        if #available(OSX 10.16, *) {
            return NSFont.monospacedDigitSystemFont(ofSize: 15.61, weight: .light)
        } else {
            return NSFont.monospacedDigitSystemFont(ofSize: 12.77, weight: .regular)
        }
    }()
    
    let timerButton: ToolbarButton = {
        if #available(OSX 10.16, *) {
            return ImagedButton(widthOfTitle: "", attributes: [.font: monospacedDigitSystemFont])
        } else {
            return ImagedButton(widthOfTitle: "00::00", attributes: [.font: monospacedDigitSystemFont])
        }
    }()
    
    let counterButton: ToolbarButton = {
        if #available(OSX 10.16, *) {
            return ImagedButton(widthOfTitle: "", attributes: [.font: monospacedDigitSystemFont])
        } else {
            return ImagedButton(widthOfTitle: "00::00", attributes: [.font: monospacedDigitSystemFont])
        }
    }()
    
    let smileyButton: SmileyButton = SmileyButton(target: nil, action: #selector(relive(_:)))
    
    let timerToolbarItem: NSToolbarItem = NSToolbarItem(itemIdentifier: .timer)
    let smileyToolbarItem: NSToolbarItem = NSToolbarItem(itemIdentifier: .smiley)
    let counterToolbarItem: NSToolbarItem = NSToolbarItem(itemIdentifier: .counter)
    
    var numberOfCoveredMounds: Int = 0
    var numberOfFlags: Int = 0 {
        didSet {
            counterToolbarItem.label = String(minefield.numberOfMines - numberOfFlags)
            counterButton.title = counterToolbarItem.label
        }
    }
    
    var isBattling: Bool = false
    var isAlive: Bool = true
    var canAct: Bool = true
    var sadMacBehavior: SadMacBehavior = .askEveryTime
    
    var nextDifficultyReminder: String = ""
    var nextDifficulty: Minefield.Difficulty? {
        didSet {
            if let nextDifficulty = self.nextDifficulty {
                nextDifficultyReminder =  String(
                    format: "next-difficulty".localized,
                    nextDifficulty.numberOfColumns, nextDifficulty.numberOfRows, nextDifficulty.numberOfMines
                )
            } else {
                nextDifficultyReminder = ""
            }
        }
    }
    
    lazy var savingAlert: NSAlert = {
        let alert = NSAlert()
        alert.messageText = "saving-alert-title".localized
        alert.addButton(withTitle: "saving-alert-ok".localized)
        alert.addButton(withTitle: "alert-cancel".localized)
        alert.addButton(withTitle: "saving-alert-delete".localized)
        return alert
    }()
    
    private lazy var _givingUpAlert: NSAlert = {
        let alert = NSAlert()
        alert.messageText = "giving-up-alert-title".localized
        alert.addButton(withTitle: "giving-up-alert-ok".localized)
        alert.addButton(withTitle: "alert-cancel".localized)
        return alert
    }()
    
    var givingUpAlert: NSAlert {
        _givingUpAlert.informativeText = nextDifficultyReminder
        return _givingUpAlert
    }
    
    var givingUpAlertWithoutNextDifficultyReminder: NSAlert {
        _givingUpAlert.informativeText = ""
        return _givingUpAlert
    }
    
    var timer: Timer = Timer()
    var timeInterval: Int = 0 {
        didSet {
            let seconds = timeInterval % 60
            let minutes = timeInterval / 60 % 60
            let hours = timeInterval / 60 / 60
            timerToolbarItem.label = hours > 0
                ? "\(hours):\(minutes > 9 ? "" : "0")\(minutes):\(seconds > 9 ? "" : "0")\(seconds)"
                : "\(minutes):\(seconds > 9 ? "" : "0")\(seconds)"
            timerButton.title = timerToolbarItem.label
            if #available(OSX 10.14, *) {} else {
                timerToolbarItem.minSize = NSSize(width: max(timerButton.intrinsicContentSize.width,
                                                             (timerButton as! ImagedButton).width ?? 40),
                                                  height: timerToolbarItem.minSize.height)
            }
        }
    }
    
    private lazy var _failedAlert: NSAlert = {
        let alert = NSAlert()
        alert.messageText = "failed-alert-title".localized
        alert.addButton(withTitle: "failed-alert-ok".localized)
        alert.addButton(withTitle: "failed-alert-cancel".localized)
        return alert
    }()
    
    var failedAlert: NSAlert {
        _failedAlert.informativeText = nextDifficultyReminder
        return _failedAlert
    }
    
    private lazy var _succeededAlert: NSAlert = {
        let alert = NSAlert()
        alert.messageText = "succeed-alert-title".localized
        alert.addButton(withTitle: "succeed-alert-ok".localized)
        return alert
    }()
    
    var succeededAlert: NSAlert {
        _succeededAlert.informativeText = nextDifficultyReminder
        return _succeededAlert
    }
    
    func userDefault(for key: UserDefaultsKey) -> Any? {
        switch key {
        case .moundSize:
            if let moundSize = UserDefaults.standard.object(forKey: key.rawValue) as? Double {
                return CGFloat(moundSize)
            }
        case .mineStyle:
            if let mineStyle = UserDefaults.standard.object(forKey: key.rawValue) as? Int {
                return Minefield.MineStyle(rawValue: mineStyle)
            }
        case .fieldStyle:
            if let fieldStyle = UserDefaults.standard.object(forKey: key.rawValue) as? Int {
                return Minefield.FieldStyle(rawValue: fieldStyle)
            }
        case .difficulty:
            if let difficulty = UserDefaults.standard.array(forKey: key.rawValue) as? [Int] {
                return Minefield.Difficulty(rawValues: difficulty)
            }
        case .sadMacBehavior:
            if let sadMacBehavior = UserDefaults.standard.object(forKey: key.rawValue) as? Int {
                return SadMacBehavior(rawValue: sadMacBehavior)
            }
        case .states:
            return UserDefaults.standard.string(forKey: key.rawValue)
            
        case .timeInterval:
            return UserDefaults.standard.object(forKey: key.rawValue) as? Int
        }
        return nil
    }
    
    func setUserDefaults(for keys: [UserDefaultsKey]) {
        keys.forEach {key in
            switch key {
            case .moundSize:
                UserDefaults.standard.set(minefield.moundSize, forKey: key.rawValue)
            case .mineStyle:
                UserDefaults.standard.set(minefield.mineStyle.rawValue, forKey: key.rawValue)
            case .fieldStyle:
                UserDefaults.standard.set(minefield.fieldStyle.rawValue, forKey: key.rawValue)
            case .difficulty:
                UserDefaults.standard.set(minefield.difficulty.rawValues, forKey: key.rawValue)
            case .sadMacBehavior:
                UserDefaults.standard.set(sadMacBehavior.rawValue, forKey: key.rawValue)
            case .states:
                UserDefaults.standard.set(minefield.states, forKey: key.rawValue)
            case .timeInterval:
                UserDefaults.standard.set(timeInterval, forKey: key.rawValue)
            }
        }
    }
    
    func removeUserDefaults(for keys: [UserDefaultsKey]) {
        keys.forEach {UserDefaults.standard.removeObject(forKey: $0.rawValue)}
    }
    
    func setEmotion(_ emotion: SmileyButton.Emotion) {
        smileyButton.emotion = emotion
        smileyToolbarItem.label = emotion == .happy ? "Happy Mac" : "Sad Mac"
    }
    
    func setSadType() {
        smileyButton.sadType = mineStyle == .flower ? .jokingly : .deadly
    }
    
    override func loadView() {
        if let sadMacBehavior = userDefault(for: .sadMacBehavior) as? SadMacBehavior {
            self.sadMacBehavior = sadMacBehavior
        }
        
        minefield = Minefield(
            mineStyle: userDefault(for: .mineStyle) as? Minefield.MineStyle,
            fieldStyle: userDefault(for: .fieldStyle) as? Minefield.FieldStyle,
            moundSize: userDefault(for: .moundSize) as? CGFloat,
            difficulty: userDefault(for: .difficulty) as? Minefield.Difficulty,
            moundDelegate: self
        )
        
        minefield.delegate = self
        
        timerToolbarItem.paletteLabel = "timer".localized
        smileyToolbarItem.paletteLabel = "smiley".localized
        counterToolbarItem.paletteLabel = "counter".localized
        
        for (button, toolbarItem) in [
            (timerButton, timerToolbarItem),
            (smileyButton, smileyToolbarItem),
            (counterButton, counterToolbarItem)
        ] {
            button.isDisabled = true
            if #available(OSX 10.16, *) {
                button.bezelStyle = .texturedRounded
            } else if fieldStyle == .solid {
                button.bezelStyle = .texturedRounded
            } else {
                button.isBordered = false
            }
            toolbarItem.view = button
            if #available(OSX 10.14, *) {} else {
                toolbarItem.minSize = NSSize(width: max(button.intrinsicContentSize.width, 40),
                                             height: toolbarItem.minSize.height)
            }
        }

        setSadType()
        
        if let states = userDefault(for: .states) as? String {
            isBattling = true
            timeInterval = userDefault(for: .timeInterval) as? Int ?? 0
            removeUserDefaults(for: [.states, .timeInterval])
            
            minefield.states = states
            startTimer()
            setEmotion(.happy)
            
            var numberOfFlags = 0
            minefield.moundMatrix.forEach {mound, _ in
                if mound.state == .covered(withFlag: .certain) {
                    numberOfFlags += 1
                }
            }
            
            self.numberOfFlags = numberOfFlags
            
        } else {
            relive(redeploys: false)
        }
    }
    
    override func viewWillAppear() {
        minefield.window!.delegate = minefield
        minefield.windowWillAppear(minefield.window!)
    }
    
    func startTimer() {
        timer = Timer(timeInterval: 1, repeats: true) {_ in self.timeInterval += 1}
        RunLoop.current.add(timer, forMode: .default)
    }
    
    func stopTimer() {
        timer.invalidate()
    }
    
    func relive(redeploys: Bool, difficulty newDifficulty: Minefield.Difficulty? = nil) {
        minefield.stopAllAnimationsIfNeeded()
        canAct = true
        
        if isBattling {
            stopTimer()
            isBattling = false
        }
        
        if redeploys, let difficulty = newDifficulty ?? nextDifficulty {
            nextDifficulty = nil
            if difficulty == minefield.difficulty {
                minefield.reuse(undeploys: true)
            } else {
                minefield.difficulty = difficulty
                minefield.resizeToMatchDifficulty()
                setUserDefaults(for: [.difficulty])
            }
        } else {
            minefield.reuse(undeploys: redeploys)
        }
        
        setEmotion(.happy)
        smileyButton.isDisabled = true
        numberOfCoveredMounds = minefield.numberOfMounds
        numberOfFlags = 0
        isAlive = true
        timeInterval = 0
    }
    
    func succeed(by mound: Mound) {
        stopTimer()
        isBattling = false
        canAct = false
        
        if self.sadMacBehavior != .askEveryTime {
            self.smileyButton.isDisabled = false
        }
        
        minefield.radiate(from: mound) {
            if self.sadMacBehavior == .askEveryTime {
                self.succeededAlert.beginSheetModal(for: self.minefield.window!) {_ in
                    self.relive(redeploys: true)
                }
            }
        }
    }
    
    func fail(by mound: Mound) {
        stopTimer()
        isBattling = false
        isAlive = false
        canAct = false
        setEmotion(.sad)
        
        if self.sadMacBehavior != .askEveryTime {
            self.smileyButton.isDisabled = false
        }
        
        let callback = {
            if self.sadMacBehavior == .askEveryTime {
                self.failedAlert.beginSheetModal(for: self.minefield.window!) {response in
                    self.relive(redeploys: response == .alertFirstButtonReturn)
                }
            }
        }
        
        switch mineStyle {
        case .bomb: minefield.explode(from: mound, then: callback)
        case .flower: minefield.disturb(from: mound, then: callback)
        }
    }
}

extension MinefieldController: MinefieldDelegate {
    func minefieldWindowShouldClose(_: Minefield) -> Bool {
        if !isBattling {return true}
        
        savingAlert.beginSheetModal(for: minefield.window!, completionHandler: NSApplication.shared.stopModal(withCode:))
        switch savingAlert.runModal() {
        case .alertFirstButtonReturn:
            setUserDefaults(for: [.states, .timeInterval])
            fallthrough
        case .alertThirdButtonReturn:
            return true
        default:
            return false
        }
    }
    
    func minefieldWindowDidResize(_ minefield: Minefield) {
        setUserDefaults(for: [.moundSize])
    }
}

extension MinefieldController: MoundDelegate {
    var mineStyle: Minefield.MineStyle {minefield.mineStyle}
    
    var fieldStyle: Minefield.FieldStyle {minefield.fieldStyle}
    
    func moundCanAct(_ mound: Mound) -> Bool {canAct}
    
    func moundDidDig(_ mound: Mound) {
        if !isBattling {
            if !minefield.hasDeployed {
                minefield.deployMines(skip: minefield.moundMatrix.indexOf(mound)!.vicinities.filter {
                    minefield.moundMatrix.contains(index: $0)
                })
            }
            isBattling = true
            startTimer()
        }
        
        if mound.hasMine {
            return fail(by: mound)
        }
        
        numberOfCoveredMounds -= 1
        
        if numberOfCoveredMounds == minefield.numberOfMines {
            return succeed(by: mound)
        }
        
        if mound.hint > 0 {
            return
        }
        
        minefield.moundMatrix.indexOf(mound)!.vicinities.forEach {vicinityIndex in
            if let vicinityMound = minefield.moundMatrix[vicinityIndex],
                !vicinityMound.hasMine,
                vicinityMound.state == .covered(withFlag: .none) {
                vicinityMound.dig()
            }
        }
    }
    
    func moundNeedDigVicinities(_ mound: Mound) {
        if mound.hint == 0 {return}
        
        var numberOfFlaggedVicinities = 0
        var vicinityMounds: [Mound] = []
        
        minefield.moundMatrix.indexOf(mound)!.vicinities.forEach {vicinityIndex in
            if let vicinityMound = minefield.moundMatrix[vicinityIndex] {
                switch vicinityMound.state {
                case .exposed:
                    return
                case .covered(withFlag: .none):
                    vicinityMounds.append(vicinityMound)
                default:
                    numberOfFlaggedVicinities += 1
                }
            }
        }
        
        if numberOfFlaggedVicinities >= mound.hint {
            return vicinityMounds.forEach {$0.dig()}
        }
        
        NSCursor.operationNotAllowed.push()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.75) {
            NSCursor.current.pop()
        }
    }
    
    func mound(_: Mound, shouldFlagAs flag: Mound.Flag) -> Bool {
        if !isBattling {return false}
        
        switch flag {
        case .uncertain:
            numberOfFlags -= 1
        case .certain:
            guard numberOfFlags < minefield.numberOfMines else {return false}
            numberOfFlags += 1
        default:
            break
        }
        
        return true
    }
    
}
