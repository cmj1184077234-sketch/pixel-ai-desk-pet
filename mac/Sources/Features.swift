import AppKit

final class DayStats {
    var Date = ""
    var Work = 0, WorkSec = 0, Pat = 0, Poke = 0, Feed = 0, Chat = 0, ActiveSec = 0, Pomo = 0
    var Note = ""
}

// ---------- 名字：在 config.txt 里改 pet_name / my_name / pet_desc ----------
enum Names {
    static var Pet = "叮叮"                       // 桌宠的名字
    static var Nick = "你"                        // 桌宠怎么称呼你
    static var Desc = "一只戴红蝴蝶结的像素小铃铛精，AI 干完活就摇响自己叫人"   // 一句话描述它自己（AI 聊天时会用）
    static var DataFolder = "PixelDeskPet"        // 记忆、造型等数据放在哪个文件夹
    static var Skin = ""                          // 默认用哪个整体形象
    static func Load(_ dir: String, _ example: String) {
        let f = PathJoin(dir, "config.txt")
        if !FileX.Exists(f) && FileX.Exists(example) { FileX.Copy(example, f) }   // 第一次运行：从模板生成自己的设置
        for line in FileX.Lines(f) {
            let i = line.IndexOf("=")
            if i <= 0 || line.Trim.hasPrefix("#") { continue }
            let k = line.Sub(0, i).Trim, v = line.Sub(i + 1).Trim
            if v == "" { continue }
            if k == "pet_name" { Pet = v }
            else if k == "my_name" { Nick = v }
            else if k == "pet_desc" { Desc = v }
            else if k == "skin" { Skin = v }
            else if k == "data_folder" && !v.contains("/") && !v.contains(":") { DataFolder = v }
        }
    }
}

extension PetForm {
    func InitFeatures() {
        ptext = PixelText(PathJoin(PathJoin(resDir, "assets"), "pixelfont.bin"))
        LoadExtra()
        LoadMemos()
        LoadReminders()
        NewDayIfNeeded()
        if weatherOn { Background { [weak self] in self?.WeatherLoop() } }
    }

    // ---------- 存档 ----------
    func ExtraFile() -> String { PathJoin(cfgDir, "xiaoc.txt") }

    func LoadExtra() {
        if FileX.Exists(ExtraFile()) {
            for line in FileX.Lines(ExtraFile()) {
                let i = line.IndexOf("="); if i < 0 { continue }
                let k = line.Sub(0, i), v = line.Sub(i + 1)
                if k == "met", let d = ParseDate(v) { metDate = d }
                if k == "hunger", let h = Int(v) { hunger = h }
                if k == "unlock", let u = Int(v) { unlockLevel = u }
                if k == "walk" && (v == "none" || v == "small" || v == "medium") { walkRangeSetting = v }
                if k == "chatfreq" && (v == "often" || v == "normal" || v == "rarely" || v == "off") { chatFreq = v }
            }
        } else { SaveExtra() }
        for line in FileX.Lines(PathJoin(dir, "config.txt")) where line.Trim.Lower.Replace(" ", "") == "weather=off" { weatherOn = false }
    }

    func SaveExtra() {
        FileX.Write(ExtraFile(), "met=" + Fmt(metDate, "yyyy-MM-dd") + "\nhunger=\(hunger)\nunlock=\(unlockLevel)\nwalk=" + walkRangeSetting + "\nchatfreq=" + chatFreq + "\n")
    }

    func DaysTogether() -> Int { DaysBetween(metDate, Date()) + 1 }

    // ---------- 每帧的额外事情 ----------
    func FeaturesTick(_ dt: Double) {
        NewDayIfNeeded()
        let idle = Idle.Seconds()
        if now - lastStatsSave > 1 {
            if idle < 120 && !away { today.ActiveSec += Int((now - lastStatsSave).rounded()) }
            if working { today.WorkSec += Int((now - lastStatsSave).rounded()) }
            if Int(now) % 60 == 0 { SaveDiary() }
            lastStatsSave = now
        }

        // 饿：大约 3 分钟饿 1 点
        if lastHungerTick == 0 { lastHungerTick = now }
        if now - lastHungerTick > 180 { lastHungerTick = now; hunger = min(100, hunger + 1); SaveExtra() }

        // 免打扰：前台是全屏窗口（看视频、开会、放 PPT）
        if now - lastQuietCheck > 2 {
            lastQuietCheck = now
            let q = manualQuiet || ForegroundFullscreen()
            if q != quiet {
                quiet = q
                win.alphaValue = quiet ? 0.3 : 1
                if quiet { quietSince = now; if Calm() || state == "talk" { Set("idle") } }
                else if pendingDone && !away {
                    pendingDone = false
                    let line = NICK + "，刚才你在忙的时候，AI 已经做完啦！"
                    Say(line, 8); Announce(line)
                }
            }
        }

        // 番茄钟
        if pomoEnd > 0 && now >= pomoEnd {
            pomoEnd = -1; today.Pomo += 1; breakEnd = now + 5 * 60
            Set("party")
            Remind(NICK + "，专注时间到！你好棒，休息 5 分钟吧～", nil)
        }
        if breakEnd > 0 && now >= breakEnd {
            breakEnd = -1
            Set("wave")
            Remind("休息结束啦，要不要再来一个番茄钟？", nil)
        }

        // 定时提醒
        var i = reminders.count - 1
        while i >= 0 {
            if Date() >= reminders[i].0 {
                let what = reminders[i].1
                reminders.remove(at: i); SaveReminders()
                signText = what
                if quiet { quiet = false; win.alphaValue = 1; lastQuietCheck = now + 60 }   // 提醒比免打扰重要，露面一分钟
                Set("sign")
                Say(NICK + "，到点啦：" + what + "！", 12)
                PlaySfx("dingdong")
            }
            i -= 1
        }

        // 亲密度解锁
        let lv = aff >= 80 ? 3 : aff >= 60 ? 2 : aff >= 40 ? 1 : 0
        if lv > unlockLevel {
            unlockLevel = lv; SaveExtra()
            let what = ["", "抛球杂耍和小白花头饰", "跳舞和小嫩芽头饰", "小皇冠头饰，还有走路时冒小爱心"]
            Set("party")
            Say("亲密度升级！解锁了" + what[lv] + "！", 6)
        }
    }

