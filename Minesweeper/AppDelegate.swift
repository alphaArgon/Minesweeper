import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSToolbarDelegate {
    let window: NSWindow = NSWindow(contentRect: .zero, styleMask: [.closable, .miniaturizable, .titled, .resizable], backing: .buffered, defer: true)
    let controller: MinefieldController = MinefieldController()
    
    let timerToolbarItem: NSToolbarItem = NSToolbarItem(itemIdentifier: .timer)
    let smileyToolbarItem: NSToolbarItem = NSToolbarItem(itemIdentifier: .smiley)
    let counterToolbarItem: NSToolbarItem = NSToolbarItem(itemIdentifier: .counter)
    
    func applicationWillFinishLaunching(_: Notification) {
        let appMenu = NSMenu(title: "minesweeper".localized)
        appMenu.addItem(withTitle: "about-minesweeper".localized, action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "open-preferences".localized, action: #selector(MinefieldController.openPreferences(_:)), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "hide-minesweeper".localized, action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "hide-others".localized, action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h", modifiers: [.command, .option])
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "quit-minesweeper".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        let gameMenu = NSMenu(title: "game".localized)
        gameMenu.addItem(withTitle: "replay".localized, action: #selector(MinefieldController.replay(_:)), keyEquivalent: "r")
        gameMenu.addItem(.separator())
        gameMenu.addItem(withTitle: "new".localized, action: #selector(MinefieldController.newGame(_:)), keyEquivalent: "n")
        let newGameWithDifficultyMenu = NSMenu(title: "new-with-difficulty".localized)
        newGameWithDifficultyMenu.addItem(withTitle: "beginner".localized, action: #selector(MinefieldController.newGameWithDifficulty(_:)), keyEquivalent: "1", tag: 1)
        newGameWithDifficultyMenu.addItem(withTitle: "intermediate".localized, action: #selector(MinefieldController.newGameWithDifficulty(_:)), keyEquivalent: "2", tag: 2)
        newGameWithDifficultyMenu.addItem(withTitle: "advanced".localized, action: #selector(MinefieldController.newGameWithDifficulty(_:)), keyEquivalent: "3", tag: 3)
        gameMenu.addItem(withSubmenu: newGameWithDifficultyMenu)
        gameMenu.addItem(.separator())
        gameMenu.addItem(withTitle: "close".localized, action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        
        let windowsMenu = NSMenu(title: "window".localized)
        windowsMenu.addItem(withTitle: "minimize".localized, action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        
        let helpMenu = NSMenu(title: "help".localized)
        helpMenu.addItem(withTitle: "minesweeper-help".localized, action: #selector(NSApplication.showHelp(_:)), keyEquivalent: "?")
        
        let mainMenu = NSMenu(title: "Main Menu")
        mainMenu.addItem(withSubmenu: appMenu)
        mainMenu.addItem(withSubmenu: gameMenu)
        mainMenu.addItem(withSubmenu: windowsMenu)
        mainMenu.addItem(withSubmenu: helpMenu)
        
        NSApplication.shared.mainMenu = mainMenu
        
        NSApplication.shared.windowsMenu = windowsMenu
        NSApplication.shared.helpMenu = helpMenu
        
        let toolbar = NSToolbar(identifier: "Toolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        if #available(OSX 10.14, *) {
            toolbar.centeredItemIdentifier = .smiley
        }
        
        if #available(OSX 10.16, *) {
            window.toolbarStyle = .expanded
        }
        
        timerToolbarItem.paletteLabel = "timer".localized
        smileyToolbarItem.paletteLabel = "smiley".localized
        counterToolbarItem.paletteLabel = "counter".localized
        
        for (button, toolbarItem) in [
            (controller.timerButton, timerToolbarItem),
            (controller.smileyButton, smileyToolbarItem),
            (controller.counterButton, counterToolbarItem)
        ] {
            button.bezelStyle = .texturedRounded            
            toolbarItem.view = button
            toolbarItem.label = toolbarItem.paletteLabel
            if #available(OSX 10.16, *) {} else {
                toolbarItem.minSize = button.fittingSize
            }
        }
        
        window.toolbar = toolbar
        window.title = "minesweeper".localized
        window.tabbingMode = .disallowed
        window.collectionBehavior = .fullScreenNone
        window.backgroundColor = .windowBackgroundColor
        
        window.contentViewController = controller
        window.center()
        window.setFrameAutosaveName("Minesweeper")
    }

    func applicationDidFinishLaunching(_: Notification) {
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        window.isVisible
            ? window.delegate?.windowShouldClose?(window) ?? true ? .terminateNow : .terminateCancel
            : .terminateNow
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.smiley, .timer, .counter, .flexibleSpace, .space]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.timer, .flexibleSpace, .smiley, .flexibleSpace, .counter]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .timer:
            return timerToolbarItem
        case .smiley:
            return smileyToolbarItem
        case .counter:
            return counterToolbarItem
        default:
            return nil
        }
    }
}

extension NSToolbarItem.Identifier {
    static let timer: Self = Self(rawValue: "Timer")
    static let smiley: Self = Self(rawValue: "Smiley")
    static let counter: Self = Self(rawValue: "Counter")
}

extension NSMenu {
    func addItem(withTitle title: String, action: Selector?, keyEquivalent: String, tag: Int) {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        menuItem.tag = tag
        addItem(menuItem)
    }
    
    func addItem(withTitle title: String, action: Selector?, keyEquivalent: String, modifiers: NSEvent.ModifierFlags) {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        menuItem.keyEquivalentModifierMask = modifiers
        addItem(menuItem)
    }
    
    func addItem(withSubmenu submenu: NSMenu) {
        let menuItem = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        menuItem.submenu = submenu
        addItem(menuItem)
    }
}

extension String {
    var localized: String {NSLocalizedString(self, comment: "")}
}
