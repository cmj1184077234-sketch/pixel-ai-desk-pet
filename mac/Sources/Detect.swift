import AppKit
import ApplicationServices
import IOKit.pwr_mgt
import Darwin

// ---------- 屏幕上的窗口（用来跳到窗口顶上、判断前台是谁） ----------
struct WinInfo {
    var id: UInt32
    var pid: Int32
    var owner: String
    var rect: RectI      // 左上角为原点，往下为正（和 Windows 一样）
    var layer: Int
    var minimized: Bool
}

enum WinList {
    static func Parse(_ d: [String: Any]) -> WinInfo? {
        guard let id = d[kCGWindowNumber as String] as? UInt32,
              let pid = d[kCGWindowOwnerPID as String] as? Int32,
              let b = d[kCGWindowBounds as String] as? [String: Any] else { return nil }
        var r = CGRect.zero
        if !CGRectMakeWithDictionaryRepresentation(b as CFDictionary, &r) { return nil }
        let owner = d[kCGWindowOwnerName as String] as? String ?? ""
        let layer = d[kCGWindowLayer as String] as? Int ?? 0
        let onScreen = d[kCGWindowIsOnscreen as String] as? Bool ?? true
        return WinInfo(id: id, pid: pid, owner: owner, rect: RectI(Left: Double(r.minX), Top: Double(r.minY), Right: Double(r.maxX), Bottom: Double(r.maxY)), layer: layer, minimized: !onScreen)
    }
    /// 屏幕上能看到的窗口，从前往后
    static func OnScreen() -> [WinInfo] {
        guard let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return l.compactMap(Parse)
    }
    static var cache: [UInt32: (Double, WinInfo?)] = [:]
    static func ById(_ id: UInt32) -> WinInfo? {
        let t = Date().timeIntervalSince1970
        if let c = cache[id], t - c.0 < 0.15 { return c.1 }
        var w: WinInfo? = nil
        if let l = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(id)) as? [[String: Any]], let d = l.first { w = Parse(d) }
        cache[id] = (t, w)
        if cache.count > 50 { cache.removeAll() }
        return w
    }
    /// 前台程序最前面的那个普通窗口
    static func FrontWindow() -> WinInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let me = ProcessInfo.processInfo.processIdentifier
        if app.processIdentifier == me { return nil }
        return OnScreen().first { $0.pid == app.processIdentifier && $0.layer == 0 && $0.rect.Width > 80 && $0.rect.Height > 60 }
    }
    static func At(_ x: Double, _ y: Double) -> WinInfo? {
        let me = ProcessInfo.processInfo.processIdentifier
        return OnScreen().first { $0.pid != me && $0.layer == 0 && $0.rect.Contains(x, y) }
    }
}

