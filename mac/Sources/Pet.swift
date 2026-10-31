import AppKit
import Foundation

// ---------- 叮叮主体：窗口、物理、动作（对应 Windows 版的 Pet.cs） ----------

final class Particle {
    var Kind = ""
    var X = 0.0, Y = 0.0, VX = 0.0, VY = 0.0, Life = 0.0
}

enum Mode { case Ground, Perch, Fall, Held, Jump, Free }

/// 画叮叮的那块透明画布
final class PetView: NSView {
    weak var pet: PetForm?
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for e: NSEvent?) -> Bool { true }
    override func draw(_ r: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let p = pet else { return }
        ctx.clear(bounds)
        ctx.setShouldAntialias(false)
        ctx.interpolationQuality = .none
        p.Paint(ctx)
    }
    override func mouseDown(with e: NSEvent) { pet?.OnDown(e) }
    override func mouseDragged(with e: NSEvent) { pet?.OnMove(e) }
    override func mouseUp(with e: NSEvent) { pet?.OnUp(e) }
    override func rightMouseDown(with e: NSEvent) { pet?.ShowMenu(e, self) }
}

final class PetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PetForm: NSObject {
    // ---------- 尺寸 ----------
    // 画布：x 从 -3 到 18、y 从 -6 到 17（单位格），每个单位格再细分成 4×4 小格
    let UX0 = 11.0, UY0 = 6.0
    let GW = 148, GH = 92            // 小格数
    var S = 3                        // 每个小格多少屏幕点
    let BUBBLE_H = 120               // 头顶对话气泡的空间
    let FORM_W_MIN = 360
    let FOOT = 84                    // 脚底所在的小格行（y=15）

    var win: PetWindow!
    var view: PetView!
    var cw = 360.0, ch = 400.0       // 窗口大小（点）

    // ---------- 表情状态 ----------
    var state = "idle"
    var since = 0.0, now = 0.0, nextBlink = 2.0, blinkUntil = 0.0, nextIdleAct = 9.0, lastSpawn = 0.0
    var lastInteract = 0.0, lastChatAt = 0.0, workStarted = 0.0
    var unanswered = 0
    var afterStretch = "idle"
    var pokes: [Double] = []
    var parts: [Particle] = []
    let rnd = Rnd()
    let startTime = Date()

    // ---------- 位置与物理（屏幕坐标：posX=身体中线，posY=脚底；左上角为原点，往下为正） ----------
    var thrown = false
    var mode: Mode = .Fall
    var posX = 0.0, posY = 0.0, vx = 0.0, vy = 0.0
    var perchWnd: UInt32 = 0
    var perchRect = RectI(Left: 0, Top: 0, Right: 0, Bottom: 0)
    var jumpT = 0.0, jx0 = 0.0, jy0 = 0.0, jx1 = 0.0, jy1 = 0.0
    var jumpWnd: UInt32 = 0
    var jumpToFloor = false
    var walkGear = false
    var lastFestSpawn = 0.0
    var walkDir = 1
    var walkUntil = 0.0, walkTarget = Double.nan, paceCenter = 0.0
    var squash = 0
    var lastFrame = 0.0
    var heldOffX = 0.0, heldOffY = 0.0
    var lastCurX = 0.0, lastCurY = 0.0, cursorVX = 0.0, cursorVY = 0.0

    // ---------- 和人的互动 ----------
    var detectedBusy = false
    var working = false, manualWork = false, pendingDone = false, away = false
    var notBusyCount = 0
    var lastKeyIdle = 999.0
    var keyEvents: [Double] = []
    var lastShakeReact = 0.0, hoverSince = -1.0, lastHoverReact = 0.0, lastClaudeClick = -99.0, lastEsc = -99.0
    var activeSince = 0.0, lastSitRemind = 0.0, lastTimeCheck = 0.0, lastDecay = 0.0, lastSulkLine = 0.0
    var said = Swift.Set<String>()
    var aff = 50
    var fed: [Double] = []

    var muted = false
    var bubbleText = ""
    var bubbleUntil = 0.0
    var chatting = false

    var timer: Timer?
    var downX = 0.0, downY = 0.0, mouseDown = false, dragged = false
    var dir = ""          // 叮叮的文件夹：设置、日记、记忆都放这里（~/Library/Application Support/叮叮）
    var cfgDir = ""       // 数据文件夹
    var resDir = ""       // 程序自带的资源（字体、自带形象）
    var apiKey = ""
    let myPid = ProcessInfo.processInfo.processIdentifier
    var userActUntil = 0.0
    var tickErrorLogged = false

    var hatChoice = "bow"
    var festMode = ""        // "" = 跟着日历走，"off" = 不换装，其他 = 预览某个节日
    var birthday = ""        // config.txt 里的 birthday=MM-DD
    var petBirthday = ""

    // 绘制
    var G: CGContext?
    var OX = 0, OY = 0

    // ---------- Features ----------
    var ptext: PixelText!
    var hunger = 20
    var lastHungerTick = 0.0, lastHungryAsk = 0.0
    var weatherKind = ""
    var weatherText = ""
    var weatherOn = true
    var metDate = Today()
    var unlockLevel = 0
    var today: DayStats!
    var lastStatsSave = 0.0, lastQuietCheck = 0.0, quietSince = -1.0
    var quiet = false, manualQuiet = false
    var pomoEnd = -1.0, breakEnd = -1.0
    var pomoMinutes = 0
    var awayStart = 0.0
    var memos: [[String]] = []
    var reminders: [(Date, String)] = []
    var signText = ""
    var chatLog: [[String]] = []
    var chatWin: ChatWindow?
    var pendingSays: [String] = []
    var sayTimer: Timer?

    // ---------- 形象（皮肤） ----------
    var skins: [Skin] = []
    var skin: Skin?
    var SKIN_LINE = B("#5E3B2C"), SKIN_FEET = B("#E99A8A"), SKIN_EYE = B("#1A1A1A"), SKIN_HAND = B("#F2B880")
    var skinBrushes: [Character: Brush] = [:]
    var thinBrushes = Swift.Set<Brush>()
    var cells: [[Brush?]] = []
    var outlineMark: [Bool] = []
    var BODY = B("#A9BBCF"), BODY_D = B("#8C9FB4")

