import AppKit
import Foundation

// ---------- 看看别的 AI 在聊什么 + 自己给自己升级（对应 Windows 版的 Upgrade.cs） ----------

/// 程序和资源在哪里（自我升级后，跑的是自己重新编译的那份程序，资源还在原来的 .app 里）
enum AppPaths {
    static var res = Bundle.main.resourcePath ?? ""
    static var bundleExe = Bundle.main.executablePath ?? ""
    static var upgraded = false
    static var lockFd: Int32 = -1

    static func Support() -> String { PathJoin(NSHomeDirectory(), "Library/Application Support") }

    /// 叮叮的文件夹：~/Library/Application Support/PixelDeskPet（config.txt 里的 data_folder 可以改名字）
    static func ResolveFolder() -> String {
        let example = PathJoin(res, "config.example.txt")
        let base = PathJoin(Support(), "PixelDeskPet")
        FileX.MkDir(base)
        Names.Load(base, example)
        if Names.DataFolder == "PixelDeskPet" { return base }
        let folder = PathJoin(Support(), Names.DataFolder)
        FileX.MkDir(folder)
        if !FileX.Exists(PathJoin(folder, "config.txt")) { FileX.Copy(PathJoin(base, "config.txt"), PathJoin(folder, "config.txt")) }
        Names.Load(folder, example)
        return folder
    }

    /// 这一版 .app 的“指纹”：装了新版本就不再用旧的自我升级
    static func BundleStamp() -> String {
        let a = try? FileManager.default.attributesOfItem(atPath: bundleExe)
        let d = a?[.modificationDate] as? Date
        return String(Int(d?.timeIntervalSince1970 ?? 0))
    }

    static func UpgradedExe(_ folder: String) -> String? {
        let exe = PathJoin(folder, "bin/DingDing")
        guard FileX.Exists(exe), FileManager.default.isExecutableFile(atPath: exe) else { return nil }
        let stamp = (FileX.Read(PathJoin(folder, "bin/base.txt")) ?? "").Trim
        return stamp == BundleStamp() ? exe : nil
    }

    /// 只让一个叮叮在跑
    static func SingleInstance(_ folder: String) -> Bool {
        lockFd = open(PathJoin(folder, ".running.lock"), O_CREAT | O_RDWR, 0o644)
        if lockFd < 0 { return true }
        return flock(lockFd, LOCK_EX | LOCK_NB) == 0
    }

    /// 运行一个程序，等它结束，拿到输出
    static func Run(_ exe: String, _ args: [String], timeout: Double = 600) -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = pipe
        p.standardInput = FileHandle.nullDevice
        var out = Data()
        let lock = NSLock()
        pipe.fileHandleForReading.readabilityHandler = { h in let d = h.availableData; lock.lock(); out.append(d); lock.unlock() }
        do { try p.run() } catch { return (-1, error.localizedDescription) }
        let deadline = Date().addingTimeInterval(timeout)
        while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
        if p.isRunning { p.terminate(); Thread.sleep(forTimeInterval: 0.3) }
        pipe.fileHandleForReading.readabilityHandler = nil
        let rest = pipe.fileHandleForReading.readDataToEndOfFile()
        lock.lock(); out.append(rest); let all = out; lock.unlock()
        return (p.isRunning ? -2 : p.terminationStatus, String(decoding: all, as: UTF8.self))
    }

    /// 有没有装 Xcode 命令行工具（没装的话 swiftc 用不了）
    static func HasSwiftc() -> Bool {
        let (st, out) = Run("/usr/bin/xcode-select", ["-p"], timeout: 10)
        return st == 0 && FileX.DirExists(out.Trim)
    }
}

extension PetForm {
    static let SWIFT_FLAGS = ["-swift-version", "5", "-framework", "AppKit", "-framework", "ApplicationServices", "-framework", "AVFoundation", "-framework", "IOKit"]