// ---------- 读别的程序窗口里的按钮和文字（macOS 的“辅助功能”） ----------
enum AX {
    static func Attr(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
    }
    static func Str(_ e: AXUIElement, _ name: String) -> String { Attr(e, name) as? String ?? "" }
    static func Children(_ e: AXUIElement) -> [AXUIElement] { Attr(e, kAXChildrenAttribute as String) as? [AXUIElement] ?? [] }
    static func Windows(_ app: AXUIElement) -> [AXUIElement] { Attr(app, kAXWindowsAttribute as String) as? [AXUIElement] ?? [] }
    static func Frame(_ e: AXUIElement) -> RectI? {
        guard let pv = Attr(e, kAXPositionAttribute as String), let sv = Attr(e, kAXSizeAttribute as String) else { return nil }
        var p = CGPoint.zero, s = CGSize.zero
        guard CFGetTypeID(pv) == AXValueGetTypeID(), CFGetTypeID(sv) == AXValueGetTypeID() else { return nil }
        AXValueGetValue(pv as! AXValue, .cgPoint, &p); AXValueGetValue(sv as! AXValue, .cgSize, &s)
        return RectI(Left: Double(p.x), Top: Double(p.y), Right: Double(p.x + s.width), Bottom: Double(p.y + s.height))
    }
    static func Trusted(prompt: Bool) -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }
    /// Electron（Claude 桌面版等）和 Chrome 默认不把网页里的按钮告诉辅助功能，要先打开
    static var woken = Set<Int32>()
    static func Wake(_ pid: Int32, _ app: AXUIElement, browser: Bool) {
        if woken.contains(pid) { return }
        woken.insert(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        if browser { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) }
    }
    /// 按钮的名字：标题、描述、提示都看
    static func Name(_ e: AXUIElement) -> String {
        let t = Str(e, kAXTitleAttribute as String)
        if t != "" { return t }
        let d = Str(e, kAXDescriptionAttribute as String)
        if d != "" { return d }
        return Str(e, kAXHelpAttribute as String)
    }
    /// 一层层往下找，visit 返回 true 就停
    static func Walk(_ root: AXUIElement, maxNodes: Int = 6000, deadline: Double, _ visit: (AXUIElement, String) -> Bool) {
        var stack: [(AXUIElement, Int)] = [(root, 0)]
        var n = 0
        while let (e, depth) = stack.popLast() {
            n += 1
            if n > maxNodes || Date().timeIntervalSince1970 > deadline { return }
            let role = Str(e, kAXRoleAttribute as String)
            if visit(e, role) { return }
            if depth < 70 { for c in Children(e).reversed() { stack.append((c, depth + 1)) } }
        }
    }
}

enum Detector {
    // Mac 上 AI 应用的名字 → 显示的名字
    static let AI_APPS: [(String, String)] = [
        ("claude", "Claude"), ("chatgpt", "ChatGPT"), ("codex", "Codex"), ("cursor", "Cursor"), ("windsurf", "Windsurf"), ("trae", "Trae"),
        ("doubao", "豆包"), ("豆包", "豆包"), ("kimi", "Kimi"), ("deepseek", "DeepSeek"), ("copilot", "Copilot"), ("yuanbao", "元宝"), ("元宝", "元宝"),
        ("qwen", "通义"), ("通义", "通义"), ("tongyi", "通义"), ("codebuddy", "CodeBuddy"), ("workbuddy", "WorkBuddy"),
        ("visual studio code", "VS Code"), ("code", "VS Code"), ("jimeng", "即梦"), ("即梦", "即梦"), ("lingma", "通义灵码"), ("perplexity", "Perplexity")]
    static let BROWSERS = ["google chrome", "chrome", "safari", "microsoft edge", "firefox", "arc", "brave browser", "opera", "vivaldi", "quark", "夸克", "orion", "dia", "comet", "360浏览器", "qq浏览器", "chromium"]
    static let AI_SITES: [(String, String)] = [
        ("claude", "Claude"), ("chatgpt", "ChatGPT"), ("gemini", "Gemini"),
        ("deepseek", "DeepSeek"), ("豆包", "豆包"), ("kimi", "Kimi"),
        ("copilot", "Copilot"), ("通义", "通义"), ("千问", "通义千问"),
        ("文心", "文心一言"), ("元宝", "元宝"), ("perplexity", "Perplexity"),
        ("grok", "Grok"), ("智谱", "智谱清言"), ("chatglm", "智谱清言"),
        ("poe", "Poe"), ("秘塔", "秘塔"), ("纳米ai", "纳米AI"), ("即梦", "即梦"),
        ("mistral", "Mistral"), ("minimax", "MiniMax"), ("海螺", "海螺AI")]
    // 只有这几个没有“停止”按钮的智能体才看 CPU
    static let CPU_APPS = ["workbuddy", "codebuddy"]

    static func IsBrowser(_ name: String) -> Bool { BROWSERS.contains(name.lowercased()) }

    static func AppLabel(_ name: String) -> String? {
        let n = name.lowercased()
        for a in AI_APPS where a.0 == n { return a.1 }
        return nil
    }

    static func AiLabel(_ pname: String, _ title: String) -> String? {
        if let l = AppLabel(pname) { return l }
        if IsBrowser(pname) {
            let t = title.lowercased()
            for a in AI_SITES where t.contains(a.0) { return a.1 }
        }
        return nil
    }

