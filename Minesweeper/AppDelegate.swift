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
            if #available(OSX 10.14, *) {} else {
                toolbarItem.minSize = button.fittingSize
            }
        }
        
        window.toolbar = toolbar
        window.title = "minesweeper".localized
        window.tabbingMode = .disallowed
        window.collectionBehavior = .fullScreenNone
        
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

extension NSImage {
    var cgImage: CGImage? {
        var frame = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &frame, context: nil, hints: nil)
    }
}

extension NSRect {
    func insetBy(_ edgeInset: NSEdgeInsets) -> NSRect {
        return NSRect(
            x: minX + edgeInset.left,
            y: minY + edgeInset.bottom,
            width: width - edgeInset.left - edgeInset.right,
            height: height - edgeInset.bottom - edgeInset.top
        )
    }
}

extension NSColor {
    static let accentRed: NSColor = NSColor(red: 0.9, green: 0.19, blue: 0.24, alpha: 1)
    static let accentOrange: NSColor = NSColor(red: 0.95, green: 0.42, blue: 0.1, alpha: 1)
    static let accentYellow: NSColor = NSColor(red: 1, green: 0.68, blue: 0, alpha: 1)
    static let accentGreen: NSColor = NSColor(red: 0.33, green: 0.78, blue: 0.13, alpha: 1)
    static let accentBlue: NSColor = NSColor(red: 0, green: 0.5, blue: 1, alpha: 1)
    static let accentVoilet: NSColor = NSColor(red: 0.3, green: 0.2, blue: 1, alpha: 1)
    static let accentPurple: NSColor = NSColor(red: 0.69, green: 0.2, blue: 0.72, alpha: 1)
    static let accentPink: NSColor = NSColor(red: 0.93, green: 0.2, blue: 0.55, alpha: 1)
    static let accentGraphite: NSColor = NSColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1)
    static let accentGold: NSColor = NSColor(red: 0.67, green: 0.53, blue: 0.33, alpha: 1)
    static let accentCyan: NSColor = NSColor(red: 0, green: 0.87, blue: 0.8, alpha: 1)
    
    static let accentBlood: NSColor = NSColor(red: 0.7, green: 0.15, blue: 0.15, alpha: 1)
    static let accentCopper: NSColor = NSColor(red: 0.9, green: 0.28, blue: 0.1, alpha: 1)
    static let accentConifer: NSColor = NSColor(red: 0.1, green: 0.54, blue: 0.63, alpha: 1)
    static let accentOcean: NSColor = NSColor(red: 0.1, green: 0.43, blue: 0.67, alpha: 1)
    static let accentIndigo: NSColor = NSColor(red: 0.39, green: 0.38, blue: 0.66, alpha: 1)
}
