import AppKit

// ---------- 右键菜单（每次右键都重新生成，勾选状态总是最新的） ----------
extension PetForm {
    func BuildMenu() -> NSMenu {
        let m = NSMenu(title: Names.Pet)
        m.autoenablesItems = false
        let h = max(0, min(5, (aff + 10) / 20))
        m.Add("亲密度  " + String(repeating: "♥", count: h) + String(repeating: "♡", count: 5 - h) + "  (\(aff))", enabled: false)
        m.Add("认识 " + NICK + " 的第 \(DaysTogether()) 天" + (weatherText != "" ? "  ·  " + weatherText : "") + (hunger >= 70 ? "  ·  饿了" : "") +
              (manualWork ? "  ·  手动工作模式开着" : detectedBusy ? "  ·  " + busyApp + " 正在工作" : ""), enabled: false)
        if detectedBusy && !manualWork { m.Add("「" + busyApp + "」其实没在工作（别再认错了）") { [weak self] in self?.IgnoreCurrentButton() } }
        if !AX.Trusted(prompt: false) { m.Add("打开「辅助功能」权限（识别 AI 要用）…") { [weak self] in self?.OpenAccessibilitySettings() } }
        m.Sep()
        m.Add("和" + Names.Pet + "聊天…") { [weak self] in self?.OpenChatWindow() }
        m.Add("喂一个小橘子") { [weak self] in self?.Feed() }
        m.Add("用照片给" + Names.Pet + "变装…") { [weak self] in self?.PhotoLook() }
        BuildSkinMenu(m)
        BuildLooksMenu(m)
        BuildPersonaMenu(m)
        m.Sep()
        let pomo = m.Sub(pomoEnd > 0 ? "番茄钟（还剩 \(max(1, Int(ceil((pomoEnd - now) / 60)))) 分钟）" : breakEnd > 0 ? "番茄钟（休息中）" : "番茄钟")
        pomo.Add("专注 25 分钟") { [weak self] in self?.StartPomo(25) }
        pomo.Add("专注 50 分钟") { [weak self] in self?.StartPomo(50) }
        pomo.Add("结束番茄钟") { [weak self] in self?.StopPomo() }
        m.Add("设个提醒…") { [weak self] in self?.AskReminder() }
        m.Add("翻翻日记") { [weak self] in self?.ShowDiary() }
        m.Add("免打扰", checked: manualQuiet) { [weak self] in guard let s = self else { return }; s.manualQuiet.toggle(); s.lastQuietCheck = 0 }
        m.Sep()
        m.Add("戳一下") { [weak self] in self?.Poke() }
        m.Add("摸摸头") { [weak self] in self?.Pat() }
        m.Add("跳个舞") { [weak self] in self?.Act("dance") }
        m.Add("去散个步") { [weak self] in
            guard let s = self else { return }
            s.Interact()
            if s.Grounded() { s.StartWalk(s.rnd.Next(2) == 0 ? -1 : 1, 6, Double.nan); s.UserAct(6.2) }
        }
        m.Add("跳到当前窗口上") { [weak self] in guard let s = self else { return }; s.Interact(); s.UserAct(2); _ = s.TryJumpToWindow(true) }
        m.Add(state == "sleep" ? "叫醒" : "睡觉") { [weak self] in
            guard let s = self else { return }
            if s.state == "sleep" { s.Act("surprised") } else { s.afterStretch = "sleep"; s.Act("stretch") }
        }
        m.Sep()
        BuildAISettingsMenu(m)
        let size = m.Sub("大小")
        for (i, n) in ["小", "中", "大", "特大"].enumerated() {
            let sz = i + 2
            size.Add(n, checked: S == sz) { [weak self] in guard let s = self else { return }; s.S = sz; s.ResizeForm(); s.Place(); s.SaveState() }
        }
        let hat = m.Sub("头饰")
        let hatNames = ["粉色蝴蝶结", "小白花", "小嫩芽", "小皇冠", "不戴"], hatIds = ["bow", "flower", "sprout", "crown", ""]
        for i in 0..<hatIds.count {
            let id = hatIds[i]
            let ok = Unlocked(id)
            let need = id == "flower" ? "亲密度 40 解锁" : id == "sprout" ? "亲密度 60 解锁" : id == "crown" ? "亲密度 80 解锁" : ""
            hat.Add(hatNames[i] + (ok || need == "" ? "" : "（" + need + "）"), checked: hatChoice == id, enabled: ok) { [weak self] in
                guard let s = self else { return }; s.hatChoice = id; s.SaveState(); s.Act("happy")
            }
        }
        m.Add(Names.Pet + " 的生日…") { [weak self] in self?.SetPetBirthday() }
        let fm = m.Sub("节日装扮")
        fm.Add("跟着日历自动换", checked: festMode == "") { [weak self] in guard let s = self else { return }; s.festMode = ""; s.SaveState(); s.Act("happy") }
        fm.Add("不换节日装扮", checked: festMode == "off") { [weak self] in guard let s = self else { return }; s.festMode = "off"; s.SaveState() }
        fm.Sep()
        let pv = fm.Sub("预览")
        for f in FESTS() {
            let key = f[0], line = f[2]
            pv.Add(f[1]) { [weak self] in guard let s = self else { return }; s.festMode = key; s.Act("happy"); s.Say("（预览）" + line, 5) }
        }
        m.Add("声音", checked: !muted) { [weak self] in self?.ToggleSound() }
        m.Add("走路的嗒嗒声", checked: stepSfx) { [weak self] in
            guard let s = self else { return }
            s.stepSfx.toggle()
            let nf = PathJoin(s.cfgDir, "nostep.txt")
            if s.stepSfx { FileX.Delete(nf) } else { FileX.Write(nf, "1") }
        }
        m.Add("手动：假装 AI 在工作", checked: manualWork) { [weak self] in self?.manualWork.toggle() }
        m.Add("开机自动启动", checked: FileX.Exists(StartupFile())) { [weak self] in self?.ToggleAutostart() }
        m.Add("检测诊断（识别不到时用）") { [weak self] in self?.Diagnose() }
        m.Add("打开" + Names.Pet + "的文件夹") { [weak self] in if let s = self { OpenPath(s.dir) } }
        m.Sep()
        m.Add("退出") { [weak self] in self?.Quit() }
        return m
    }

    func OpenAccessibilitySettings() {
        _ = AX.Trusted(prompt: true)
        OpenUrl("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        AskAccessibility()
    }
}