    static func IsStopName(_ name: String) -> Bool {
        if name.isEmpty { return false }
        let l = name.lowercased()
        if l.contains("debug") || name.contains("调试") || l.contains("loading") || name.contains("加载") ||
            l.contains("record") || name.contains("录制") || name.contains("录音") || l.contains("dictation") || name.contains("听写") ||
            l.contains("stopwatch") || l.contains("stop sharing") { return false }
        return l.contains("stop") || l.contains("interrupt") || l.contains("cancel generat") || l.contains("cancel response") || name.contains("停止") || name.contains("中断") ||
            name.contains("中止") || name.contains("取消生成") || name.contains("暂停生成")
    }

    static let lock = NSLock()
    static var ignoreButtons: [String] = []
    static var stopRects: [String: RectI] = [:]
    static var stopName = ""
    static var busyNow: [String] = []
    static var cpuDetected = Set<String>()
    static var detectFrozen = false   // 只给测试用
    static func Ignored(_ app: String, _ name: String) -> Bool { lock.lock(); defer { lock.unlock() }; return ignoreButtons.contains(app + "|" + name) }
    static func stopRectsCopy() -> [String: RectI] { lock.lock(); defer { lock.unlock() }; return stopRects }

    /// 能看到的 AI 窗口：(显示的名字, 程序, 窗口)
    static func AiWindows() -> [(String, NSRunningApplication, AXUIElement)] {
        var list: [(String, NSRunningApplication, AXUIElement)] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let name = app.localizedName ?? ""
            let exe = (app.executableURL?.lastPathComponent ?? "")
            let direct = AppLabel(name) ?? AppLabel(exe)
            let browser = IsBrowser(name) || IsBrowser(exe)
            if direct == nil && !browser { continue }
            let ax = AXUIElementCreateApplication(app.processIdentifier)
            AX.Wake(app.processIdentifier, ax, browser: browser)
            for w in AX.Windows(ax) {
                let title = AX.Str(w, kAXTitleAttribute as String)
                if let label = direct ?? AiLabel(browser ? "chrome" : name, title) { list.append((label, app, w)) }
            }
        }
        return list
    }

    /// 哪些 AI 窗口里有“停止”按钮
    static func Detect() -> [String] {
        var found: [String] = []
        let deadline = Date().timeIntervalSince1970 + 2.5
        for (label, _, w) in AiWindows() {
            if found.contains(label) { continue }
            AX.Walk(w, deadline: deadline) { e, role in
                if role != (kAXButtonRole as String) { return false }
                let name = AX.Name(e)
                if IsStopName(name) && !Ignored(label, name) {
                    lock.lock()
                    stopName = name
                    if let r = AX.Frame(e) { stopRects[label] = RectI(Left: r.Left - 8, Top: r.Top - 8, Right: r.Right + 8, Bottom: r.Bottom + 8) }
                    lock.unlock()
                    found.append(label)
                    return true
                }
                return false
            }
        }
        return found
    }

    // ---------- 没有“停止”按钮的 AI（比如 WorkBuddy 这类智能体）：看它是不是在持续占用 CPU ----------
    static var cpuLast: [String: Double] = [:]
    static var cpuHist: [String: [Bool]] = [:]
    static var cpuOn = Set<String>()
    static var cpuLastAt: Double = 0
    static var timebase: Double = {
        var tb = mach_timebase_info_data_t(); mach_timebase_info(&tb)
        return Double(tb.numer) / Double(tb.denom)
    }()

    /// 某个程序（包括它的辅助进程）一共用了多少 CPU 秒
    static func CpuSeconds(_ prefix: String) -> Double? {
        let n = proc_listallpids(nil, 0)
        if n <= 0 { return nil }
        var pids = [Int32](repeating: 0, count: Int(n) + 32)
        let got = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        var total = 0.0; var any = false
        for i in 0..<Int(max(0, got)) {
            let pid = pids[i]
            var buf = [CChar](repeating: 0, count: 256)
            proc_name(pid, &buf, 256)
            let name = String(cString: buf).lowercased()
            if !name.hasPrefix(prefix) { continue }
            var ri = rusage_info_current()
            let ok = withUnsafeMutablePointer(to: &ri) { p in p.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0) } }
            if ok == 0 { total += Double(ri.ri_user_time + ri.ri_system_time) * timebase / 1e9; any = true }
        }
        return any ? total : nil
    }

    static func CpuBusyApps() -> [String] {
        var busy: [String] = []
        let t = Date().timeIntervalSince1970
        let dt = cpuLastAt == 0 ? 0 : t - cpuLastAt
        cpuLastAt = t
        // 前台是哪个程序：用户正在操作它时（刚有键盘鼠标输入），它忙不算 AI 在工作
        let fg = (NSWorkspace.shared.frontmostApplication?.localizedName ?? "").lowercased()
        let userTyping = Idle.Seconds() < 3
        for a in AI_APPS where CPU_APPS.contains(a.0) {
            let name = a.0
            guard let total = CpuSeconds(name) else { cpuLast.removeValue(forKey: name); cpuHist.removeValue(forKey: name); cpuOn.remove(name); continue }
            var active = false
            if let prev = cpuLast[name], dt > 0.5 {
                let load = (total - prev) / dt      // 相当于占用了几个核
                active = load > 0.25 && !(userTyping && fg.hasPrefix(name))
            }
            cpuLast[name] = total
            var h = cpuHist[name] ?? []
            h.append(active); if h.count > 12 { h.removeFirst() }
            cpuHist[name] = h
            let n = h.filter { $0 }.count
            let recent = h.suffix(8).filter { $0 }.count
            // 开始：最近约 18 秒里至少 10 次都在忙（持续在跑，不是偶尔动一下）；结束：最近约 12 秒里最多 1 次在忙
            if !cpuOn.contains(name) && h.count >= 12 && n >= 10 { cpuOn.insert(name) }
            else if cpuOn.contains(name) && h.count >= 8 && recent <= 1 { cpuOn.remove(name) }
            if cpuOn.contains(name) && !Ignored(a.1, "CPU") { busy.append(a.1) }
        }
        return busy
    }
}

