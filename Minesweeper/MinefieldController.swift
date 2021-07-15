import AppKit

class MinefieldController: NSViewController {
    enum SadMacBehavior: Int {
        case askEveryTime
        case redeploy
        case replay
        
        var description: String {
            switch self {
            case .askEveryTime:
                return "do-nothing".localized
            case .redeploy:
                return "start-a-new-game".localized
            case .replay:
                return "replay".localized
            }
        }
    }
    
    enum UserDefaultsKey: String {
        case moundSize = "MoundSize"
        case difficulty = "Difficulty"
        case sadMacBehavior = "SadMacBehavior"
        case states = "States"
        case timeInterval = "TimeInterval"
    }
    
    let userDefaults: UserDefaults = UserDefaults()
    
    var minefield: Minefield {
        set {view = newValue}
        get {view as! Minefield}
    }
    
    let timerButton: NSButton = NSButton(title: "00:00", target: nil, action: nil)
    let counterButton: NSButton = NSButton(title: "00:00", target: nil, action: nil)
    let smileyButton: SmileyButton = SmileyButton(target: nil, action: #selector(relive(_:)))
    
    var numberOfCoveredMounds: Int = 0
    var numberOfFlags: Int = 0 {
        didSet {
            counterButton.title = String(minefield.numberOfMines - numberOfFlags)
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
            timerButton.title = "\(timeInterval / 60):\(seconds > 9 ? "" : "0")\(seconds)"
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
            if let moundSize = userDefaults.object(forKey: key.rawValue) as? Double {
                return CGFloat(moundSize)
            }
        case .difficulty:
            if let difficulty = userDefaults.array(forKey: key.rawValue) as? [Int] {
                return Minefield.Difficulty(rawValues: difficulty)
            }
        case .sadMacBehavior:
            if let sadMacBehavior = userDefaults.object(forKey: key.rawValue) as? Int {
                return SadMacBehavior(rawValue: sadMacBehavior)
            }
        case .states:
            return userDefaults.string(forKey: key.rawValue)
            
        case .timeInterval:
            return userDefaults.object(forKey: key.rawValue) as? Int
        }
        
        return nil
    }
    
    func setUserDefaults(for keys: [UserDefaultsKey]) {
        keys.forEach {key in
            switch key {
            case .moundSize:
                userDefaults.set(minefield.moundSize, forKey: key.rawValue)
            case .difficulty:
                userDefaults.set(minefield.difficulty.rawValues, forKey: key.rawValue)
            case .sadMacBehavior:
                userDefaults.set(sadMacBehavior.rawValue, forKey: key.rawValue)
            case .states:
                userDefaults.set(minefield.states, forKey: key.rawValue)
            case .timeInterval:
                userDefaults.set(timeInterval, forKey: key.rawValue)
            }
        }
    }
    
    func removeUserDefaults(for keys: [UserDefaultsKey]) {
        keys.forEach {key in
            userDefaults.removeObject(forKey: key.rawValue)
        }
    }
    
    override func loadView() {
        if let sadMacBehavior = userDefault(for: .sadMacBehavior) as? SadMacBehavior {
            self.sadMacBehavior = sadMacBehavior
        }
        
        minefield = Minefield(
            moundSize: userDefault(for: .moundSize) as? CGFloat,
            difficulty: userDefault(for: .difficulty) as? Minefield.Difficulty,
            moundDelegate: self
        )
        
        minefield.delegate = self
        
        timerButton.isEnabled = false
        smileyButton.isEnabled = false
        counterButton.isEnabled = false
        (timerButton.cell as! NSButtonCell).imageDimsWhenDisabled = false
        (smileyButton.cell as! NSButtonCell).imageDimsWhenDisabled = false
        (counterButton.cell as! NSButtonCell).imageDimsWhenDisabled = false
        
        let monospacedDigitSystemFont = NSFont.monospacedDigitSystemFont(ofSize: -1, weight: .regular)
        timerButton.font = monospacedDigitSystemFont
        counterButton.font = monospacedDigitSystemFont
        
        if let states = userDefault(for: .states) as? String {
            isBattling = true
            minefield.states = states
            timeInterval = userDefault(for: .timeInterval) as? Int ?? 0
            startTimer()
            
            removeUserDefaults(for: [.states, .timeInterval])
            
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
        
        smileyButton.emotion = .happy
        smileyButton.isEnabled = false
        numberOfCoveredMounds = minefield.numberOfMounds
        numberOfFlags = 0
        isAlive = true
        timeInterval = 0
    }
    
    func succeed(by mound: Mound) {
        stopTimer()
        isBattling = false
        canAct = false
        
        minefield.radiate(from: mound) {
            if self.sadMacBehavior == .askEveryTime {
                self.succeededAlert.beginSheetModal(for: self.minefield.window!) {_ in
                    self.relive(redeploys: true)
                }
            } else {
                self.smileyButton.isEnabled = true
            }
        }
    }
    
    func fail(by mound: Mound) {
        stopTimer()
        isBattling = false
        isAlive = false
        canAct = false
        smileyButton.emotion = .sad

        minefield.explode(from: mound) {
            if self.sadMacBehavior == .askEveryTime {
                self.failedAlert.beginSheetModal(for: self.minefield.window!) {response in
                    self.relive(redeploys: response == .alertFirstButtonReturn)
                }
            } else {
                self.smileyButton.isEnabled = true
            }
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
    func moundCanAct(_: Mound) -> Bool {canAct}
    
    func moundDidDig(_ mound: Mound) {
        if !isBattling {
            if !minefield.hasDeployed {
                minefield.deployMines(indicesOfSafeMounds: minefield.moundMatrix.indexOf(mound)!.vicinities.filter {
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