    func Unlocked(_ thing: String) -> Bool {
        switch thing {
        case "juggle", "flower": return unlockLevel >= 1
        case "dance", "sprout": return unlockLevel >= 2
        case "crown", "trail": return unlockLevel >= 3
        default: return true
        }
    }

    func ForegroundFullscreen() -> Bool {
        guard let fa = NSWorkspace.shared.frontmostApplication, fa.processIdentifier != myPid else { return false }
        if fa.bundleIdentifier == "com.apple.finder" { return false }
        // AI 自己的窗口（Claude、浏览器里的 AI 等）全屏时不算“在看视频”，提醒照常
        if Detector.AppLabel(fa.localizedName ?? "") != nil { return false }
        guard let w = WinList.FrontWindow() else { return false }
        let b = Scr.Bounds(Scr.FromPoint((w.rect.Left + w.rect.Right) / 2, (w.rect.Top + w.rect.Bottom) / 2))
        if w.rect.Left <= b.Left && w.rect.Top <= b.Top && w.rect.Right >= b.Right && w.rect.Bottom >= b.Bottom {
            if Detector.IsBrowser(fa.localizedName ?? "") {
                let ax = AXUIElementCreateApplication(fa.processIdentifier)
                if let fw = AX.Attr(ax, kAXFocusedWindowAttribute as String), Detector.AiLabel("chrome", AX.Str(fw as! AXUIElement, kAXTitleAttribute as String)) != nil { return false }
            }
            return true
        }
        return false
    }

    // ---------- 平时的小事（作息、饿、担心、回忆） 返回 true 表示已经安排了事情 ----------
    func FeatureIdle() -> Bool {
        if ringing { return true }
        if quiet || pomoEnd > 0 { nextIdleAct = 8; return true }
        let d = Date()
        let day = Fmt(d, "yyyyMMdd")
        let hm = Double(Hour(d)) + Double(Minute(d)) / 60.0
        if !away && hm >= 7 && hm < 9.5 && Grounded() && Once(day + "brush") { Set("brush"); Say("早上好 " + NICK + "！我先刷个牙～", 4); return true }
        if !away && hm >= 21 && hm < 22.5 && Grounded() && Once(day + "shower") { Set("shower"); Say("洗香香时间～", 4); return true }
        if hm >= 12.5 && hm < 14 && Grounded() && Idle.Seconds() > 60 && Once(day + "nap") { afterStretch = "sleep"; Set("stretch"); Say("呼啊……睡个午觉……", 3); return true }

        if hunger >= 70 && now - lastHungryAsk > 600 && !away {
            lastHungryAsk = now; Set("hungry")
            Say(Pick([NICK + "，我饿了……想吃橘子（右键可以喂我）", "咕噜噜……肚子在叫……", "有没有小橘子呀……"]), 5)
            return true
        }

        // 熬夜或者连续工作太久：变得黏人，过来看看你
        let late = Hour(d) < 5
        if !away && (late || now - activeSince > 3 * 3600) && rnd.NextDouble() < 0.35 && Grounded() {
            let c = Scr.Cursor
            StartWalk(c.X > posX ? 1 : -1, 6, c.X)
            Say(late ? Pick([NICK + "，好晚了，我有点担心你……", "再忙也要早点睡哦，我陪着你。"])
                     : Pick([NICK + "，你已经忙了好久了，眼睛累不累？", "歇一下嘛，我在这里陪你。"]), 5)
            return true
        }

        // 记得你说过的事
        if !away && !memos.isEmpty {
            for i in 0..<memos.count {
                guard let md = ParseDate(memos[i][0]) else { continue }
                let days = DaysBetween(md, Date())
                if days > 0 && days <= 7 {
                    let kw = memos[i][1]
                    memos.remove(at: i); SaveMemos()
                    Set("talk")
                    Say(NICK + "，之前说的" + kw + "怎么样啦？", 7)
                    return true
                }
            }
            memos.removeAll { m in if let x = ParseDate(m[0]) { return DaysBetween(x, Date()) > 7 }; return false }
        }

        // 天气
        if weatherKind != "" && rnd.NextDouble() < 0.08 && !away {
            let line = weatherKind == "rain" ? "外面在下雨，出门记得带伞哦～" : weatherKind == "snow" ? "下雪啦！出门穿暖和点～" :
                weatherKind == "hot" ? "今天好热，多喝水～" : "今天有点冷，别着凉啦～"
            Say(line, 5); Set("wave")
            return true
        }
        return false
    }

    // ---------- 离开与回来 ----------
    func ReturnFromAway(_ awayFor: Double) {
        if pendingDone {
            pendingDone = false
            Set("happy")
            let line = "欢迎回来 " + NICK + "！你不在的时候，AI 已经做完啦，快去看看吧！"
            Say(line, 10); Announce(line)
            return
        }
        if working { return }
        if awayFor > 3600 {
            if state == "sleep" { Set("surprised") }
            let c = Scr.Cursor
            if Grounded() { StartWalk(c.X > posX ? 1 : -1, 5, c.X) }
            walkGear = false
            let line = NICK + "！你终于回来了，我好想你～"
            Say(line, 6); Announce(line)
            AddAff(2)
        } else if awayFor > 600 {
            if state == "sleep" { Set("surprised") } else { Set("wave") }
            Say(Pick(["欢迎回来 " + NICK + "！", NICK + " 回来啦！我刚刚一直在等你。"]), 4)
        } else {
            if state == "sleep" { Set("surprised") } else { Set("wave") }
            Say("回来啦～", 3)
        }
    }