    // ===== 读 AI 窗口里的文字 =====
    func ReadAiWindow(_ want: String, _ maxChars: Int) -> String {
        if !AX.Trusted(prompt: false) {
            return "还没有打开「辅助功能」权限，看不到别的窗口。请 " + Names.Nick + " 在「系统设置 → 隐私与安全性 → 辅助功能」里打开 " + Names.Pet + "，或者截个图发给你。"
        }
        let wins = Detector.AiWindows()
        if wins.isEmpty { return "现在桌面上没有打开的 AI 窗口（支持 Claude、ChatGPT、DeepSeek、Kimi、豆包、WorkBuddy 等应用，以及浏览器里的 AI 网页）。" }
        var pick = wins[0]
        var found = false
        if want != "" {
            for w in wins where w.0.lowercased().contains(want.lowercased()) || want.lowercased().contains(w.0.lowercased()) { pick = w; found = true; break }
        }
        if !found {
            // 没指定就挑正在忙的，或者最近在用的那个
            for w in wins where busyApp.contains(w.0) { pick = w; found = true; break }
            if !found && lastBusyApp != "" { for w in wins where w.0 == lastBusyApp { pick = w; break } }
        }
        var lines: [String] = []
        var last = ""
        let skip: Set<String> = ["AXButton", "AXMenuItem", "AXMenuButton", "AXPopUpButton", "AXRadioButton", "AXCheckBox", "AXImage", "AXScrollBar", "AXTabGroup", "AXToolbar"]
        AX.Walk(pick.2, maxNodes: 6000, deadline: Date().timeIntervalSince1970 + 5) { e, role in
            if skip.contains(role) { return false }
            var t = ""
            if role == "AXStaticText" || role == "AXTextArea" || role == "AXTextField" || role == "AXHeading" {
                t = AX.Attr(e, kAXValueAttribute as String) as? String ?? ""
                if t == "" { t = AX.Name(e) }
            } else if role == "AXLink" { t = AX.Name(e) }
            t = t.Trim
            if t.count < 2 || t == last || last.contains(t) { return false }
            lines.append(t)
            last = t
            return false
        }
        var all = lines.joined(separator: "\n").Trim
        if all == "" { return "「" + pick.0 + "」窗口里读不到文字（有的应用不对外提供文字）。可以让 " + Names.Nick + " 截个图发给你。" }
        // 最新的对话一般在最下面，太长就保留后面的部分
        if all.count > maxChars { all = "……（前面省略）\n" + all.Sub(all.count - maxChars) }
        ChatNote("（" + Names.Pet + " 看了看「" + pick.0 + "」窗口）")
        return "「" + pick.0 + "」窗口（" + AX.Str(pick.2, kAXTitleAttribute as String) + "）里能看到的文字：\n" + all
    }

    // ===== 自我升级 =====
    func SrcDir() -> String { PathJoin(dir, "src") }
    func BundleSrc() -> String { PathJoin(AppPaths.res, "src") }
    func CanUpgrade() -> Bool { FileX.Exists(PathJoin(SrcDir(), "Pet.swift")) || FileX.Exists(PathJoin(BundleSrc(), "Pet.swift")) }

    func SrcFiles() -> [String] {
        let d = FileX.Exists(PathJoin(SrcDir(), "Pet.swift")) ? SrcDir() : BundleSrc()
        return FileX.Files(d, ".swift").map { ($0 as NSString).lastPathComponent }
    }

    /// 第一次改代码前，把 .app 里带的源代码复制一份出来；装了新版本就换成新版本的代码
    func EnsureSrc() {
        let stampFile = PathJoin(SrcDir(), "base.txt")
        let stamp = AppPaths.BundleStamp()
        if FileX.Exists(PathJoin(SrcDir(), "Pet.swift")) && (FileX.Read(stampFile) ?? "").Trim == stamp { return }
        if FileX.DirExists(SrcDir()) {
            let old = PathJoin(PathJoin(dir, "src_backups"), "旧版本_" + upgradeStamp)
            FileX.MkDir((old as NSString).deletingLastPathComponent)
            try? FileManager.default.moveItem(atPath: SrcDir(), toPath: old)
        }
        FileX.MkDir(SrcDir())
        for f in FileX.Files(BundleSrc(), ".swift") { FileX.Copy(f, PathJoin(SrcDir(), (f as NSString).lastPathComponent)) }
        FileX.Write(stampFile, stamp)
    }

    func SrcPath(_ f: String) -> String {
        let p = PathJoin(SrcDir(), f)
        if FileX.Exists(p) && (FileX.Read(PathJoin(SrcDir(), "base.txt")) ?? "").Trim == AppPaths.BundleStamp() { return p }
        return PathJoin(BundleSrc(), f)
    }