extension PetForm {
    func LoadIgnore() {
        let f = PathJoin(cfgDir, "ignore_buttons.txt")
        Detector.lock.lock(); Detector.ignoreButtons += FileX.Lines(f); Detector.lock.unlock()
    }

    // m 说“它其实没在工作”：把现在认错的那个按钮记下来，以后不再当成“停止”
    func IgnoreCurrentButton() {
        let app = busyApp
        Detector.lock.lock(); var name = Detector.stopName; let viaCpu = Detector.cpuDetected.contains(app); Detector.lock.unlock()
        if app != "" && !app.contains("、") && viaCpu { name = "CPU" }
        if app == "" || name == "" { Say("现在没有在等的 AI 呀～", 3); return }
        Detector.lock.lock(); Detector.ignoreButtons.append(app + "|" + name); Detector.lock.unlock()
        FileX.Append(PathJoin(cfgDir, "ignore_buttons.txt"), app + "|" + name + "\n")
        LogEvent(Names.Nick + " 说 " + app + " 没在工作 → 以后忽略按钮「" + name + "」")
        busyApp = ""; detectedBusy = false; appActive.removeAll(); Detector.lock.lock(); Detector.busyNow.removeAll(); Detector.lock.unlock(); manualWork = false
        Set("shy")
        Say(name == "CPU" ? "对不起，我认错啦！以后不再靠「" + app + "」忙不忙来判断它在不在工作了。" : "对不起，我认错啦！以后不会再把「" + name + "」当成停止按钮了。", 5)
    }