    // ---------- 天气（wttr.in，按网络位置大概判断） ----------
    func WeatherLoop() {
        while true {
            if let url = URL(string: "https://wttr.in/?format=%t|%C&lang=en") {
                var req = URLRequest(url: url, timeoutInterval: 20)
                req.setValue("curl/8.0", forHTTPHeaderField: "User-Agent")
                if let (data, _) = HttpSync(req), let s0 = String(data: data, encoding: .utf8) {
                    let p = s0.Trim.Split("|")
                    if p.count == 2 {
                        let temp = Int(RxMatch(p[0], "[-+]?\\d+")?[0] ?? "") ?? 20
                        let c = p[1].lowercased()
                        let kind = c.contains("snow") || c.contains("sleet") ? "snow" :
                            c.contains("rain") || c.contains("drizzle") || c.contains("shower") || c.contains("thunder") ? "rain" :
                            temp >= 30 ? "hot" : temp <= 8 ? "cold" : ""
                        OnMain { [weak self] in self?.weatherKind = kind; self?.weatherText = "\(temp)°C" }
                    }
                }
            }
            Thread.sleep(forTimeInterval: 30 * 60)
        }
    }

    // ---------- 日记 ----------
    func DiaryFile() -> String { PathJoin(dir, Names.Pet + "的日记.txt") }
    func DiaryData() -> String { PathJoin(cfgDir, "diary.txt") }

    func NewDayIfNeeded() {
        let d = Fmt(Date(), "yyyy-MM-dd")
        if today != nil && today.Date == d { return }
        if today != nil { SaveDiary() }
        today = nil
        for s in ReadDiary() where s.Date == d { today = s }
        if today == nil { today = DayStats(); today.Date = d }
        let days = DaysTogether()
        let marks = [7, 30, 100, 200, 365, 500, 520, 1000]
        if marks.contains(days) && Once(d + "anniv") {
            Set("party")
            Say("今天是我们认识的第 \(days) 天！" + NICK + "，谢谢你一直陪着我～", 8)
        }
    }

    func ReadDiary() -> [DayStats] {
        var list: [DayStats] = []
        for line in FileX.Lines(DiaryData()) {
            let p = line.Split("|")
            if p.count < 9 { continue }
            let s = DayStats()
            s.Date = p[0]
            s.Work = Int(p[1]) ?? 0; s.WorkSec = Int(p[2]) ?? 0; s.Pat = Int(p[3]) ?? 0
            s.Poke = Int(p[4]) ?? 0; s.Feed = Int(p[5]) ?? 0; s.Chat = Int(p[6]) ?? 0
            s.ActiveSec = Int(p[7]) ?? 0; s.Pomo = Int(p[8]) ?? 0
            if p.count > 9 { s.Note = p[9] }
            list.append(s)
        }
        return list
    }

    func SaveDiary() {
        guard let today = today else { return }
        var list = ReadDiary()
        list.removeAll { $0.Date == today.Date }
        list.append(today)
        list.sort { $0.Date < $1.Date }
        var sb = ""
        for s in list {
            sb += "\(s.Date)|\(s.Work)|\(s.WorkSec)|\(s.Pat)|\(s.Poke)|\(s.Feed)|\(s.Chat)|\(s.ActiveSec)|\(s.Pomo)|" + s.Note.Replace("|", " ").Replace("\n", " ") + "\n"
        }
        FileX.Write(DiaryData(), sb)
        var txt = ""
        for s in list.reversed() { txt += DiaryEntry(s) + "\n\n" }
        FileX.Write(DiaryFile(), txt)
    }

