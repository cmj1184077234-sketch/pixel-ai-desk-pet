import AppKit

// 叮叮 Mac 版入口
let cliArgs = CommandLine.arguments
func Arg(_ k: String) -> String? {
    if let i = cliArgs.firstIndex(of: k), i + 1 < cliArgs.count { return cliArgs[i + 1] }
    return nil
}
if let r = Arg("--res") { AppPaths.res = r; AppPaths.upgraded = true }
if let b = Arg("--bundle") { AppPaths.bundleExe = b }
// 自我升级后重启：等旧的自己退出
if let w = Arg("--wait-pid"), let pid = Int32(w) {
    var n = 0
    while kill(pid, 0) == 0 && n < 100 { usleep(200_000); n += 1 }
}

let appFolder = AppPaths.ResolveFolder()

// 有自己升级过的版本，就换成那一份来跑
if !AppPaths.upgraded, let exe = AppPaths.UpgradedExe(appFolder) {
    var cargs: [UnsafeMutablePointer<CChar>?] = [strdup(exe), strdup("--res"), strdup(AppPaths.res), strdup("--bundle"), strdup(AppPaths.bundleExe), nil]
    execv(exe, &cargs)   // 成功的话不会回到这里
}

if !AppPaths.SingleInstance(appFolder) { exit(0) }   // 已经有一个叮叮在桌面上了

let app = NSApplication.shared
let appDelegate = AppDelegate(folder: appFolder)
app.delegate = appDelegate
app.setActivationPolicy(.accessory)   // 不在程序坞里显示图标，像桌宠一样待在桌面上
app.run()