    // ---------- 声音 ----------
    var curSound: NSSound?
    var bigSoundUntil = 0.0, lastStepSfx = 0.0
    var stepParity = 0
    var stepSfx = true
    var ringing = false, ringDeferred = false
    var ringStart = 0.0
    var ringStage = 0
    var ringApp = "Claude"

    // ---------- AI ----------
    var apiBase = "https://api.anthropic.com"
    var chatModel = "claude-sonnet-5-5"
    var quickModel = "claude-haiku-5-5"
    var visionBase = "", visionFormat = "", visionModel = ""
    var apiFormat = "anthropic"
    var saver = true
    var convo: [[String]] = []
    var memoryNotes: [String] = []
    var recentProactive: [String] = []
    var agentBusy = false
    var nextProactive = 0.0
    var chatFreq = "normal"
    var walkRangeSetting = "small"
    var looks: [Look] = []
    var localHintShown = false
    var keepingAwake = false
    var awakeAssertion: UInt32 = 0
    var busyApp = ""
    var lastBusyApp = "Claude"
    var homeX = Double.nan
    var walkPalSince = -1.0
    var walkAfterLand = false
    var personality = "default"
    var personalityCustom = ""
    var aiWin: AISettingsWindow?
    var upgradePending = false
    let upgradeStamp = Fmt(Date(), "yyyyMMdd_HHmmss")

    // ---------- 检测 AI 工作 ----------
    var appActive = Swift.Set<String>()
    var appLastSeen: [String: Double] = [:]
    var appStarted: [String: Double] = [:]
    var cpuWas = Swift.Set<String>()
    var lastStopClick = -99.0
    var lastStopApp = ""

    // ---------- 离线小脑袋 ----------
    var brain = BrainState()

    init(folder: String, resources: String) {
        super.init()
        dir = folder; cfgDir = folder; resDir = resources
        FileX.MkDir(cfgDir)
        LoadConfig()
        muted = FileX.Exists(PathJoin(cfgDir, "mute.txt"))
        cells = Array(repeating: Array(repeating: nil, count: SKIN_W + PAD * 2), count: SKIN_H + PAD * 2 + 4)
        outlineMark = Array(repeating: false, count: (SKIN_H + PAD * 2 + 4) * (SKIN_W + PAD * 2))

        win = PetWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 400), styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        win.title = Names.Pet
        view = PetView(frame: NSRect(x: 0, y: 0, width: 360, height: 400))
        view.pet = self
        win.contentView = view
        win.acceptsMouseMovedEvents = true

        ResizeForm()
        LoadState()
        InitFeatures()
        InitAgent()

        win.orderFrontRegardless()

        timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.Tick() }
        RunLoop.main.add(timer!, forMode: .common)

        Background { [weak self] in self?.DetectLoop() }

        lastInteract = Now(); lastChatAt = Now(); lastDecay = Now()
        activeSince = Now()
        Greet()
    }

    func Now() -> Double { Date().timeIntervalSince(startTime) }
    func FootOffset() -> Double { Double(BUBBLE_H + FOOT * S) }

    func ResizeForm() {
        cw = Double(max(FORM_W_MIN, GW * S + 20))
        ch = Double(BUBBLE_H + GH * S)
        win.setContentSize(NSSize(width: cw, height: ch))
        view.frame = NSRect(x: 0, y: 0, width: cw, height: ch)
    }

    // 窗口左上角（屏幕坐标，往下为正）
    var Left: Double { Double(win.frame.minX) }
    var Top: Double { Scr.primaryH - Double(win.frame.maxY) }

    func Place() {
        let x = (posX - cw / 2).rounded(), y = (posY - FootOffset()).rounded()
        win.setFrameOrigin(Scr.toMac(x, y, ch))
    }

    // ---------- 设置与存档 ----------
    func LoadConfig() {
        let f = PathJoin(dir, "config.txt")
        if !FileX.Exists(f) { return }
        for line in FileX.Lines(f) {
            let l = line.Trim
            if l.hasPrefix("#") || l.IndexOf("=") < 0 { continue }
            let k = l.Sub(0, l.IndexOf("=")).Trim.Lower
            let v = l.Sub(l.IndexOf("=") + 1).Trim
            if k == "api_key" { apiKey = v }
            if k == "api_base" && v != "" { apiBase = v }
            if k == "chat_model" && v != "" { chatModel = v }
            if k == "quick_model" && v != "" { quickModel = v }
            if k == "api_format" { apiFormat = v.Lower == "openai" ? "openai" : "anthropic" }
            if k == "vision_base" { visionBase = v }
            if k == "vision_format" { visionFormat = v.Lower == "openai" ? "openai" : v == "" ? "" : "anthropic" }
            if k == "vision_model" { visionModel = v }
            if k == "saver" { saver = v.Lower != "off" }
            if k == "birthday" { birthday = v.Replace("/", "-").Replace(".", "-") }
            if k == "pet_birthday" { petBirthday = v.Replace("/", "-").Replace(".", "-") }
            if k == "size", let s = Int(v), s >= 2 && s <= 6 { S = s }
        }
    }

    func LoadState() {
        let wa = Scr.WorkingArea(Scr.Primary)
        posX = wa.Right - 140; posY = wa.Bottom - 200
        let f = PathJoin(cfgDir, "state.txt")
        for line in FileX.Lines(f) {
            let kv = line.Split("=")
            if kv.count != 2 { continue }
            if kv[0] == "hat" { hatChoice = kv[1].Trim; continue }
            if kv[0] == "fest" { festMode = kv[1].Trim == "off" ? "off" : ""; continue }
            guard let d = Double(kv[1].Trim) else { continue }
            if kv[0] == "x" { posX = d }
            if kv[0] == "y" { posY = d }
            if kv[0] == "size" && d >= 2 && d <= 6 { S = Int(d); ResizeForm() }
            if kv[0] == "aff" { aff = max(0, min(100, Int(d))) }
        }
        var onScreen = false
        for sc in Scr.All { if Scr.Bounds(sc).Contains(posX, posY - 10) { onScreen = true } }
        if !onScreen { posX = wa.Right - 140; posY = wa.Bottom - 200 }
        let wa2 = ScreenArea(posX)
        if posY > wa2.Bottom { posY = wa2.Bottom }
        mode = abs(posY - wa2.Bottom) < 3 ? .Ground : .Free   // 上次放在哪里，就出现在哪里
        vx = 0; vy = 0; homeX = posX
        Place()
    }

    func SaveState() {
        FileX.Write(PathJoin(cfgDir, "state.txt"),
                    "x=\(posX)\ny=\(posY)\nsize=\(S)\naff=\(aff)\nhat=\(hatChoice)\nfest=\(festMode == "off" ? "off" : "auto")\n")
    }

    func AddAff(_ d: Int) {
        aff = max(0, min(100, aff + d))
        SaveState()
    }

    // ---------- 开机自动启动（放进“登录项”） ----------
    func StartupFile() -> String {
        return PathJoin(NSHomeDirectory(), "Library/LaunchAgents/io.github.dingding.\(Names.DataFolder.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "pet").plist")
    }

    func ToggleAutostart() {
        let f = StartupFile()
        if FileX.Exists(f) { FileX.Delete(f); Say("好，开机就不自动出来啦。", 4); return }
        FileX.MkDir((f as NSString).deletingLastPathComponent)
        let exe = AppPaths.bundleExe
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>Label</key><string>\((f as NSString).lastPathComponent.replacingOccurrences(of: ".plist", with: ""))</string>
        <key>ProgramArguments</key><array><string>\(exe)</string></array>
        <key>RunAtLoad</key><true/>
        </dict></plist>
        """
        if FileX.Write(f, plist) { Say("以后开机我就自己跑出来陪你！", 4) } else { Say("设置失败了……", 6) }
    }

    // ---------- 鼠标 ----------
    func OnDown(_ e: NSEvent) {
        if e.clickCount == 2 && !dragged { mouseDown = false; Pat(); return }
        mouseDown = true; dragged = false
        let c = Scr.Cursor
        downX = c.X; downY = c.Y
        heldOffX = posX - downX; heldOffY = posY - downY
    }
    func OnMove(_ e: NSEvent) {
        if !mouseDown { return }
        let p = Scr.Cursor
        if !dragged && abs(p.X - downX) + abs(p.Y - downY) > 5 {
            dragged = true
            mode = .Held; perchWnd = 0
            Interact()
            Set("held")
        }
    }
    func OnUp(_ e: NSEvent) {
        if !mouseDown { return }
        mouseDown = false
        if dragged {
            // 往下甩（带一点弧线）才会掉下去摔倒；其他时候松手就停在原地
            if cursorVY > 650 && cursorVY > abs(cursorVX) * 0.35 {
                mode = .Fall; thrown = true
                vx = max(-1400, min(1400, cursorVX * 0.8))
                vy = max(300, min(1500, cursorVY * 0.6))
                Set("fall")
            } else {
                let wa = ScreenArea(posX)
                if posY > wa.Bottom { posY = wa.Bottom }
                mode = abs(posY - wa.Bottom) < 4 ? .Ground : .Free
                if mode == .Ground { posY = wa.Bottom }
                homeX = posX; vx = 0; vy = 0
                squash = 1; Set(working ? "think" : "land")
                SaveState()
            }
            return
        }
        let p = view.convert(e.locationInWindow, from: nil)
        if Double(p.y) > Double(BUBBLE_H) { Poke() } else if bubbleText != "" { bubbleUntil = 0 }
    }

    func ShowMenu(_ e: NSEvent, _ v: NSView) {
        let m = BuildMenu()
        NSApp.activate(ignoringOtherApps: true)
        NSMenu.popUpContextMenu(m, with: e, for: v)
    }

    // ---------- 状态切换 ----------
    func Set(_ s: String) {
        state = s; since = now
        parts.removeAll { $0.Kind == "z" }
        if s == "done" { Spawn("spark", 9) }
        if s == "party" { Spawn("conf", 14) }
        StateSound(s)
    }

    func Grounded() -> Bool { mode == .Ground || mode == .Perch || mode == .Free }
    func Calm() -> Bool {
        return state == "idle" || state == "walk" || state == "sit" || state == "daydream" || state == "lookaround"
    }

    func Interact() { lastInteract = now; unanswered = 0 }

    func Poke() {
        if Acknowledge() { return }
        Interact()
        PlaySfx("poke")
        if working { UserAct(2) }
        if state == "sulk" { Forgive(); return }
        pokes.removeAll { now - $0 > 4 }
        pokes.append(now)
        if pokes.count >= 8 { pokes.removeAll(); Set("angry"); Say("哼！别戳啦！", 3); AddAff(-4); return }
        if pokes.count >= 5 { Set("dizzy"); Say("晕……晕了……", 3); return }
        AddAff(1); today?.Poke += 1
        Set(Pick(["surprised", "surprised", "wink", "shy", "happy"]))
    }

    func Pat() {
        if Acknowledge() { return }
        Interact()
        PlaySfx("purr")
        if working { UserAct(3.4) }
        if state == "sulk" { Forgive(); return }
        AddAff(3); today?.Pat += 1
        Set(rnd.NextDouble() < 0.5 ? "love" : "shy")
        if Festival() == "petbday" && Once(Fmt(Date(), "yyyyMMdd") + "bdaypat") { Set("party"); Say("生日摸头！这是我今天收到的最好的礼物～", 4); return }
        if aff >= 80 { Say(Pick(["最喜欢你啦！", "嘿嘿，再摸一下嘛～", "被你摸头是今天最开心的事！"]), 3) }
        else { Say(Pick(["嘿嘿，好舒服～", "再摸摸嘛～", "唔……有点不好意思。"]), 3) }
    }

    func Forgive() {
        AddAff(5)
        Set("shy")
        Say("哼……好吧，原谅你了。下次不许不理我。", 4)
    }

    // m 主动叫它做的动作，就算 AI 在工作也先做完，再回去陪 AI
    func UserAct(_ seconds: Double) { userActUntil = now + seconds }
    func Act(_ s: String) {
        Interact()
        Set(s)
        UserAct((PetForm.HOLD_T[s] ?? 3.8) + 0.2)
    }

    func Pick(_ a: [String]) -> String { a.isEmpty ? "" : a[rnd.Next(a.count)] }

    static let HOLD_T: [String: Double] = [
        "done": 1.6, "brush": 7, "shower": 8, "hungry": 5, "sign": 12, "party": 2.6, "confused": 1.8, "miss": 5, "music": 8, "read": 8, "juggle": 6, "bird": 6.5, "wave": 2.2, "surprised": 1.0, "happy": 3, "lookaround": 2.6, "daydream": 7, "talk": 4, "wink": 1.6,
        "shy": 3.2, "love": 3.2, "dizzy": 3, "angry": 3.2, "sad": 4, "dance": 5, "land": 0.35,
        "sit": 7, "eat": 3.6, "jumpy": 0.6]
    static let HOLD_N: [String: String] = [
        "done": "party", "brush": "idle", "shower": "happy", "hungry": "idle", "sign": "idle", "party": "idle", "confused": "idle", "miss": "idle", "music": "idle", "read": "idle", "juggle": "idle", "bird": "idle", "wave": "idle", "surprised": "happy", "happy": "idle", "lookaround": "idle", "daydream": "idle", "talk": "idle",
        "wink": "idle", "shy": "idle", "love": "idle", "dizzy": "idle", "angry": "idle", "sad": "idle", "dance": "idle",
        "land": "idle", "sit": "idle", "eat": "yum", "jumpy": "idle"]

    // ---------- 每帧 ----------
    func Tick() {
        TickInner()
    }

    func TickInner() {
        now = Now()
        let dt = lastFrame > 0 ? min(0.1, now - lastFrame) : 0.033
        lastFrame = now
        let t = now - since

        SenseUser(dt)
        CheckWork()
        FeaturesTick(dt)
        RingTick()
        StepSound()
        ProactiveTick()

        // 自动转换
        if state == "eat" || state == "yum" || PetForm.HOLD_T[state] != nil {
            if state == "yum" { Set("happy"); Say(Pick(["好吃！橘子最棒了！", "嗷呜～甜甜的！", "吃饱饱，有力气陪你了！"]), 4) }
            else if let hold = PetForm.HOLD_T[state], t > hold { Set(PetForm.HOLD_N[state]!) }
        }
        else if state == "stretch" && t > 2.8 { let n = afterStretch; afterStretch = "idle"; Set(n) }
        else if state == "walk" && !walkUntil.isNaN && now > walkUntil { Set(rnd.NextDouble() < 0.3 ? "sit" : "idle") }
        else if state == "type" && (keyEvents.isEmpty || now - keyEvents.last! > 2.5) { Set("idle") }
        else if state == "sulk" && now - lastSulkLine > 60 { lastSulkLine = now; Say(Pick(["哼。", "……", "哼，不理你。"]), 3) }
        else if state == "idle" && !working && !chatting && t > nextIdleAct { IdleAction() }

        if now > nextBlink { blinkUntil = now + 0.13; nextBlink = now + 2 + rnd.NextDouble() * 3.5 }

        Physics(dt)
        UpdateParticles(dt)
        if now - lastTimeCheck > 20 { lastTimeCheck = now; TimeEvents() }
        view.needsDisplay = true
    }

    // ---------- 感知你在做什么 ----------
    func SenseUser(_ dt: Double) {
        let c = Scr.Cursor
        cursorVX = cursorVX * 0.6 + (c.X - lastCurX) / max(dt, 0.001) * 0.4
        cursorVY = cursorVY * 0.6 + (c.Y - lastCurY) / max(dt, 0.001) * 0.4
        let speed = (cursorVX * cursorVX + cursorVY * cursorVY).squareRoot()
        lastCurX = c.X; lastCurY = c.Y

        // 键盘：离上次按键的时间突然变短，就算敲了一下键
        let k = Idle.KeySeconds()
        if k < lastKeyIdle - 0.02 || (k < 0.05 && lastKeyIdle > 0.05) { keyEvents.append(now) }
        lastKeyIdle = k
        keyEvents.removeAll { now - $0 > 3 }
        let typing = keyEvents.count >= 4
        if typing && !working && Grounded() && Calm() { Set("type") }

        // 点"停止"或按 Esc：记下来，用来判断是不是被打断
        if Idle.LeftDown() {
            for (app, r) in Detector.stopRectsCopy() where r.Contains(c.X, c.Y) { lastStopClick = now; lastStopApp = app }
            if OverAI(c.X, c.Y) { lastClaudeClick = now }
        }
        if Idle.EscDown() { lastEsc = now }

        // 鼠标快速晃过 → 吓一跳；鼠标停在身上 → 害羞/开心
        let dx = c.X - posX, dy = c.Y - (posY - 22 * Double(S))
        let dist = (dx * dx + dy * dy).squareRoot()
        if speed > 4500 && dist < 260 && now - lastShakeReact > 6 && !working && Grounded() && Calm() {
            lastShakeReact = now; Set("surprised"); Say(Pick(["哇！吓我一跳！", "什么东西飞过去了？！"]), 2.5)
        }
        if dist < 22 * Double(S) && !mouseDown {
            if hoverSince < 0 { hoverSince = now }
            if now - hoverSince > 1.6 && now - lastHoverReact > 25 && !working && state == "idle" {
                lastHoverReact = now; Set(aff >= 60 ? "love" : "shy")
                Say(aff >= 60 ? "你在看我吗？嘿嘿～" : "唔……干嘛一直盯着我。", 3)
            }
        } else { hoverSince = -1 }

        // 离开与回来
        let idle = Idle.Seconds()
        if !away && idle > 300 { away = true; awayStart = now - idle }
        else if away && idle < 2 {
            away = false; activeSince = now
            ReturnFromAway(now - awayStart)
        }
        else if !away && pendingDone && idle < 2 {
            pendingDone = false
            let line = NICK + "，你刚才不在，Claude 已经做完啦！"
            Say(line, 8); Announce(line)
        }

        // 久坐提醒：连续在电脑前 45 分钟
        if !away && now - activeSince > 45 * 60 && now - lastSitRemind > 45 * 60 && !working {
            lastSitRemind = now; activeSince = now
            afterStretch = "idle"; Set("stretch")
            let line = NICK + "，已经坐了四十五分钟啦，起来走走、喝口水吧！"
            Say(line, 8); Announce(line)
        }

        // 亲密度慢慢下降
        if now - lastInteract > 20 * 60 && now - lastDecay > 20 * 60 && !away { lastDecay = now; AddAff(-2) }
    }

    /// 鼠标下面是不是 AI 的窗口
    func OverAI(_ x: Double, _ y: Double) -> Bool {
        guard let w = WinList.At(x, y) else { return false }
        return w.owner.lowercased() == "claude" || Detector.IsBrowser(w.owner)
    }

    // ---------- 平时自己找事做 ----------
    func IdleAction() {
        nextIdleAct = 6 + rnd.NextDouble() * 7
        if FeatureIdle() { return }
        let idle = Idle.Seconds()

        if !away && now - lastInteract > 40 * 60 && aff < 45 {
            Set("sulk"); lastSulkLine = now; Say("哼，你都不理我……", 4); return
        }
        if away && idle > 600 { afterStretch = "sleep"; Set("stretch"); return }
        if !away && now - lastInteract > 15 * 60 && idle > 180 { afterStretch = "sleep"; Set("stretch"); return }

        if !Grounded() { return }
        if WalkPalDone() { return }
        var w: [(String, Int)] = []
        w.append(("daydream", 14))
        w.append(("lookaround", 12))
        w.append(("happy", 8))
        w.append(("stretch", 7))
        if Unlocked("dance") { w.append(("dance", 6)) }
        w.append(("wink", 6))
        w.append(("love", aff >= 70 ? 10 : 3))
        w.append(("shy", 4))
        w.append(("music", 8))
        w.append(("read", 7))
        if Unlocked("juggle") { w.append(("juggle", 6)) }
        w.append(("bird", 5))
        let walkPal = looks.contains { $0.Enabled && $0.When == "walk" }
        if WalkRangePx() > 0 { w.append(("walk", walkPal ? 20 : away ? 18 : 14)) }   // 遛着猫稍微多走一点
        w.append(("sit", 10))
        let cur = Scr.Cursor
        if aff >= 70 && !away && WalkRangePx() > 0 && abs(cur.X - posX) < WalkRangePx() * 2 { w.append(("chase", 6)) }
        w = w.map { ($0.0, max(0, Int((Double($0.1) * PersonaMult($0.0)).rounded()))) }
        let sum = w.reduce(0) { $0 + $1.1 }
        if sum <= 0 { Set("daydream"); return }
        var x = rnd.Next(sum); var pick = "daydream"
        for kv in w { x -= kv.1; if x < 0 { pick = kv.0; break } }

        if pick == "walk" { StartWalk(rnd.Next(2) == 0 ? -1 : 1, 2 + rnd.NextDouble() * (walkPal ? 4 : 2.5), Double.nan) }
        else if pick == "chase" { StartWalk(cur.X > posX ? 1 : -1, 3, cur.X) }
        else if pick == "perch" { if !TryJumpToWindow(false) { Set("daydream") } }
        else if pick == "hopdown" { HopDown() }
        else { Set(pick) }
    }

    func StartWalk(_ d: Int, _ seconds: Double, _ target: Double) {
        walkDir = d; walkUntil = now + seconds; walkTarget = target; walkGear = seconds > 4 && rnd.NextDouble() < 0.45
        Set("walk")
    }

    // ---------- 窗口：跳到窗口顶上 ----------
    func GoodPerch(_ h: UInt32, _ r: inout RectI) -> Bool {
        if h == 0 { return false }
        guard let w = WinList.ById(h) else { return false }
        if w.pid == myPid || w.layer != 0 || w.minimized { return false }
        r = w.rect
        if r.Right - r.Left < 50 * Double(S) || r.Bottom - r.Top < 120 { return false }
        let wa = Scr.WorkingArea(Scr.FromPoint((r.Left + r.Right) / 2, max(r.Top, 0)))
        if r.Top < wa.Top + 70 * Double(S) || r.Top > wa.Bottom - 60 { return false }
        if abs(r.Left - wa.Left) < 2 && abs(r.Right - wa.Right) < 2 && abs(r.Top - wa.Top) < 2 { return false }   // 铺满屏幕的窗口
        return true
    }

    func TryJumpToWindow(_ asked: Bool) -> Bool {
        if mode != .Ground && mode != .Perch { return false }
        let h = WinList.FrontWindow()?.id ?? 0
        var r = RectI(Left: 0, Top: 0, Right: 0, Bottom: 0)
        if !GoodPerch(h, &r) {
            if asked { Say("这个窗口我跳不上去……（全屏或太靠上的窗口不行）", 4) }
            return false
        }
        let margin = 24 * Double(S)
        let tx = max(r.Left + margin, min(r.Right - margin, posX + (rnd.NextDouble() - 0.5) * 200))
        StartJump(tx, r.Top, h, false)
        return true
    }

    func HopDown() {
        let wa = Scr.WorkingArea(Scr.FromPoint(posX, posY))
        var tx = posX + (posX - perchRect.Left < perchRect.Right - posX ? -1 : 1) * (min(posX - perchRect.Left, perchRect.Right - posX) + 30 * Double(S))
        tx = max(wa.Left + 24 * Double(S), min(wa.Right - 24 * Double(S), tx))
        StartJump(tx, wa.Bottom, 0, true)
    }

    func StartJump(_ tx: Double, _ ty: Double, _ wnd: UInt32, _ floor: Bool) {
        mode = .Jump; jumpT = 0; jx0 = posX; jy0 = posY; jx1 = tx; jy1 = ty; jumpWnd = wnd; jumpToFloor = floor
        perchWnd = 0
        Set("jump")
    }

    // ---------- 物理 ----------
    func Physics(_ dt: Double) {
        let c = Scr.Cursor
        let Sd = Double(S)
        switch mode {
        case .Held:
            posX = c.X + heldOffX; posY = c.Y + heldOffY

        case .Jump:
            jumpT += dt / 0.75
            let u = min(1, jumpT)
            let h = 60 + abs(jy1 - jy0) * 0.3
            posX = jx0 + (jx1 - jx0) * u
            posY = jy0 + (jy1 - jy0) * u - sin(u * Double.pi) * h
            if u >= 1 {
                var r = RectI(Left: 0, Top: 0, Right: 0, Bottom: 0)
                if !jumpToFloor && GoodPerch(jumpWnd, &r) { perchWnd = jumpWnd; perchRect = r; posY = r.Top; mode = .Perch }
                else if jumpToFloor { mode = .Ground }
                else { mode = .Fall; vx = 0; vy = 0; break }
                Land(500)
                if walkAfterLand && mode == .Ground { walkAfterLand = false; homeX = posX; UserAct(8); StartWalk(rnd.Next(2) == 0 ? -1 : 1, 6, Double.nan) }
            }

        case .Fall:
            let oldY = posY
            vy += 2600 * dt
            posX += vx * dt; posY += vy * dt
            let wa = ScreenArea(posX)
            if posX < wa.Left + 22 * Sd { posX = wa.Left + 22 * Sd; vx = -vx * 0.5 }
            if posX > wa.Right - 22 * Sd { posX = wa.Right - 22 * Sd; vx = -vx * 0.5 }
            if posY < wa.Top + 60 * Sd && vy < 0 { vy = 0 }
            // 落到当前窗口顶上
            if vy > 0, let fw = WinList.FrontWindow() {
                var r = RectI(Left: 0, Top: 0, Right: 0, Bottom: 0)
                if GoodPerch(fw.id, &r) && oldY <= r.Top && posY >= r.Top && posX > r.Left + 18 * Sd && posX < r.Right - 18 * Sd {
                    posY = r.Top; perchWnd = fw.id; perchRect = r; mode = .Perch; Land(vy); homeX = posX; break
                }
            }
            if posY >= wa.Bottom {
                posY = wa.Bottom; mode = .Ground; Land(vy); homeX = posX; SaveState()
                if walkAfterLand && state != "dizzy" { walkAfterLand = false; UserAct(8); StartWalk(rnd.Next(2) == 0 ? -1 : 1, 6, Double.nan) }
            }

        case .Perch:
            var r = RectI(Left: 0, Top: 0, Right: 0, Bottom: 0)
            if !GoodPerch(perchWnd, &r) { mode = .Fall; vx = 0; vy = 0; if state != "held" { Set("fall") }; break }
            posX += r.Left - perchRect.Left          // 窗口被拖动，跟着走
            posY = r.Top
            perchRect = r
            if posX < r.Left + 14 * Sd || posX > r.Right - 14 * Sd {
                if state == "walk" || state == "pace" { walkDir = -walkDir; posX = max(r.Left + 14 * Sd, min(r.Right - 14 * Sd, posX)) }
                else { mode = .Fall; vx = 0; vy = 0; Set("fall"); break }
            }
            if homeX.isNaN { homeX = posX }
            Walk(dt, max(r.Left + 20 * Sd, homeX - WalkRangePx()), min(r.Right - 20 * Sd, homeX + WalkRangePx()))

        case .Ground:
            let wa = ScreenArea(posX)
            if abs(posY - wa.Bottom) > 2 { mode = .Free; break }  // 程序坞位置变了，就待在原地
            if homeX.isNaN { homeX = posX }
            Walk(dt, max(wa.Left + 24 * Sd, homeX - WalkRangePx()), min(wa.Right - 24 * Sd, homeX + WalkRangePx()))

        case .Free:
            let wa = ScreenArea(posX)
            if homeX.isNaN { homeX = posX }
            Walk(dt, max(wa.Left + 24 * Sd, homeX - WalkRangePx()), min(wa.Right - 24 * Sd, homeX + WalkRangePx()))
        }
        Place()
    }

    func ScreenArea(_ x: Double) -> RectI {
        var best = Scr.Primary
        for sc in Scr.All { let b = Scr.Bounds(sc); if x >= b.Left && x < b.Right { best = sc } }
        return Scr.WorkingArea(best)
    }

    func Walk(_ dt: Double, _ minX: Double, _ maxX: Double) {
        if state != "walk" && state != "pace" { return }
        if maxX - minX < 4 { Set("idle"); return }
        let speed = (state == "pace" ? 8 : 10) * Double(S)
        posX += Double(walkDir) * speed * dt
        if state == "pace" {
            if posX > paceCenter + 30 * Double(S) { walkDir = -1 }
            if posX < paceCenter - 30 * Double(S) { walkDir = 1 }
        }
        if !walkTarget.isNaN && state == "walk" && abs(posX - walkTarget) < 6 {
            walkTarget = Double.nan; Set(aff >= 70 ? "love" : "idle"); return
        }
        if posX < minX { posX = minX; walkDir = 1; walkTarget = Double.nan }
        if posX > maxX { posX = maxX; walkDir = -1; walkTarget = Double.nan }
    }

    func Land(_ speed: Double) {
        squash = speed > 1500 ? 3 : speed > 700 ? 2 : 1
        vx = 0; vy = 0
        Spawn("dust", 4)
        let wasThrown = thrown; thrown = false
        if wasThrown {
            squash = 3
            Set("dizzy")
            PlaySfx("thud")
            Say(Pick(["哎哟！摔倒了……", "呜……屁股好痛……", "眼前全是小星星……", Names.Nick + " 好坏，把我摔下来了！"]), 3)
            today?.Poke += 1
            return
        }
        if working { Set("think"); return }
        Set("land")
    }

    // ---------- 粒子 ----------
    func UpdateParticles(_ dt: Double) {
        var i = parts.count - 1
        while i >= 0 {
            let p = parts[i]
            p.Life -= dt; p.X += p.VX * dt; p.Y += p.VY * dt
            if p.Kind == "spark" || p.Kind == "speck" || p.Kind == "crumb" { p.VY += 4 * dt }
            if p.Kind == "orange" { p.VY += 18 * dt; if p.Y >= 10.25 { p.Life = 0; Set("eat") } }
            if p.Life <= 0 && i < parts.count { parts.remove(at: i) }
            i -= 1
        }
        if state == "sleep" && now - lastSpawn > 1.4 { Spawn("z", 1); lastSpawn = now }
        if (state == "love" || state == "miss") && now - lastSpawn > 0.6 { Spawn("heart", 1); lastSpawn = now }
        if state == "music" && now - lastSpawn > 0.7 { Spawn("note", 1); lastSpawn = now }
        if state == "bell" && now - lastSpawn > 0.8 { Spawn("note", 1); lastSpawn = now }
        if state == "dance" && now - lastSpawn > 0.5 { Spawn("note", 1); lastSpawn = now }
        if state == "angry" && now - lastSpawn > 0.45 { Spawn("puff", 1); lastSpawn = now }
        if state == "eat" && now - lastSpawn > 0.4 { Spawn("crumb", 1); lastSpawn = now }
        let fest = Festival()
        if now - lastFestSpawn > 1.1 {
            lastFestSpawn = now
            if fest == "christmas" { Spawn("snow", 2) }
            else if (fest == "newyear" || fest == "birthday") && rnd.NextDouble() < 0.35 { Spawn("conf", 3) }
            else if (fest == "valentine" || fest == "qixi") && rnd.NextDouble() < 0.4 { Spawn("heart", 1) }
        }
        if (state == "work2" || state == "type") && now - lastSpawn > 0.35 { Spawn("code", 1); lastSpawn = now }
    }

    func Spawn(_ type: String, _ n: Int) {
        for i in 0..<n {
            let p = Particle(); p.Kind = type; p.Life = 1.2 + rnd.NextDouble() * 0.6
            let r1 = rnd.NextDouble(), r2 = rnd.NextDouble()
            switch type {
            case "spark":
                let left = i % 2 == 0
                p.X = left ? -2 + r1 * 3 : 14 + r1 * 2; p.Y = 2 + r2 * 5; p.VX = (left ? -1 : 1) * (0.5 + r1); p.VY = -2 - r2 * 2
                if i % 3 == 2 { p.Kind = "speck" }
            case "heart": p.X = 12 + r1 * 2; p.Y = 4; p.VX = 0.6; p.VY = -2
            case "z": p.X = 12.5; p.Y = 4; p.VX = 0.8; p.VY = -1.2; p.Life = 2.2
            case "note": p.X = rnd.Next(2) == 0 ? -1 : 14.5; p.Y = 5; p.VX = 0; p.VY = -2
            case "puff": p.X = rnd.Next(2) == 0 ? 1.5 : 12; p.Y = 4.5; p.VX = 0; p.VY = -1.8; p.Life = 0.9
            case "q": p.X = 13; p.Y = 3; p.VX = 0; p.VY = -0.8; p.Life = 1.4
            case "dust": let left = i % 2 == 0; p.X = left ? 1.5 : 12.5; p.Y = 14.5; p.VX = left ? -3.5 : 3.5; p.VY = -0.6; p.Life = 0.45
            case "crumb": p.X = 7 + r1; p.Y = 12; p.VX = (r2 - 0.5) * 3; p.VY = -1; p.Life = 0.7
            case "code": p.X = 8 + r1 * 5; p.Y = 9; p.VX = 0; p.VY = -2.2; p.Life = 0.7
            case "snow": p.X = -2 + r1 * 19; p.Y = -5; p.VX = (r2 - 0.5) * 0.6; p.VY = 1.2 + r2 * 0.6; p.Life = 9
            case "conf": p.X = 1 + r1 * 13; p.Y = -3 + r2 * 4; p.VX = Double(rnd.Next(5) - 2) * 0.01 + 0.001; p.VY = 1.5 + r2; p.Life = 2.2
            case "orange": p.X = 6.5; p.Y = -5; p.VX = 0; p.VY = 3; p.Life = 5
            default: break
            }
            parts.append(p)
        }
    }

    // ---------- 喂食 ----------
    func Feed() {
        Interact()
        if !Grounded() { return }
        if working { UserAct(6) }
        fed.removeAll { now - $0 > 1800 }
        if fed.count >= 4 { Set("dizzy"); Say("吃不下啦……肚子圆滚滚的～", 3); return }
        fed.append(now)
        AddAff(6); hunger = max(0, hunger - 40); SaveExtra(); today?.Feed += 1
        Set("catch")
        Spawn("orange", 1)
    }

    // ---------- 时间感知 ----------
    func Greet() {
        let h = Hour()
        let g = h < 5 ? Names.Nick + "，这么晚还没睡呀？我陪你。" : h < 11 ? "早上好 " + Names.Nick + "！今天也一起加油～" :
            h < 14 ? "中午好 " + Names.Nick + "！吃饭了吗？" : h < 18 ? "下午好 " + Names.Nick + "！AI 工作的时候我会陪你等着。" :
            h < 23 ? "晚上好 " + Names.Nick + "！今天辛苦啦。" : Names.Nick + "，这么晚还在忙呀？我陪你。"
        Say(g, 6); Set("wave")
        said.insert(Fmt(Date(), "yyyyMMdd") + "greet")
    }

    func TimeEvents() {
        if away || working || Idle.Seconds() > 120 { return }
        let d = Date()
        let day = Fmt(d, "yyyyMMdd")
        let h = Hour(d), m = Minute(d)
        let hm = Double(h) + Double(m) / 60.0
        if hm >= 6 && hm < 10.5 && Once(day + "morning") { Remind("早上好！新的一天开始啦～", "happy"); return }
        if hm >= 11.75 && hm < 13 && Once(day + "lunch") { Remind("中午啦，记得去吃饭哦！", "happy"); return }
        if hm >= 17.75 && hm < 19 && Once(day + "dinner") { Remind("该吃晚饭啦～别饿着肚子工作。", "happy"); return }
        if (h >= 23 || h < 2) && Once(day + "late" + String(h) + String(m / 30)) {
            afterStretch = "idle"; Set("stretch")
            Remind(Pick(["已经很晚啦，早点睡吧……", "呼啊……我都困了，你也去休息吧？", "熬夜对身体不好哦，明天再继续吧。"]), nil)
            return
        }
        let fest = festMode == "" ? Festival() : ""
        if fest != "" && Once(day + "fest") {
            if fest == "petbday" { Remind(PetBdayLine(), "party"); return }
            for f in FESTS() where f[0] == fest { Remind(f[2], fest == "christmas" || fest == "newyear" || fest == "birthday" ? "party" : "happy"); return }
        }
        if m == 0 && Once(day + "hour" + String(h)) && Calm() { Say(String(h) + " 点啦！", 4); Set("wink") }
    }

    func Once(_ key: String) -> Bool { if said.contains(key) { return false }; said.insert(key); return true }

    func Remind(_ line: String, _ mood: String?) {
        if let mood = mood { Set(mood) }
        Say(line, 8); Announce(line)
    }

    // 农历节日在公历上的日期（2026–2031）
    static let CNY = ["2026-02-17", "2027-02-06", "2028-01-26", "2029-02-13", "2030-02-03", "2031-01-23"]
    static let DUANWU = ["2026-06-19", "2027-06-09", "2028-05-28", "2029-06-16", "2030-06-05", "2031-06-24"]
    static let QIXI = ["2026-08-19", "2027-08-08", "2028-08-26", "2029-08-16", "2030-08-05", "2031-08-24"]
    static let ZHONGQIU = ["2026-09-25", "2027-09-15", "2028-10-03", "2029-09-22", "2030-09-12", "2031-10-01"]

    static func Near(_ d: Date, _ dates: [String], _ before: Int, _ after: Int) -> Bool {
        for s in dates {
            guard let c = ParseDate(s) else { continue }
            let diff = DaysBetween(c, d)
            if diff >= -before && diff <= after { return true }
        }
        return false
    }

    func FESTS() -> [[String]] {
        return [
            ["newyear", "元旦", "新年快乐！今年也请多多指教～"],
            ["cny", "春节", "过年好！新年快乐，红包拿来～"],
            ["lantern", "元宵节", "元宵节快乐！今天要吃汤圆哦～"],
            ["valentine", "情人节", "情人节快乐！我最喜欢你啦～"],
            ["children", "儿童节", "儿童节快乐！今天大家都是小朋友！"],
            ["dragonboat", "端午节", "端午安康！我想吃粽子～"],
            ["qixi", "七夕", "七夕快乐！喜鹊都来陪我啦～"],
            ["midautumn", "中秋节", "中秋快乐！月亮好圆，月饼好甜～"],
            ["national", "国庆节", "国庆快乐！放假啦，出去玩吧～"],
            ["halloween", "万圣节", "不给糖就捣蛋！嘿嘿～"],
            ["christmas", "圣诞节", "圣诞快乐！下雪啦～"],
            ["birthday", "生日", "生日快乐！今天你最大！"],
            ["petbday", Names.Pet + "的生日", "今天是我的生日！谢谢 " + Names.Nick + " 把我带到桌面上～"],
        ]
    }

    func Festival() -> String {
        if festMode == "off" { return "" }
        if festMode != "" { return festMode }
        let d = Date()
        let md = Fmt(d, "MM-dd")
        if birthday.count == 5 && md == birthday { return "birthday" }
        if md == PetBday() { return "petbday" }
        if PetForm.Near(d, PetForm.CNY, 7, 0) { return "cny" }                 // 除夕前一周到初一
        if PetForm.Near(d, PetForm.CNY, -1, 6) { return "cny" }                // 初二到初七
        if PetForm.Near(d, PetForm.CNY, -14, 14) { return "lantern" }          // 正月十五
        let mo = Month(d), dd = DayOf(d)
        if (mo == 12 && dd == 31) || (mo == 1 && dd <= 2) { return "newyear" }
        if mo == 2 && dd == 14 { return "valentine" }
        if mo == 6 && dd == 1 { return "children" }
        if PetForm.Near(d, PetForm.DUANWU, 1, 1) { return "dragonboat" }
        if PetForm.Near(d, PetForm.QIXI, 0, 0) { return "qixi" }
        if PetForm.Near(d, PetForm.ZHONGQIU, 2, 1) { return "midautumn" }
        if mo == 10 && dd <= 7 { return "national" }
        if (mo == 10 && dd >= 29) || (mo == 11 && dd <= 1) { return "halloween" }
        if mo == 12 && dd >= 20 && dd <= 26 { return "christmas" }
        return ""
    }

    func Hat() -> String {
        switch Festival() {
        case "newyear", "birthday", "petbday": return "party"
        case "cny", "lantern": return "cny"
        case "valentine": return "heartband"
        case "qixi": return "magpie"
        case "midautumn": return "bunny"
        case "halloween": return "witch"
        case "christmas": return "santa"
        case "dragonboat": return "band"
        default: break
        }
        let h = Hour()
        if h >= 23 || h < 6 { return "night" }
        return hatChoice
    }

    // 节日手里拿的东西（儿童节气球、元宵灯笼、端午粽子、中秋月饼、国庆小红旗、春节红包、生日蛋糕）
    func HeldItem() -> String {
        switch Festival() {
        case "cny": return "hongbao"
        case "lantern": return "lantern"
        case "children": return "balloon"
        case "dragonboat": return "zongzi"
        case "midautumn": return "mooncake"
        case "national": return "flag"
        case "birthday", "petbday": return "cake"
        case "halloween": return "candy"
        default: return ""
        }
    }

    func Say(_ text: String, _ seconds: Double) {
        if quiet { return }
        bubbleText = text; bubbleUntil = Now() + seconds
    }

    func ToggleSound() {
        muted = !muted
        let f = PathJoin(cfgDir, "mute.txt")
        if muted { FileX.Write(f, "1") } else { FileX.Delete(f) }
        if !muted { PlaySfx("happy"); Say("声音打开啦～", 3) }
        else { Say("好，我安安静静地陪着你。", 3) }
    }

    func Announce(_ text: String) {
        // 不用人声，只“叮”一声，话写在气泡里
        PlaySfx("ding")
    }

    static let MOODS: [String: String] = [
        "开心": "happy", "害羞": "shy", "爱心": "love", "生气": "angry", "难过": "sad", "惊讶": "surprised",
        "跳舞": "dance", "眨眼": "wink", "发呆": "daydream", "晕": "dizzy", "困": "stretch", "疑惑": "confused", "想你": "miss"]

    static func ParseMood(_ text0: String, _ mood: inout String) -> String {
        var text = text0.Trim
        if text.hasPrefix(Names.Pet + "：") || text.hasPrefix(Names.Pet + ":") { text = text.Sub(Names.Pet.count + 1).Trim }
        if text.count > 2 && (text.At(0) == "[" || text.At(0) == "【") {
            var end = -1
            for (i, c) in text.enumerated() { if c == "]" || c == "】" { end = i; break } }
            if end > 0 && end < 6 {
                let tag = text.Sub(1, end - 1)
                if let st = MOODS[tag] { mood = st }
                text = text.Sub(end + 1).Trim
            }
        }
        return text
    }

    func Reply(_ msg: String) {
        Interact(); lastChatAt = now; AddAff(2)
        guard let text = LocalThink(msg) else { LocalSearchReply(msg); return }
        if !working && Grounded() { Set("think") }
        Say("唔……", 3)
        chatting = true
        let delay = Double(500 + rnd.Next(700) + min(1200, msg.count * 30)) / 1000
        Later(delay) { [weak self] in self?.chatting = false; self?.PetSays(text) }
    }

    func Quit() {
        SaveState(); SaveDiary()
        NSApp.terminate(nil)
    }
}

var NAME: String { Names.Pet }
var NICK: String { Names.Nick }