    func DiaryEntry(_ s: DayStats) -> String {
        let d = ParseDate(s.Date) ?? Date()
        let wk = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
        var sb = "【" + Fmt(d, "M月d日") + " " + wk[Cal.component(.weekday, from: d) - 1] + "】\n"
        let h = s.ActiveSec / 3600, mi = (s.ActiveSec % 3600) / 60
        if s.ActiveSec > 60 { sb += "今天 " + NICK + " 在电脑前待了" + (h > 0 ? "\(h) 小时 " : "") + "\(mi) 分钟。\n" }
        if s.Work > 0 { sb += "AI 工作了 \(s.Work) 次，一共 \(max(1, s.WorkSec / 60)) 分钟，我都在旁边帮忙盯着！\n" }
        if s.Pomo > 0 { sb += "我们一起完成了 \(s.Pomo) 个番茄钟，" + NICK + " 好认真。\n" }
        if s.Pat > 0 { sb += NICK + " 摸了我的头 \(s.Pat) 下，好开心～\n" }
        if s.Poke > 0 { sb += "被戳了 \(s.Poke) 下" + (s.Poke > 10 ? "，头都晕了！" : "。") + "\n" }
        if s.Feed > 0 { sb += "吃了 \(s.Feed) 个小橘子，甜甜的。\n" }
        if s.Chat > 0 { sb += "和 " + NICK + " 聊了 \(s.Chat) 句。\n" }
        if s.Note != "" { sb += s.Note + "\n" }
        if sb.Split("\n").count <= 2 { sb += "今天比较安静，我自己玩了一会儿。\n" }
        return sb.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func ShowDiary() {
        SaveDiary()
        let list = ReadDiary()
        var sb = "这是我认识 " + NICK + " 的第 \(DaysTogether()) 天。\n\n"
        var i = list.count - 1
        while i >= 0 && i >= list.count - 30 { sb += DiaryEntry(list[i]) + "\n\n"; i -= 1 }
        PixelWindow.Show(self, NAME + "的日记", sb)
    }

    // ---------- 记住你说过的事 ----------
    static let EVENT_WORDS = ["考试", "截稿", "交稿", "交作业", "作业", "论文", "答辩", "开题", "中期", "面试", "展览", "布展", "汇报", "比赛", "ddl", "DDL", "deadline", "演出", "旅行", "搬家"]

    func LoadMemos() {
        for line in FileX.Lines(PathJoin(cfgDir, "memos.txt")) { let p = line.Split("|"); if p.count >= 3 { memos.append(p) } }
    }

    func SaveMemos() {
        var sb = ""
        for m in memos { sb += m[0] + "|" + m[1] + "|" + m[2].Replace("|", " ") + "\n" }
        FileX.Write(PathJoin(cfgDir, "memos.txt"), sb)
    }

    @discardableResult func NoteEvent(_ msg: String) -> String? {
        for w in PetForm.EVENT_WORDS where msg.contains(w) {
            memos.removeAll { $0[1] == w }
            memos.append([Fmt(Date(), "yyyy-MM-dd"), w, msg])
            SaveMemos()
            if today != nil && today.Note.count < 60 { today.Note = (today.Note + " " + NICK + " 提到了" + w + "，我记下来了。").Trim }
            return w
        }
        return nil
    }

    // ---------- 提醒 ----------
    func LoadReminders() {
        for line in FileX.Lines(PathJoin(cfgDir, "reminders.txt")) {
            let i = line.IndexOf("|")
            if i < 0 { continue }
            if let d = ParseDate(line.Sub(0, i)) { reminders.append((d, line.Sub(i + 1))) }
        }
    }

    func SaveReminders() {
        var sb = ""
        for r in reminders { sb += Fmt(r.0, "yyyy-MM-dd HH:mm:ss") + "|" + r.1 + "\n" }
        FileX.Write(PathJoin(cfgDir, "reminders.txt"), sb)
    }

    // 认得这些说法："10分钟后提醒我喝水"、"3点提醒我交作业"、"下午3点半提醒我开会"、"15:30 提醒我…"、"明天9点提醒我…"
    static func ParseReminder(_ msg: String, _ when: inout Date, _ what: inout String) -> Bool {
        let k = msg.IndexOf("提醒我")
        if k < 0 { return false }
        what = msg.Sub(k + 3).trimmingCharacters(in: CharacterSet(charactersIn: " ，,。！!~～"))
        let head = msg.Sub(0, k)
        if what == "" { what = "该做事啦" }
        let m = RxMatch(head, "(\\d+)\\s*(分钟|分|min)")
        let h = RxMatch(head, "(\\d+)\\s*(个)?小时")
        if h != nil || (m != nil && head.contains("后")) {
            var w = Date()
            if let h = h { w = w.addingTimeInterval(Double(Int(h[1]) ?? 0) * 3600) }
            if let m = m { w = w.addingTimeInterval(Double(Int(m[1]) ?? 0) * 60) }
            when = w
            return w > Date()
        }
        if let t = RxMatch(head, "(\\d{1,2})\\s*[:：点]\\s*(半|\\d{1,2})?") {
            var hh = Int(t[1]) ?? 0, mm = 0
            if t[2] != "" { mm = t[2] == "半" ? 30 : (Int(t[2]) ?? 0) }
            if (head.contains("下午") || head.contains("晚上") || head.contains("傍晚")) && hh < 12 { hh += 12 }
            if hh > 23 || mm > 59 { return false }
            var d = Today().addingTimeInterval(Double(hh) * 3600 + Double(mm) * 60)
            if head.contains("明天") { d = AddDays(d, 1) }
            else if d <= Date() {
                if hh < 12 && !head.contains("上午") && !head.contains("早") && d.addingTimeInterval(12 * 3600) > Date() { d = d.addingTimeInterval(12 * 3600) }
                else { d = AddDays(d, 1) }
            }
            when = d
            return true
        }
        return false
    }

    func AddReminder(_ when: Date, _ what: String) {
        reminders.append((when, what))
        SaveReminders()
    }

    func AskReminder() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "让" + Names.Pet + "提醒你"
        a.informativeText = "什么时候（15:30 / 10分钟后 / 明天9点），提醒什么"
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 58))
        let t1 = NSTextField(frame: NSRect(x: 0, y: 32, width: 300, height: 24)); t1.placeholderString = "什么时候，比如 15:30"
        let t2 = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24)); t2.placeholderString = "提醒什么，比如 喝水"
        v.addSubview(t1); v.addSubview(t2)
        a.accessoryView = v
        a.addButton(withTitle: "好的"); a.addButton(withTitle: "算了")
        a.window.initialFirstResponder = t1
        if a.runModal() == .alertFirstButtonReturn && t1.stringValue.Trim != "" {
            ReminderFromWindow(t1.stringValue, t2.stringValue.Trim == "" ? "该做事啦" : t2.stringValue.Trim)
        }
    }

    func ReminderFromWindow(_ timeText: String, _ what: String) {
        var when = Date(), w2 = ""
        var msg = timeText.Trim
        if RxIsMatch(msg, "^\\d+$") { msg += "分钟后" }
        if !PetForm.ParseReminder(msg + "提醒我" + what, &when, &w2) {
            Say("唔，我没看懂这个时间……试试「15:30」或「10分钟后」", 5); Set("confused")
            return
        }
        AddReminder(when, w2)
        Set("wink")
        Say("记住啦！" + PetForm.FormatWhen(when) + "提醒你：" + w2, 5)
    }

    static func FormatWhen(_ d: Date) -> String {
        let dd = DaysBetween(Date(), d)
        let day = dd == 0 ? "" : dd == 1 ? "明天 " : Fmt(d, "M月d日 ")
        return day + Fmt(d, "HH:mm") + " "
    }

    // ---------- 番茄钟 ----------
    func StartPomo(_ minutes: Int) {
        Interact()
        pomoMinutes = minutes; pomoEnd = now + Double(minutes) * 60; breakEnd = -1
        Set("wave")
        Say("好！专注 \(minutes) 分钟，我陪你一起～", 4)
    }

    func StopPomo() {
        pomoEnd = -1; breakEnd = -1
        Say("番茄钟停下来啦。", 3)
    }

    // ---------- 聊天 ----------
    func OpenChatWindow() {
        Interact()
        if state == "sulk" { Forgive() }
        if chatWin == nil {
            chatWin = ChatWindow(self)
            let st2 = max(0, chatLog.count - 60)
            for i in st2..<chatLog.count { chatWin!.AddLine(chatLog[i][0], chatLog[i][1]) }
            if chatLog.isEmpty { chatWin!.AddLine(NAME, HasAI() ? "嗨 " + Names.Nick + "！想聊什么都可以。我能帮你查资料，也能帮你在电脑上做事，还能给自己画新造型～" : "嗨 " + Names.Nick + "！想聊什么都可以～也可以说「10分钟后提醒我喝水」。") }
        }
        NSApp.activate(ignoringOtherApps: true)
        chatWin!.makeKeyAndOrderFront(nil)
        chatWin!.FocusInput()
    }

    func UserSays(_ msg: String) {
        chatLog.append([NICK, msg])
        chatWin?.AddLine(NICK, msg)
        today?.Chat += 1
        NoteEvent(msg)
        if HasAI() { AgentChat(msg, nil); return }
        if !localHintShown {
            localHintShown = true
            ChatNote("（没接 AI 时，" + Names.Pet + " 靠自己的小脑袋聊天：会记住你说的事、读懂心情、接着话头问，知识类问题会去网上搜给你看。想让它真正理解你、帮你在电脑上做事，可以在右键「AI 设置…」接上 AI）")
        }
        var when = Date(), what = ""
        if PetForm.ParseReminder(msg, &when, &what) {
            AddReminder(when, what)
            PetSays("[眨眼] 记住啦！" + PetForm.FormatWhen(when) + "我会提醒你" + what + "～")
            return
        }
        Reply(msg)
    }

    func UserSendsImage(_ path: String, _ caption0: String) {
        let caption = caption0 == "" ? "你看看这张图" : caption0
        chatLog.append([NICK, "[图片] " + caption])
        chatWin?.AddLine(NICK, "[图片] " + caption)
        today?.Chat += 1
        if HasAI() { AgentChat(caption, path); return }
        PetSays("[疑惑] 我现在还看不懂图片……右键「AI 设置…」填好 key，我就能看啦。")
    }

    static func PlainText(_ t0: String) -> String {
        var t = t0.Replace("**", "").Replace("__", "").Replace("`", "")
        t = RxReplace(t, "^\\s*#{1,6}\\s*", "", multiline: true)
        t = RxReplace(t, "^\\s*[-*]\\s+", "· ", multiline: true)
        t = RxReplace(t, "\\[([^\\]]+)\\]\\((https?://[^)]+)\\)", "$1 $2")
        return t.Trim
    }

    // 闲聊时像真人一样分几条发：用空行隔开、每段都短的回复，拆成几条消息，隔一小会儿一条
    func PetSays(_ raw: String) {
        var mood0 = "talk"
        let all = PetForm.PlainText(PetForm.ParseMood(raw, &mood0)).Replace("\r\n", "\n").Trim
        let parts = RxSplit(all, "\\n\\s*\\n")
        var split = parts.count >= 2 && parts.count <= 3 && !all.contains("http") && !all.contains("· ")
        if split { for pp in parts where pp.Trim.isEmpty || pp.Trim.count > 70 || pp.contains("\n") { split = false } }
        if sayTimer != nil { sayTimer!.invalidate(); sayTimer = nil; for q in pendingSays { PetSaysOne(q) }; pendingSays.removeAll() }   // 上一轮还没发完的先发掉
        if !split { PetSaysOne(raw); return }
        let head = raw.Trim.hasPrefix("[") && raw.IndexOf("]") > 0 ? raw.Sub(0, raw.IndexOf("]") + 1) + " " : ""
        PetSaysOne(head + parts[0].Trim)
        for i in 1..<parts.count { pendingSays.append(parts[i].Trim) }
        ScheduleNextSay()
    }

    func ScheduleNextSay() {
        guard !pendingSays.isEmpty else { return }
        let iv = Double(min(2200, 700 + pendingSays[0].count * 45)) / 1000
        sayTimer = Timer.scheduledTimer(withTimeInterval: iv, repeats: false) { [weak self] _ in self?.NextSay() }
    }

    func NextSay() {
        sayTimer = nil
        if pendingSays.isEmpty { return }
        let q = pendingSays.removeFirst()
        PetSaysOne(q)
        ScheduleNextSay()
    }

    func PetSaysOne(_ raw: String) {
        var mood = "talk"
        let text = PetForm.PlainText(PetForm.ParseMood(raw, &mood))
        chatLog.append([NAME, text])
        if chatLog.count > 200 { chatLog.removeFirst(chatLog.count - 200) }
        if chatWin == nil || !chatWin!.isKeyWindow { PlaySfx("pop") }
        chatWin?.AddLine(NAME, text)
        if !working && Grounded() { Set(mood) }
        var bubble = text
        let cut = bubble.IndexOf("\n")
        if cut > 0 && cut < 60 { bubble = bubble.Sub(0, cut) }
        let chatOpen = chatWin != nil && chatWin!.isVisible
        if bubble.count > 54 { bubble = bubble.Sub(0, 50) + "…" + (chatOpen ? "" : "（右键「和" + Names.Pet + "聊天」看全部）") }
        else if bubble != text { bubble += "…" }
        Say(bubble, max(5, min(14, Double(bubble.count) * 0.25)))
    }

    func ContextForModel() -> String {
        var sb = "现在是 " + Fmt(Date(), "M月d日 HH:mm") + "。"
        sb += "你认识 " + Names.Nick + " 第 \(DaysTogether()) 天，亲密度 \(aff)/100，饥饿 \(hunger)/100。"
        if weatherText != "" { sb += "外面 " + weatherText + "。" }
        if let t = today { sb += "今天 AI 工作了 \(t.Work) 次，" + Names.Nick + " 摸了你 \(t.Pat) 下。" }
        if !memos.isEmpty {
            sb += Names.Nick + " 最近提到过："
            for m in memos { sb += m[0] + " " + m[2] + "；" }
        }
        return sb
    }

    // ---------- 额外的画 ----------
    func DrawProp2(_ prop: String, _ t: Double, _ n: Double, _ fx: Double, _ fy: Double, _ dx: Double, _ dy: Double) {
        switch prop {
        case "bell":
            // 举着金色小铃铛左右摇
            let sw = SeqD(n, 0.12, [-0.4, 0.4])
            let hx = 14 + dx + sw * 0.3, hy = 4.5 + dy
            U(hx, hy, 2, 2, BODY)
            U(hx + 0.75, hy + 2, 0.5, 0.5, HARDHAT_D)
            U(hx + 0.25 + sw, hy + 2.5, 1.5, 0.5, GOLD)
            U(hx + sw, hy + 3, 2, 1, GOLD)
            U(hx - 0.25 + sw, hy + 4, 2.5, 0.5, GOLD)
            U(hx + 0.5 + sw, hy + 3, 0.25, 0.75, PAPER)
            U(hx + 0.75 + sw * 1.6, hy + 4.5, 0.5, 0.5, HARDHAT_D)
            // 声音的小波纹
            let wx = sw < 0 ? hx - 1.25 : hx + 3
            let dir: Double = sw < 0 ? -1 : 1
            U(wx, hy + 2.75, 0.25, 1, EDGE)
            U(wx + dir * 0.75, hy + 2.25, 0.25, 2, EDGE)
        case "toothbrush":
            let sc = SeqD(n, 0.15, [0, 0.5])
            U(-1.5 + dx + sc, 10.25 + dy, 4.5, 0.5, BOOK); U(2.5 + dx + sc, 9.75 + dy, 1, 0.5, PAPER)
            U(0.25 + dx + sc, 10.5 + dy, 1.75, 1.5, BODY)
            for i in 0..<3 { U(5.5 + Double(i) * 1.5 + ((n * 3 + Double(i)) % 1) * 0.5, 11 + sin(n * 5 + Double(i)) * 0.25, 0.75, 0.75, PAPER) }
        case "shower":
            U(4, -3, 7, 1, NAIL); U(7, -4.5, 1, 1.5, NAIL); U(4.5, -2, 6, 0.5, NAIL)
            for i in 0..<6 {
                let a = ((n * 2.2) + Double(i) * 0.17) % 1.0
                U(4.75 + Double(i), -1.25 + a * 6.5, 0.25, 0.75, TEAR)
            }
            U(3 + sin(n * 2) * 0.5, 5, 1.25, 1.25, PAPER); U(10.5, 4.75 + sin(n * 3) * 0.25, 1, 1, PAPER); U(6, 4.5, 0.75, 0.75, PAPER)
        case "belly":
            U(5 + fx, 11 + fy, 1.75, 1.75, BODY_D); U(8.25 + fx, 11 + fy, 1.75, 1.75, BODY_D)
            if Seq(n, 0.5, [0, 1]) == 0 { PixText("咕~", 12.5, 6.5, 2, EYE, true) }
        case "sign":
            // 举着小牌子：上面写着要提醒的事
            let s = signText.count > 8 ? signText.Sub(0, 8) + "…" : signText
            let bob = SeqD(n, 0.4, [0, -0.25])
            U(1.25 + dx, -0.5 + dy + bob, 0.5, 7.5, WOOD); U(13.25 + dx, -0.5 + dy + bob, 0.5, 7.5, WOOD)
            U(-0.75 + dx, -4.75 + dy + bob, 16.5, 4.5, WOOD); U(-0.5 + dx, -4.5 + dy + bob, 16, 4, PAPER)
            PixText(s, 0, -4.25 + dy + bob, TextPx() == 24 ? 3 : 2.25, EYE, true)
        default: break
        }
    }

    // 天气的小物件、番茄钟计时牌、亲密度满的爱心尾巴
    func DrawExtras(_ n: Double, _ fx: Double, _ fy: Double, _ dx: Double, _ dy: Double, _ busyHands: Bool) {
        if !busyHands && state != "sign" && state != "shower" && state != "sulk" && state != "dizzy" {
            if weatherKind == "rain" && (state == "walk" || state == "idle" || state == "sit") {
                U(14.25 + dx, 0 + dy, 0.25, 9.5, WOOD)
                U(9.5 + dx, -1 + dy, 9.5, 1, BOOK); U(10.5 + dx, -1.75 + dy, 7.5, 0.75, BOOK); U(12.5 + dx, -2.25 + dy, 3.5, 0.5, BOOK)
                U(14 + dx, 9 + dy, 0.75, 0.5, WOOD)
                for i in 0..<4 { let a = ((n * 1.8) + Double(i) * 0.3) % 1.0; U(-1 + Double(i) * 5, -4 + a * 18, 0.25, 0.6, TEAR) }
            } else if weatherKind == "hot" && (state == "idle" || state == "sit") {
                U(-0.5 + dx, 6.5 + dy, 1.75, 3, POPSICLE); U(-0.5 + dx, 6.5 + dy, 1.75, 0.75, POPSICLE_HI); U(0.125 + dx, 9.5 + dy, 0.5, 1.5, WOOD)
            }
            if weatherKind == "cold" || weatherKind == "snow" {
                U(2 + fx, 11.5 + fy, 11, 1, SCARF); U(10 + fx, 12.5 + fy, 1.25, 2, SCARF); U(10 + fx, 13.25 + fy, 1.25, 0.25, PAPER)
            }
        }
        if pomoEnd > 0 {
            let left = max(0, Int(pomoEnd - now))
            let s = String(format: "%02d:%02d", left / 60, left % 60)
            U(-3.25, 1.5, 5.5, 2.5, WOOD); U(-3, 1.75, 5, 2, BOX); U(-1, 4, 0.5, 3, WOOD)
            PixText(s, -3, 1.75, TextPx() == 24 ? 2 : 1.6, EYE, false)
        }
        if state == "walk" && Unlocked("trail") && aff >= 80 && Seq(n, 0.6, [0, 1, 1]) == 0 { Bits(HEART, walkDir > 0 ? -1.5 : 15, 9, 0.3, PINK) }
    }
}

