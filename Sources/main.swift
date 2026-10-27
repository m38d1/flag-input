import Cocoa
import Carbon
import ServiceManagement

private let flagBySourceID: [String: String] = [
    "com.apple.keylayout.US": "🇺🇸",
    "com.apple.keylayout.USExtended": "🇺🇸",
    "com.apple.keylayout.USInternational-PC": "🇺🇸",
    "com.apple.keylayout.British": "🇬🇧",
    "com.apple.keylayout.British-PC": "🇬🇧",
    "com.apple.keylayout.Persian": "🇮🇷",
    "com.apple.keylayout.Persian-ISIRI": "🇮🇷",
    "com.apple.keylayout.Persian-ISIRI2901": "🇮🇷",
    "com.apple.keylayout.Persian-QWERTY": "🇮🇷",
    "com.apple.keylayout.Arabic": "🇸🇦",
    "com.apple.keylayout.Arabic-QWERTY": "🇸🇦",
    "com.apple.keylayout.Hebrew": "🇮🇱",
    "com.apple.keylayout.French": "🇫🇷",
    "com.apple.keylayout.German": "🇩🇪",
    "com.apple.keylayout.Spanish": "🇪🇸",
    "com.apple.keylayout.Italian": "🇮🇹",
    "com.apple.keylayout.Dutch": "🇳🇱",
    "com.apple.keylayout.Portuguese": "🇵🇹",
    "com.apple.keylayout.Russian": "🇷🇺",
    "com.apple.keylayout.Ukrainian": "🇺🇦",
    "com.apple.keylayout.Greek": "🇬🇷",
    "com.apple.keylayout.Turkish": "🇹🇷",
    "com.apple.keylayout.Polish": "🇵🇱",
    "com.apple.keylayout.Czech": "🇨🇿",
    "com.apple.keylayout.Hungarian": "🇭🇺",
    "com.apple.keylayout.Romanian": "🇷🇴",
    "com.apple.keylayout.Swedish": "🇸🇪",
    "com.apple.keylayout.Norwegian": "🇳🇴",
    "com.apple.keylayout.Danish": "🇩🇰",
    "com.apple.keylayout.Finnish": "🇫🇮",
    "com.apple.keylayout.Thai": "🇹🇭",
    "com.apple.keylayout.Vietnamese": "🇻🇳",
    "com.apple.keylayout.Korean": "🇰🇷",
    "com.apple.keylayout.Japanese": "🇯🇵",
    "com.apple.keylayout.Chinese": "🇨🇳"
]

private func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
}

private func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return false }
    return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
}

private func flag(for sourceID: String, name: String) -> String {
    if let flag = flagBySourceID[sourceID] { return flag }
    let haystack = (sourceID + " " + name).lowercased()
    if haystack.contains("persian") || haystack.contains("isiri") { return "🇮🇷" }
    if haystack.contains("arabic") { return "🇸🇦" }
    if haystack.contains("british") || haystack.contains("uk") { return "🇬🇧" }
    if haystack.contains("english") || haystack.contains("u.s.") || haystack.contains("us-") { return "🇺🇸" }
    return "🌐"
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var lastSourceID = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "FlagInput"
        statusItem.button?.font = NSFont.systemFont(ofSize: 15)
        statusItem.button?.toolTip = "Input language"
        statusItem.menu = menu
        menu.delegate = self

        refreshStatusItem()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceDidChange),
            name: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil
        )
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshStatusItem()
        }
    }

    private func currentSource() -> TISInputSource? {
        guard let source = TISCopyCurrentKeyboardInputSource() else { return nil }
        return source.takeRetainedValue()
    }

    private func currentSourceID() -> String {
        guard let source = currentSource(), let id = stringProperty(source, kTISPropertyInputSourceID) else {
            return ""
        }
        return id
    }

    private func refreshStatusItem() {
        let selected = currentSource()
        let id = selected.flatMap { stringProperty($0, kTISPropertyInputSourceID) } ?? ""
        let name = selected.flatMap { stringProperty($0, kTISPropertyLocalizedName) } ?? ""
        let symbol = id.isEmpty ? "🌐" : flag(for: id, name: name)
        statusItem.button?.title = symbol
        statusItem.button?.toolTip = name.isEmpty ? "Input language" : name
        lastSourceID = id
    }

    @objc private func inputSourceDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshStatusItem()
        }
    }

    private func keyboardSources() -> [TISInputSource] {
        guard let created = TISCreateInputSourceList(nil, false) else { return [] }
        let list = created.takeRetainedValue() as NSArray
        var sources: [TISInputSource] = []
        for case let source as TISInputSource in list {
            guard let category = stringProperty(source, kTISPropertyInputSourceCategory),
                  category == (kTISCategoryKeyboardInputSource as String),
                  boolProperty(source, kTISPropertyInputSourceIsEnabled),
                  boolProperty(source, kTISPropertyInputSourceIsSelectCapable) else { continue }
            sources.append(source)
        }
        return sources
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let selectedID = currentSourceID()

        for source in keyboardSources() {
            let id = stringProperty(source, kTISPropertyInputSourceID) ?? ""
            let name = stringProperty(source, kTISPropertyLocalizedName) ?? id
            let item = NSMenuItem(
                title: "\(flag(for: id, name: name))  \(name)",
                action: #selector(selectInputSource(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = id
            item.state = (id == selectedID) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        if #available(macOS 13.0, *) {
            loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        }
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func selectInputSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let source = keyboardSources().first(where: { stringProperty($0, kTISPropertyInputSourceID) == id }) else {
            return
        }
        TISSelectInputSource(source)
        refreshStatusItem()
    }

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("FlagInput: launch-at-login failed: \(error.localizedDescription)")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
