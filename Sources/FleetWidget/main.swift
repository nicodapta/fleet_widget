import AppKit

// Offscreen render for visual checks during development. Draws one frame of a
// synthetic fleet to a PNG and exits, without opening a window.
if CommandLine.arguments.contains("--render-preview") {
    let index = CommandLine.arguments.firstIndex(of: "--render-preview")!
    let path = CommandLine.arguments.indices.contains(index + 1)
        ? CommandLine.arguments[index + 1]
        : "fleet-preview.png"
    PreviewRenderer.write(to: path)
    exit(0)
}

if let index = CommandLine.arguments.firstIndex(of: "--render-iconset") {
    let directory = CommandLine.arguments.indices.contains(index + 1)
        ? CommandLine.arguments[index + 1]
        : "AppIcon.iconset"
    exit(IconRenderer.writeIconset(to: directory))
}

if CommandLine.arguments.contains("--self-test-interaction") {
    exit(InteractionSelfTest.run())
}

let application = NSApplication.shared
// Accessory: no Dock icon, no app-switcher entry. Set in code as well as via
// LSUIElement so `swift run` behaves the same as the bundled .app.
application.setActivationPolicy(.accessory)

let delegate = AppDelegate()
application.delegate = delegate
application.run()