// ---------- 同步发网络请求（在后台线程里用） ----------
func HttpSync(_ req: URLRequest) -> (Data, HTTPURLResponse)? {
    var out: (Data, HTTPURLResponse)? = nil
    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: req) { d, r, _ in
        if let d = d, let r = r as? HTTPURLResponse { out = (d, r) }
        sem.signal()
    }.resume()
    _ = sem.wait(timeout: .now() + req.timeoutInterval + 5)
    return out
}

// ---------- 像素字（Fusion Pixel 12px 预先栅格化成点阵，自己一格一格画，保证每个字都是清晰的像素） ----------
final class PixelText {
    var glyphs: [UInt32: [UInt16]] = [:]
    var advs: [UInt32: Int] = [:]
    var Loaded = false

    init(_ path: String) {
        guard let b = FileManager.default.contents(atPath: path), b.count > 4 else { return }
        let bytes = [UInt8](b)
        func u16(_ p: Int) -> Int { Int(bytes[p]) | (Int(bytes[p + 1]) << 8) }
        let n = Int(bytes[0]) | (Int(bytes[1]) << 8) | (Int(bytes[2]) << 16) | (Int(bytes[3]) << 24)
        var p = 4
        for _ in 0..<n {
            if p + 3 + 24 > bytes.count { break }
            let cp = UInt32(u16(p)); let adv = Int(bytes[p + 2]); p += 3
            var rows = [UInt16](repeating: 0, count: 12)
            for r in 0..<12 { rows[r] = UInt16(u16(p)); p += 2 }
            glyphs[cp] = rows; advs[cp] = adv
        }
        Loaded = n > 0
    }