    func ReadMyCode(_ file: String, _ query: String, _ start: Int, _ count: Int) -> String {
        if !CanUpgrade() { return "这个版本没有带源代码，没法自我升级。" }
        let names = SrcFiles()
        if file == "" && query == "" {
            var s = "我的代码文件（Swift 5 + AppKit，改完会用 swiftc 重新编译）：\n"
            for f in names { s += f + "：\(FileX.Lines(SrcPath(f)).count) 行\n" }
            s += "Pet.swift=窗口/动作/物理；Draw.swift=绘制；Detect.swift=AI 工作识别；Features.swift=提醒/番茄钟/聊天窗/字体；Agent.swift=AI 接口/工具/造型/性格/AI 设置；Brain.swift=离线聊天；Sound.swift=音效/摇铃；Skin.swift=整体形象；Menu.swift=右键菜单；Upgrade.swift=读 AI 窗口/自我升级；Core.swift=通用小工具；App.swift、main.swift=启动。\n"
            s += "用 query 搜关键词，或者 file + start + count 看某一段。\n"
            return s
        }
        let files = file != "" ? [(file as NSString).lastPathComponent] : names
        var sb = ""
        for f in files {
            let p = SrcPath(f)
            if !FileX.Exists(p) { sb += "没有文件 " + f + "\n"; continue }
            let lines = FileX.Lines(p)
            if query == "" {
                let a = max(1, start), b = min(lines.count, a + max(1, min(200, count <= 0 ? 120 : count)) - 1)
                sb += "== " + f + " 第 \(a)–\(b) 行（共 \(lines.count) 行）\n"
                if a <= b { for i in a...b { sb += "\(i): " + lines[i - 1] + "\n" } }
            } else {
                var hits = 0
                for i in 0..<lines.count where hits < 40 {
                    if !lines[i].lowercased().contains(query.lowercased()) { continue }
                    hits += 1
                    sb += "== " + f + " 第 \(i + 1) 行附近\n"
                    for j in max(0, i - 3)...min(lines.count - 1, i + 3) { sb += "\(j + 1): " + lines[j] + "\n" }
                }
            }
        }
        if sb.Trim == "" { return "没搜到“" + query + "”。" }
        return sb.count > 14000 ? sb.Sub(0, 14000) + "\n……（太长了，缩小范围再看）" : sb
    }

    func EditMyCode(_ file0: String, _ find: String, _ replace: String, _ why: String, _ isErr: inout Bool) -> String {
        isErr = true
        if !CanUpgrade() { return "这个版本没有带源代码，没法自我升级。" }
        if !AppPaths.HasSwiftc() { return "这台 Mac 还没装 Xcode 命令行工具，改了代码也编译不了。请 " + Names.Nick + " 打开「终端」运行 xcode-select --install 装好后再试。" }
        let file = (file0 as NSString).lastPathComponent
        let names = SrcFiles()
        if !names.contains(file) { return "只能改这些文件：" + names.joined(separator: "、") }
        if find == "" { return "find 不能是空的" }
        // 安全底线：确认窗口相关的代码不能自己改
        for guardWord in ["ConfirmCommandWindow", "ConfirmCodeWindow", "RunShell(", "EditMyCode(", "SWIFT_FLAGS"] where find.contains(guardWord) || replace.contains(guardWord) {
            return "涉及运行命令或改代码前的确认窗口，这部分不能自己改。"
        }
        let tn = (FileX.Read(SrcPath(file)) ?? "").Replace("\r\n", "\n")
        let fn = find.Replace("\r\n", "\n"), rn = replace.Replace("\r\n", "\n")
        guard let r1 = tn.range(of: fn) else { return "在 " + file + " 里找不到要替换的原文（要和代码一字不差，包括空格缩进）。先用 read_my_code 看准再改。" }
        if tn.range(of: fn, range: tn.index(after: r1.lowerBound)..<tn.endIndex) != nil { return "原文在 " + file + " 里出现了不止一次，多带几行上下文让它唯一。" }
        let newText = tn.replacingCharacters(in: r1, with: rn)
        // 先给 m 看
        let ok: Bool = OnMainSync { Dialogs.ConfirmCodeWindow(file, why, find, replace) }
        if !ok { ChatNote("（" + Names.Nick + " 没有同意这次改动）"); return Names.Nick + " 没有同意这次改动。问问 TA 想怎么改。" }
        EnsureSrc()
        // 编译检查：换上新内容，编译通过才写入
        ChatNote("（正在检查改完的代码能不能编译，要等一小会儿…）")
        let errs = CompileCheck(file, newText)
        if errs != "" { return "编译没通过，没有保存，原来的代码没动：\n" + errs + "\n照着报错改一改再试。" }
        let bdir = PathJoin(PathJoin(dir, "src_backups"), upgradeStamp)
        FileX.MkDir(bdir)
        let bpath = PathJoin(bdir, file)
        if !FileX.Exists(bpath) { FileX.Copy(PathJoin(SrcDir(), file), bpath) }   // 这一轮升级里第一次改这个文件时才备份
        if !FileX.Write(PathJoin(SrcDir(), file), newText) { return "保存失败了" }
        upgradePending = true
        isErr = false
        LogEvent("自我升级：改了 " + file + "（" + why + "）")
        ChatNote("（" + Names.Pet + " 改好了 " + file + "，编译通过）")
        return "改好了，编译通过，旧版本已备份。改动要重启后才生效：所有要改的都改完后，调用 restart_self。"
    }

