import AppKit

class PreferenceSheet: NSWindow {
    let windowMargin: CGFloat = 20
    
    var givesUpToApplyDifficulty: Bool = false
    var difficulty: Minefield.Difficulty
    var sadMacBehavior: MinefieldController.SadMacBehavior
    var isBattling: Bool
    
    private var originDifficulty: Minefield.Difficulty
    
    let beginnerRadioButton = NSButton(radioButtonWithTitle: "beginner".localized, target: nil, action: #selector(switchDifficulty(_:)))
    let intermediateRadioButton = NSButton(radioButtonWithTitle: "intermediate".localized, target: nil, action: #selector(switchDifficulty(_:)))
    let advancedRadioButton = NSButton(radioButtonWithTitle: "advanced".localized, target: nil, action: #selector(switchDifficulty(_:)))
    let customRadioButton = NSButton(radioButtonWithTitle: "custom".localized, target: nil, action: #selector(switchDifficulty(_:)))
    let helpLabel = NSTextField(labelWithString: "")
    let sizeLabel = NSTextField(labelWithString: "size-label".localized)
    let multiplyLabel = NSTextField(labelWithString: " × ")
    let mineLabel = NSTextField(labelWithString: "mine-label".localized)
    let widthInput = IntegerTextField()
    let heightInput = IntegerTextField()
    let mineInput = IntegerTextField()
    let applyCheckbox = NSButton(checkboxWithTitle: "apply-checkbox".localized, target: nil, action: nil)
    let sadMacPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    let okButton = NSButton(title: "alert-ok".localized, target: nil, action: nil)
    let cancelButton = NSButton(title: "alert-cancel".localized, target: nil, action: nil)
    
    init(difficulty: Minefield.Difficulty, sadMacBehavior: MinefieldController.SadMacBehavior, isBattling: Bool) {
        self.originDifficulty = difficulty
        self.difficulty = difficulty
        self.sadMacBehavior = sadMacBehavior
        self.isBattling = isBattling
        
        super.init(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        
        beginnerRadioButton.target = self
        intermediateRadioButton.target = self
        advancedRadioButton.target = self
        customRadioButton.target = self
        
        beginnerRadioButton.refusesFirstResponder = true
        intermediateRadioButton.refusesFirstResponder = true
        advancedRadioButton.refusesFirstResponder = true
        customRadioButton.refusesFirstResponder = true
        
        beginnerRadioButton.tag = 1
        intermediateRadioButton.tag = 2
        advancedRadioButton.tag = 3
        customRadioButton.tag = 0
        
        widthInput.minValue = 9
        widthInput.maxValue = 30
        heightInput.minValue = 9
        heightInput.maxValue = 24
        mineInput.minValue = 10
        mineInput.maxValue = (difficulty.numberOfColumns - 1) * (difficulty.numberOfRows - 1)
        
        widthInput.setValue(value: difficulty.numberOfColumns)
        heightInput.setValue(value: difficulty.numberOfRows)
        mineInput.setValue(value: difficulty.numberOfMines)
        
        widthInput.target = self
        heightInput.target = self
        mineInput.target = self
        widthInput.action = #selector(fillDifficulty(_:))
        heightInput.action = #selector(fillDifficulty(_:))
        mineInput.action = #selector(fillDifficulty(_:))

        helpLabel.stringValue = String(format: "preferences-help-label".localized, difficulty.numberOfColumns, difficulty.numberOfRows, difficulty.numberOfMines)
        helpLabel.font = NSFont(descriptor: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize).fontDescriptor.addingAttributes([
            NSFontDescriptor.AttributeName.featureSettings: [[
                NSFontDescriptor.FeatureKey.typeIdentifier: kCaseSensitiveLayoutType,
                NSFontDescriptor.FeatureKey.selectorIdentifier: kCaseSensitiveLayoutOnSelector
            ]]
        ]), size: NSFont.smallSystemFontSize)
        
        switch difficulty {
        case .beginner:
            beginnerRadioButton.state = .on
            beginnerRadioButton.refusesFirstResponder = false
        case .intermediate:
            intermediateRadioButton.state = .on
            intermediateRadioButton.refusesFirstResponder = false
        case .advanced:
            advancedRadioButton.state = .on
            advancedRadioButton.refusesFirstResponder = false
        default:
            customRadioButton.state = .on
            customRadioButton.refusesFirstResponder = false
        }
        
        validControls()
        
        applyCheckbox.state = .off
        applyCheckbox.target = self
        applyCheckbox.action = #selector(toggleApplyCheckbox(_:))
        
        sadMacPopUp.addItems(withTitles: [
            MinefieldController.SadMacBehavior(rawValue: 0)!.description,
            MinefieldController.SadMacBehavior(rawValue: 1)!.description,
            MinefieldController.SadMacBehavior(rawValue: 2)!.description
        ])
        sadMacPopUp.selectItem(at: sadMacBehavior.rawValue)
        sadMacPopUp.target = self
        sadMacPopUp.action = #selector(selectSadMacPopUp(_:))
        
        let difficultyLabel = NSTextField(labelWithString: "difficulty-label".localized)
        let clickSadMacLabel = NSTextField(labelWithString: "click-sad-mac-label".localized)
        
        let separator = NSBox()
        separator.boxType = .separator
        
        let emptyInput = NSTextField(string: "")
        
        func placeholder() -> NSView {
            return NSGridCell.emptyContentView
        }
        
        let contentGrid = NSGridView(views: [
            [difficultyLabel,   beginnerRadioButton,        placeholder(),      customRadioButton,  emptyInput                                  ],
            [placeholder(),     intermediateRadioButton,    placeholder(),      sizeLabel,          widthInput,     multiplyLabel,  heightInput ],
            [placeholder(),     advancedRadioButton,        placeholder(),      mineLabel,          mineInput                                   ],
            [placeholder(),     placeholder(),              helpLabel,          placeholder()                                                   ],
            [placeholder(),     applyCheckbox                                                                                                   ],
            [clickSadMacLabel,  sadMacPopUp                                                                                                     ],
            [separator                                                                                                                          ]
        ])
        
        emptyInput.isHidden = true
        
        contentGrid.row(at: 0).topPadding = NSFont.systemFontSize * 0.25
        contentGrid.row(at: 0).mergeCells(in: NSRange(location: 1, length: 2))
        contentGrid.row(at: 0).mergeCells(in: NSRange(location: 1, length: 2))
        contentGrid.row(at: 1).mergeCells(in: NSRange(location: 1, length: 2))
        contentGrid.row(at: 2).mergeCells(in: NSRange(location: 1, length: 2))
        contentGrid.row(at: 2).mergeCells(in: NSRange(location: 4, length: 3))
        contentGrid.row(at: 3).mergeCells(in: NSRange(location: 2, length: 4))
        contentGrid.row(at: 3).topPadding = NSFont.smallSystemFontSize * 0.5
        contentGrid.row(at: 4).topPadding = NSFont.systemFontSize
        contentGrid.row(at: 4).mergeCells(in: NSRange(location: 1, length: 6))
        contentGrid.row(at: 5).topPadding = NSFont.systemFontSize * 1.5
        contentGrid.row(at: 5).mergeCells(in: NSRange(location: 1, length: 6))
        contentGrid.row(at: 6).mergeCells(in: NSRange(location: 0, length: 7))
        contentGrid.row(at: 6).topPadding = NSFont.systemFontSize * 1.25
        contentGrid.row(at: 6).bottomPadding = NSFont.systemFontSize * 1
        
        contentGrid.rowSpacing = NSFont.systemFont(ofSize: -1).xHeight * 0.5
        contentGrid.columnSpacing = 0
        contentGrid.rowAlignment = .firstBaseline
        contentGrid.column(at: 0).trailingPadding = NSFont.systemFontSize
        contentGrid.column(at: 0).xPlacement = .trailing
        contentGrid.column(at: 1).width = 19
        contentGrid.column(at: 2).trailingPadding = NSFont.systemFontSize * 1.5
        contentGrid.column(at: 3).xPlacement = .trailing
        contentGrid.column(at: 4).width = NSFont.systemFontSize * 2.5
        contentGrid.column(at: 6).width = NSFont.systemFontSize * 2.5
        
        okButton.tag = 1
        okButton.target = self
        okButton.action = #selector(collapseSheet(_:))
        cancelButton.tag = 0
        cancelButton.target = self
        cancelButton.action = #selector(collapseSheet(_:))
        
        let buttonSize: CGFloat = 88
        okButton.frame = NSRect(x: okButton.alignmentRectInsets.right - buttonSize - windowMargin, y: windowMargin - okButton.alignmentRectInsets.bottom, width: buttonSize, height: okButton.frame.height)
        cancelButton.frame = NSRect(x: okButton.frame.minX - buttonSize, y: windowMargin - cancelButton.alignmentRectInsets.bottom, width: buttonSize, height: cancelButton.frame.height)
        okButton.autoresizingMask = [.minXMargin]
        cancelButton.autoresizingMask = [.minXMargin]
        okButton.keyEquivalent = "\r"
        
        contentGrid.frame = NSRect(origin: NSPoint(x: windowMargin, y: okButton.frame.maxY), size: contentGrid.fittingSize)
        
        contentView!.addSubview(contentGrid)
        contentView!.addSubview(okButton)
        contentView!.addSubview(cancelButton)
        
        setContentSize(NSSize(width: contentGrid.frame.maxX + windowMargin, height: contentGrid.frame.maxY + windowMargin))
    }
    
    func validControls() {
        let controls = [sizeLabel, widthInput, multiplyLabel, heightInput, mineLabel, mineInput]
        
        if customRadioButton.state == .on {
            controls.forEach {$0.isEnabled = true}
            helpLabel.textColor = .disabledControlTextColor
        } else {
            controls.forEach {$0.isEnabled = false}
            helpLabel.textColor = nil
            helpLabel.stringValue = String(format: "preferences-help-label".localized, difficulty.numberOfColumns, difficulty.numberOfRows, difficulty.numberOfMines)
        }
        
        applyCheckbox.isEnabled = isBattling && difficulty != originDifficulty
    }
    
    override func keyDown(with event: NSEvent) {
        let nextRadioButton: NSButton
        
        switch firstResponder {
        case beginnerRadioButton:
            switch event.keyCode {
            case 124: nextRadioButton = customRadioButton
            case 125: nextRadioButton = intermediateRadioButton
            default: return super.keyDown(with: event)
            }
        case intermediateRadioButton:
            switch event.keyCode {
            case 125: nextRadioButton = advancedRadioButton
            case 126: nextRadioButton = beginnerRadioButton
            default: return super.keyDown(with: event)
            }
        case advancedRadioButton:
            switch event.keyCode {
            case 126: nextRadioButton = intermediateRadioButton
            default: return super.keyDown(with: event)
            }
        case customRadioButton:
            switch event.keyCode {
            case 123: nextRadioButton = beginnerRadioButton
            default: return super.keyDown(with: event)
            }
        default:
            return super.keyDown(with: event)
        }
        
        nextRadioButton.refusesFirstResponder = false
        makeFirstResponder(nextRadioButton)
        (firstResponder as! NSButton).refusesFirstResponder = true
        nextRadioButton.performClick(nextRadioButton)
    }
    
    @objc func switchDifficulty(_ sender: NSButton) {
        makeFirstResponder(sender)
        
        switch sender.tag {
        case 1:
            difficulty = .beginner
        case 2:
            difficulty = .intermediate
        case 3:
            difficulty = .advanced
        default:
            difficulty = .init(numberOfColumns: widthInput.value, numberOfRows: heightInput.value, numberOfMines: mineInput.value)
        }

        validControls()
    }
    
    @objc func fillDifficulty(_ sender: IntegerTextField) {
        if sender != mineInput {
            mineInput.maxValue = (widthInput.value - 1) * (heightInput.value - 1)
            if mineInput.value > mineInput.maxValue! {
                mineInput.setValue(value: mineInput.maxValue!)
            }
        }
        difficulty = Minefield.Difficulty(numberOfColumns: widthInput.value, numberOfRows: heightInput.value, numberOfMines: mineInput.value)
        applyCheckbox.isEnabled = isBattling && difficulty != originDifficulty
    }
    
    @objc func toggleApplyCheckbox(_ sender: NSButton) {
        givesUpToApplyDifficulty = sender.state == .on
    }
    
    @objc func selectSadMacPopUp(_ sender: NSPopUpButton) {
        sadMacBehavior = MinefieldController.SadMacBehavior(rawValue: sender.indexOfSelectedItem)!
    }
    
    @objc func collapseSheet(_ sender: NSButton) {
        sheetParent!.endSheet(self, returnCode: sender.tag == 1 ? .OK : .cancel)
    }
}

class IntegerTextField: NSTextField {
    var minValue: Int?
    var maxValue: Int?
    var value: Int = 0
    
    init() {
        super.init(frame: .zero)
        cell!.sendsActionOnEndEditing = true
    }
        
    required init?(coder: NSCoder) {nil}
    
    func setValue(value: Int) {
        self.stringValue = String(value)
        self.value = value
    }
    
    override func textShouldEndEditing(_ textObject: NSText) -> Bool {
        if let newValue = Int(textObject.string) {
            value = newValue
            if maxValue != nil {
                value = min(maxValue!, value)
            }
            if minValue != nil {
                value = max(minValue!, value)
            }
        }
        
        let newString = String(value)
        if newString != textObject.string {
            NSSound.beep()
        }
        
        textObject.string = newString
        return super.textShouldEndEditing(textObject)
    }
}