    func Key(_ c: Character) -> UInt32 { c.unicodeScalars.first?.value ?? 32 }

    func Adv(_ c: Character) -> Int {
        if let a = advs[Key(c)] { return a }
        return Key(c) < 128 ? 6 : 12
    }

    func Wrap(_ text: String, _ maxPx: Int, _ scale: Int) -> [String] {
        var lines: [String] = []
        for para in text.Replace("\r", "").Split("\n") {
            var cur: [Character] = []; var w = 0
            for c in para {
                let a = Adv(c) * scale
                if w + a > maxPx && !cur.isEmpty {
                    // 标点不放在行首
                    if "，。！？、：；）》」』～,.!?:;)".contains(c) && cur.count > 1 {
                        let last = cur.removeLast()
                        lines.append(String(cur)); cur = [last]; w = Adv(last) * scale
                    } else { lines.append(String(cur)); cur = []; w = 0 }
                }
                cur.append(c); w += a
            }
            lines.append(String(cur))
        }
        return lines
    }

    func Width(_ s: String, _ scale: Int) -> Int { s.reduce(0) { $0 + Adv($1) * scale } }
    func LineH(_ scale: Int) -> Int { 14 * scale }

    func Measure(_ text: String, _ maxPx: Int, _ scale: Int) -> (Int, Int) {
        let lines = Wrap(text, maxPx, scale)
        let w = lines.map { Width($0, scale) }.max() ?? 0
        return (w, lines.count * LineH(scale) - 2 * scale)
    }