    /// 只做类型检查（比完整编译快），返回报错；空字符串表示通过
    func CompileCheck(_ changed: String, _ text: String) -> String {
        let tmp = PathJoin(NSTemporaryDirectory(), "dingding_check_" + ShortId())
        FileX.MkDir(tmp)
        defer { FileX.Delete(tmp) }
        var paths: [String] = []
        for f in SrcFiles() {
            let p = PathJoin(tmp, f)
            FileX.Write(p, f == changed ? text : (FileX.Read(PathJoin(SrcDir(), f)) ?? ""))
            paths.append(p)
        }
        let (st, out) = AppPaths.Run("/usr/bin/xcrun", ["swiftc", "-typecheck"] + PetForm.SWIFT_FLAGS + paths, timeout: 300)
        if st == 0 { return "" }
        var errs: [String] = []
        for l in out.components(separatedBy: "\n") where l.contains(": error:") {
            if let m = RxMatch(l, "([^/]+\\.swift):(\\d+):\\d+: error: (.*)$") { errs.append(m[1] + " 第 " + m[2] + " 行：" + m[3]) } else { errs.append(l) }
            if errs.count >= 8 { errs.append("……还有更多错误"); break }
        }
        if errs.isEmpty { return "编译检查没通过：" + (out.count > 600 ? out.Sub(0, 600) : out) }
        return errs.joined(separator: "\n")
    }

    /// 重新编译自己，编好了就换成新的自己
    func RestartSelf() {
        Say("正在重新编译自己，要一两分钟……", 120)
        LogEvent("自我升级后重启")
        let folder = dir
        Background { [self] in
            let bin = PathJoin(folder, "bin")
            // 代码和 .app 里带的一模一样（比如全部撤销了）：直接回到原版
            var same = true
            for f in SrcFiles() where FileX.Read(PathJoin(SrcDir(), f)) != FileX.Read(PathJoin(BundleSrc(), f)) { same = false; break }
            var exe = AppPaths.bundleExe
            if same {
                FileX.Delete(bin)
            } else {
                FileX.MkDir(bin)
                let out = PathJoin(bin, "DingDing.new")
                let srcs = FileX.Files(SrcDir(), ".swift")
                let (st, log) = AppPaths.Run("/usr/bin/xcrun", ["swiftc", "-O", "-o", out] + PetForm.SWIFT_FLAGS + srcs, timeout: 900)
                if st != 0 {
                    let first = log.components(separatedBy: "\n").first { $0.contains("error:") } ?? log
                    OnMain { self.Say("编译失败了，还是用现在的我：" + (first.count > 60 ? first.Sub(0, 60) + "…" : first), 10) }
                    return
                }
                _ = AppPaths.Run("/usr/bin/codesign", ["--force", "-s", "-", out], timeout: 60)
                let final = PathJoin(bin, "DingDing")
                FileX.Delete(final)
                try? FileManager.default.moveItem(atPath: out, toPath: final)
                FileX.Write(PathJoin(bin, "base.txt"), AppPaths.BundleStamp())
                exe = final
            }
            OnMain {
                self.SaveState(); self.SaveDiary()
                let p = Process()
                p.executableURL = URL(fileURLWithPath: exe)
                p.arguments = (exe == AppPaths.bundleExe ? [] : ["--res", AppPaths.res, "--bundle", AppPaths.bundleExe]) + ["--wait-pid", String(ProcessInfo.processInfo.processIdentifier)]
                do { try p.run() } catch { self.Say("重启失败了：" + error.localizedDescription, 6); return }
                NSApp.terminate(nil)
            }
        }
    }

    // 右键菜单：撤销最近一次升级
    func UndoUpgrade() {
        let root = PathJoin(dir, "src_backups")
        let ds = ((try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []).filter { !$0.hasSuffix("_已撤销") && !$0.hasPrefix("旧版本_") && !$0.hasPrefix(".") }.sorted()
        guard let last = ds.last else { Say("还没有升级过，没有可以撤销的～", 4); return }
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = Names.Pet
        a.informativeText = "把代码恢复到 " + last + " 这次升级之前的样子，然后重新编译、重启？"
        a.addButton(withTitle: "好"); a.addButton(withTitle: "取消")
        if a.runModal() != .alertFirstButtonReturn { return }
        EnsureSrc()
        let bdir = PathJoin(root, last)
        for f in FileX.Files(bdir, ".swift") {
            let to = PathJoin(SrcDir(), (f as NSString).lastPathComponent)
            FileX.Delete(to); FileX.Copy(f, to)
        }
        try? FileManager.default.moveItem(atPath: bdir, toPath: bdir + "_已撤销")
        LogEvent("撤销了自我升级 " + last)
        RestartSelf()
    }
}