    // m 现在是不是正看着这个 AI 的窗口（它在最前面，而且 m 刚刚还在动鼠标键盘）
    func WatchingApp(_ app: String) -> Bool {
        if Idle.Seconds() > 20 { return false }
        guard let fa = NSWorkspace.shared.frontmostApplication else { return false }
        let name = fa.localizedName ?? ""
        if let l = Detector.AppLabel(name) { return l == app }
        if Detector.IsBrowser(name) {
            let ax = AXUIElementCreateApplication(fa.processIdentifier)
            if let w = AX.Attr(ax, kAXFocusedWindowAttribute as String) {
                let title = AX.Str(w as! AXUIElement, kAXTitleAttribute as String)
                return Detector.AiLabel("chrome", title) == app
            }
        }
        return false
    }

    // 有任何 AI 在工作时不让电脑息屏
    func KeepAwake(_ on: Bool) {
        if on == keepingAwake { return }
        keepingAwake = on
        if on {
            var id: IOPMAssertionID = 0
            if IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "AI 正在工作，叮叮先不让屏幕睡着" as CFString, &id) == kIOReturnSuccess { awakeAssertion = id }
        } else if awakeAssertion != 0 {
            IOPMAssertionRelease(awakeAssertion); awakeAssertion = 0
        }
    }

    // ---------- 每个 AI 分开算：谁开始、谁结束 ----------
    func CheckWork() {
        KeepAwake(detectedBusy || agentBusy)
        Detector.lock.lock(); var cur = Detector.busyNow; let cpuNow = Detector.cpuDetected; Detector.lock.unlock()
        if manualWork && !cur.contains("Claude") { cur.append("Claude") }
        for a in cpuNow { cpuWas.insert(a) }
        for app in cur {
            appLastSeen[app] = now
            if !appActive.contains(app) {
                appActive.insert(app)
                appStarted[app] = now
                if appActive.count == 1 { workStarted = now }
                today?.Work += 1
                lastBusyApp = app
                if ringing && ringApp.contains(app) { ringing = false; bubbleUntil = 0 }
            }
        }
        var finished: [String] = []
        for app in appActive {
            let seen = appLastSeen[app] ?? 0
            let st = appStarted[app] ?? 0
            // 停止按钮消失一会儿才算做完：AI 分好几步干活时，步骤之间按钮会短暂消失，要等它真的停下来
            let viaCpu = cpuNow.contains(app) || cpuWas.contains(app)
            let grace = viaCpu ? 3.0 : (now - st > 30 ? 25 : 15)
            if !cur.contains(app) && now - seen > grace { finished.append(app) }
        }
        for app in finished {
            appActive.remove(app)
            let st0 = appStarted[app] ?? 0
            let seen0 = appLastSeen[app] ?? 0
            let cpuTask = cpuWas.remove(app) != nil
            let dur = seen0 - st0
            // 太短的不算一个“任务”：一闪而过的按钮、后台随手占了一下 CPU
            if dur < (cpuTask ? 40 : 6) {
                LogEvent(app + " 只忙了 \(Int(dur)) 秒，不算完成任务，不摇铃")
                continue
            }
            lastInteract = now; lastChatAt = now; unanswered = 0
            let interrupted = (now - lastStopClick < 4 && (lastStopApp == app || lastStopApp == "")) || (now - lastEsc < 3 && now - lastClaudeClick < 60)
            if interrupted {
                LogEvent(app + " 被中途停下 → 委屈，不摇铃")
                if !ringing { Set("sad"); Say(Pick(["唔……刚才那次被打断了。", "诶，停下来了吗？没关系，我等你。"]), 5) }
            } else if WatchingApp(app) {
                // m 正盯着这个 AI 的窗口：不用摇铃吵 TA，轻轻说一声就好
                LogEvent(app + " 做完了（忙了 \(Int(dur)) 秒），你正看着它 → 只说一声，不摇铃")
                if !ringing && Grounded() { Set("happy"); Say(app + " 做完啦～", 4) }
            } else { LogEvent(app + " 做完了（忙了 \(Int(dur)) 秒）"); StartRing(app) }
        }

        let busy = !appActive.isEmpty
        if busy {
            notBusyCount = 0
            if !working {
                working = true
                if mode == .Held || mode == .Fall || mode == .Jump { return }
                if !ringing { Set("think") }
            }
            if ringing { return }   // 正在为做完的 AI 摇铃，就先不陪还在忙的那个思考
            var busyState = state == "think" || state == "work" || state == "work2" || state == "build"
            if now < userActUntil || state == "eat" || state == "catch" || state == "yum" { busyState = true }
            else if Grounded() && !busyState && state != "done" && now - since > 1 { Set("think") }
            let wt = now - workStarted
            if Grounded() && busyState && now >= userActUntil && state != "eat" && state != "catch" && state != "yum" {
                // 想一会儿 → 在终端里敲命令 → 抱着电脑写代码，轮流来；超过两分钟戴上安全帽开始敲锤子
                let want = wt > 120 ? "build" : ["think", "work", "work2"][I(wt / 8) % 3]
                if want != state { Set(want) }
            }
        } else if working {
            working = false; notBusyCount = 0
            if !ringing && (state == "think" || state == "work" || state == "work2" || state == "build") { Set("idle") }
        }
    }

    func DetectLoop() {
        var fails = 0
        var askedAX = false
        while true {
            if !AX.Trusted(prompt: false) {
                if !askedAX { askedAX = true; _ = AX.Trusted(prompt: true); OnMain { [weak self] in self?.AskAccessibility() } }
                Thread.sleep(forTimeInterval: 3); continue
            }
            var f: [String]? = nil
            autoreleasepool { f = Detector.Detect() }
            if f != nil { fails = 0 } else { fails += 1 }
            if var list = f {
                let cpu = Detector.CpuBusyApps()
                Detector.lock.lock()
                Detector.cpuDetected.removeAll()
                for a in cpu where !list.contains(a) { list.append(a); Detector.cpuDetected.insert(a) }
                Detector.lock.unlock()
                f = list
            }
            if f == nil { if fails < 3 { Thread.sleep(forTimeInterval: 1.5); continue }; f = [] }
            if Detector.detectFrozen { Thread.sleep(forTimeInterval: 1.5); continue }
            let l = f!
            Detector.lock.lock(); Detector.busyNow = l; Detector.lock.unlock()
            OnMain { [weak self] in self?.busyApp = l.joined(separator: "、"); self?.detectedBusy = !l.isEmpty }
            Thread.sleep(forTimeInterval: 1.5)
        }
    }

    /// 第一次用：请 m 打开“辅助功能”权限，不然看不到 AI 窗口
    func AskAccessibility() {
        Say("想知道 AI 有没有做完，要在「系统设置 → 隐私与安全性 → 辅助功能」里打开" + Names.Pet + "哦～", 12)
    }

    func Diagnose() {
        Say("我在检查 AI 的窗口，稍等一下…", 4)
        Background { [weak self] in
            guard let s = self else { return }
            var sb = ""
            if !AX.Trusted(prompt: false) { sb += "还没有打开“辅助功能”权限：系统设置 → 隐私与安全性 → 辅助功能，把 " + Names.Pet + " 打开。\n\n" }
            let wins = Detector.AiWindows()
            sb += "找到 AI 窗口数量：\(wins.count)\n"
            for (label, app, w) in wins {
                sb += "\n窗口：" + AX.Str(w, kAXTitleAttribute as String) + "  (" + (app.localizedName ?? "") + " → " + label + ")\n"
                var n = 0
                AX.Walk(w, deadline: Date().timeIntervalSince1970 + 4) { e, role in
                    if role == (kAXButtonRole as String) {
                        let name = AX.Name(e)
                        sb += (Detector.IsStopName(name) ? (Detector.Ignored(label, name) ? "  ☆(已忽略) " : "  ★ ") : "    ") + "按钮：" + name + "\n"
                        n += 1
                    }
                    return n > 400
                }
            }
            sb += "\n说明：带 ★ 的按钮被当作“停止”按钮。AI 正在工作时运行一次诊断，把这个文件发给 Claude，它就能帮你调整。\n"
            let f = PathJoin(s.dir, "诊断结果.txt")
            FileX.Write(f, sb)
            OnMain { OpenPath(f) }
        }
    }
}
