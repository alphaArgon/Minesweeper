import AppKit

extension MinefieldController {
    @objc func relive(_: Any?) {
        if !minefield.stopAllAnimationsIfNeeded() {
            relive(redeploys: isAlive || sadMacBehavior == .redeploy)
        }
    }
    
    @objc func replay(_: Any?) {
        if !isBattling {
            return relive(redeploys: false)
        }
        
        givingUpAlertWithoutNextDifficultyReminder.beginSheetModal(for: minefield.window!) {response in
            if response == .alertFirstButtonReturn {
                self.relive(redeploys: false)
            }
        }
    }
    
    @objc func newGame(_: Any?) {
        if !isBattling {
            return relive(redeploys: true)
        }

        givingUpAlert.beginSheetModal(for: minefield.window!) {response in
            if response == .alertFirstButtonReturn {
                self.relive(redeploys: true)
            }
        }
    }
    
    @objc func newGameWithDifficulty(_ sender: NSMenuItem) {
        if !isBattling {
            return relive(redeploys: true, difficulty: Minefield.Difficulty(tag: sender.tag))
        }

        givingUpAlert.beginSheetModal(for: minefield.window!) {response in
            if response == .alertFirstButtonReturn {
                self.relive(redeploys: true, difficulty: Minefield.Difficulty(tag: sender.tag))
            }
        }
    }
    
    @objc func openPreferences(_: Any?) {
        minefield.stopAllAnimationsIfNeeded()
        
        let preferenceSheet = PreferenceSheet(difficulty: minefield.difficulty, mineStyle: mineStyle, sadMacBehavior: sadMacBehavior, isBattling: isBattling)
        
        minefield.window!.beginSheet(preferenceSheet) {_ in
            self.sadMacBehavior = preferenceSheet.sadMacBehavior
            self.minefield.mineStyle = preferenceSheet.mineStyle
            self.setUserDefaults(for: [.sadMacBehavior, .mineStyle])
            self.setSadType()
            
            if self.isBattling {
                if preferenceSheet.difficulty != self.minefield.difficulty {
                    if preferenceSheet.givesUpToApplyDifficulty {
                        self.relive(redeploys: true, difficulty: preferenceSheet.difficulty)
                    } else {
                        self.nextDifficulty = preferenceSheet.difficulty
                    }
                }
            } else {
                self.relive(redeploys: self.sadMacBehavior != .replay, difficulty: preferenceSheet.difficulty)
            }
        }
    }
}
