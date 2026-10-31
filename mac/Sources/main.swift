import AppKit

// 叮叮 Mac 版入口
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // 不在程序坞里显示图标，像桌宠一样待在桌面上
app.run()
