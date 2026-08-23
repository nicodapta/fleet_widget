import AppKit

/// The application menu.
///
/// A regular app owns the menu bar whenever it is active, so without this the
/// widget would present an empty bar and no ⌘Q. The panel's own `X` control
/// remains the primary way to quit; this exists so the standard shortcut and
/// the Dock icon's context menu behave the way every other app does.
///
/// Only the App menu is built. There are no documents, no editing surface and
/// no secondary windows, so File/Edit/Window entries would all be inert.
enum MainMenu {
    static func install(into application: NSApplication) {
        let appName = ProcessInfo.processInfo.processName

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About \(appName)",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())

        let hide = appMenu.addItem(withTitle: "Hide \(appName)",
                                   action: #selector(NSApplication.hide(_:)),
                                   keyEquivalent: "h")
        hide.target = application

        appMenu.addItem(.separator())

        let quit = appMenu.addItem(withTitle: "Quit \(appName)",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q")
        quit.target = application

        // The bar holds one item whose submenu is the App menu; AppKit takes the
        // first item as the application menu regardless of its title.
        let appItem = NSMenuItem()
        appItem.submenu = appMenu

        let bar = NSMenu()
        bar.addItem(appItem)
        application.mainMenu = bar
    }
}