    func DrawLine(_ g: CGContext, _ s: String, _ x0: Int, _ y: Int, _ scale: Int, _ b: Brush) {
        var x = x0
        g.setFillColor(b.color)
        for c in s {
            if let rows = glyphs[Key(c)] {
                for r in 0..<12 {
                    var v = Int(rows[r]); var bit = 0
                    while v != 0 && bit < 16 {
                        if v & 1 != 0 {
                            let start = bit
                            while v & 1 != 0 { v >>= 1; bit += 1 }
                            g.fill(CGRect(x: x + start * scale, y: y + r * scale, width: (bit - start) * scale, height: scale))
                        } else { v >>= 1; bit += 1 }
                    }
                }
            } else if c != " " {
                // 字库里没有的字，用系统字体补上
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: g, flipped: true)
                (String(c) as NSString).draw(at: NSPoint(x: x, y: y - scale), withAttributes: [.font: NSFont.systemFont(ofSize: CGFloat(11 * scale)), .foregroundColor: b.ns])
                NSGraphicsContext.restoreGraphicsState()
                g.setFillColor(b.color)
            }
            x += Adv(c) * scale
        }
    }

    func Draw(_ g: CGContext, _ text: String, _ x: Int, _ y0: Int, _ scale: Int, _ b: Brush, _ maxPx: Int) -> Int {
        let lines = Wrap(text, maxPx, scale)
        var y = y0
        for l in lines { DrawLine(g, l, x, y, scale, b); y += LineH(scale) }
        return lines.count
    }
}

// 像素字的滚动文字面板：聊天记录和日记都用它
final class PixelView: NSView {
    let pt: PixelText; let scale: Int; let stickBottom: Bool
    var items: [(NSColor, String)] = []
    var scroll = 0
    var links: [(CGRect, String)] = []
    var bg = NSColor(srgbRed: 1, green: 248 / 255, blue: 231 / 255, alpha: 1)
    override var isFlipped: Bool { true }

    init(_ p: PixelText, _ sc: Int, _ bottom: Bool) { pt = p; scale = sc; stickBottom = bottom; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }

    static func FirstUrl(_ t: String) -> String? {
        guard let m = RxMatch(t, "https?://[^\\s，。）)\"'<>]+") else { return nil }
        return m[0].trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
    }

    override func scrollWheel(with e: NSEvent) {
        let step = Int(e.scrollingDeltaY.rounded()) * (e.hasPreciseScrollingDeltas ? 1 : pt.LineH(scale))
        scroll = max(0, stickBottom ? scroll + step : scroll - step)
        needsDisplay = true
    }

    override func mouseDown(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        for l in links where l.0.contains(p) { OpenUrl(l.1); return }
    }

    override func resetCursorRects() { for l in links { addCursorRect(l.0, cursor: .pointingHand) } }

    func Add(_ c: NSColor, _ text: String) { items.append((c, text)); if stickBottom { scroll = 0 }; needsDisplay = true }
    func SetText(_ c: NSColor, _ text: String) { items = [(c, text)]; scroll = 0; needsDisplay = true }

