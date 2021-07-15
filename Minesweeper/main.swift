import AppKit

let NSApp = NSApplication.shared
let delegate = AppDelegate()
NSApp.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