    override func draw(_ r: NSRect) {
        guard let g = NSGraphicsContext.current?.cgContext else { return }
        g.setFillColor(bg.cgColor); g.fill(bounds)
        g.setShouldAntialias(false)
        let lh = pt.LineH(scale), maxW = Int(bounds.width) - 8, H = Int(bounds.height)
        var lines: [(NSColor, String)] = []
        var lineUrl: [String?] = []
        for it in items {
            let url = PixelView.FirstUrl(it.1)
            for l in pt.Wrap(it.1, maxW, scale) { lines.append((it.0, l)); lineUrl.append(url) }
            lines.append((it.0, "")); lineUrl.append(nil)
        }
        links.removeAll()
        let total = lines.count * lh
        let maxScroll = max(0, total - H + 8)
        if scroll > maxScroll { scroll = maxScroll }
        let y0 = stickBottom ? min(4, H - 4 - total) + scroll : 4 - scroll
        for i in 0..<lines.count {
            let y = y0 + i * lh
            if y + lh < 0 || y > H { continue }
            let col = lineUrl[i] != nil ? RGB(60, 110, 190) : lines[i].0
            pt.DrawLine(g, lines[i].1, 4, y, scale, Brush(col))
            if let u = lineUrl[i], lines[i].1 != "" { links.append((CGRect(x: 4, y: y, width: pt.Width(lines[i].1, scale), height: lh), u)) }
        }
        window?.invalidateCursorRects(for: self)
    }
}

// ---------- 聊天窗口 ----------
final class ChatWindow: NSWindow, NSTextFieldDelegate {
    weak var pet: PetForm?
    var log: PixelView!
    var input: NSTextField!
    static let BG = RGB(255, 248, 231), INK = RGB(60, 50, 45), PETC = RGB(200, 95, 70), ME = RGB(70, 110, 170), NOTE = RGB(150, 140, 130)

    init(_ p: PetForm) {
        pet = p
        let W: CGFloat = 460, H: CGFloat = 460
        super.init(contentRect: NSRect(x: 0, y: 0, width: W, height: H), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        title = "和" + Names.Pet + "聊天"
        level = .floating
        backgroundColor = ChatWindow.BG
        minSize = NSSize(width: 360, height: 300)
        let cv = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        contentView = cv
        log = PixelView(p.ptext, 2, true)
        log.bg = ChatWindow.BG
        log.frame = NSRect(x: 12, y: 74, width: W - 24, height: H - 84)
        log.autoresizingMask = [.width, .height]
        input = NSTextField(frame: NSRect(x: 12, y: 30, width: W - 164, height: 32))
        input.font = NSFont.systemFont(ofSize: 14)
        input.placeholderString = "想说什么？Enter 发送"
        input.delegate = self
        input.autoresizingMask = [.width]
        let img = NSButton(title: "图片", target: self, action: #selector(PickImage))
        img.frame = NSRect(x: W - 146, y: 28, width: 64, height: 36); img.autoresizingMask = [.minXMargin]
        let send = NSButton(title: "发送", target: self, action: #selector(Send))
        send.frame = NSRect(x: W - 78, y: 28, width: 66, height: 36); send.autoresizingMask = [.minXMargin]
        send.keyEquivalent = "\r"
        let tip = NSTextField(labelWithString: "可以让" + Names.Pet + "查资料、帮你在电脑上做事、给自己画新造型")
        tip.font = NSFont.systemFont(ofSize: 11); tip.textColor = ChatWindow.NOTE
        tip.frame = NSRect(x: 12, y: 6, width: W - 24, height: 18); tip.autoresizingMask = [.width]
        for v in [log!, input!, img, send, tip] as [NSView] { cv.addSubview(v) }
        // 放在桌宠旁边
        let pr = p.win.frame
        var o = NSPoint(x: pr.midX - W / 2, y: pr.minY + 120)
        if let vf = p.win.screen?.visibleFrame {
            o.x = max(vf.minX, min(vf.maxX - W, o.x)); o.y = max(vf.minY, min(vf.maxY - H - 30, o.y))
        }
        setFrameOrigin(o)
    }

    func FocusInput() { makeFirstResponder(input) }

    func SetStatus(_ s: String) { title = s == "" ? "和" + Names.Pet + "聊天" : "和" + Names.Pet + "聊天 · " + s }

    func AddLine(_ who: String, _ text: String) {
        if who == "" { log.Add(ChatWindow.NOTE, text) }
        else { log.Add(who == Names.Nick ? ChatWindow.ME : ChatWindow.PETC, who + "：" + text) }
    }

    @objc func Send() {
        let msg = input.stringValue.Trim
        if msg == "" { return }
        input.stringValue = ""
        pet?.UserSays(msg)
    }

    @objc func PickImage() {
        let dlg = NSOpenPanel()
        dlg.title = "选一张图片给" + Names.Pet + "看"
        dlg.allowedFileTypes = ["jpg", "jpeg", "png", "bmp", "gif", "webp", "heic", "tiff"]
        guard dlg.runModal() == .OK, let u = dlg.url else { return }
        let cap = input.stringValue.Trim
        input.stringValue = ""
        pet?.UserSendsImage(u.path, cap)
    }

    func control(_ c: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.insertNewline(_:)) { Send(); return true }
        return false
    }
}

// ---------- 只读的像素风文字窗（日记） ----------
enum PixelWindow {
    static var open: [NSWindow] = []
    static func Show(_ owner: PetForm, _ title: String, _ body: String) {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 520), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.title = title
        let box = PixelView(owner.ptext, 2, false)
        box.frame = NSRect(x: 16, y: 14, width: 448, height: 492)
        box.autoresizingMask = [.width, .height]
        box.SetText(RGB(60, 50, 45), body)
        let cv = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 520))
        cv.wantsLayer = true; cv.layer?.backgroundColor = RGB(255, 248, 231).cgColor
        cv.addSubview(box)
        w.contentView = cv
        w.center()
        open.append(w)
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}
