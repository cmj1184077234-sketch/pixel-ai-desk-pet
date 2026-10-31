import AppKit

// ---------- 像素风小音效：全部现场合成，没有人声 ----------
enum Sfx {
    static let RATE = 22050
    static var cache: [String: Data] = [:]
    static var lengths: [String: Double] = [:]
    static let lock = NSLock()
    static var seed: UInt64 = 7
    static func NextRand() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 11) / Double(1 << 53) }

    static func Length(_ name: String) -> Double { _ = Get(name); lock.lock(); defer { lock.unlock() }; return lengths[name] ?? 0 }

    static func Get(_ name: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        if let b = cache[name] { return b }
        guard let s = Build(name) else { return nil }
        let b = Wav(s)
        cache[name] = b
        lengths[name] = Double(s.count) / Double(RATE)
        return b
    }

    static func Wav(_ s: [Float]) -> Data {
        var d = Data()
        func U32(_ v: Int) { var x = UInt32(v).littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func U16(_ v: Int) { var x = UInt16(v).littleEndian; d.append(Data(bytes: &x, count: 2)) }
        let n = s.count
        d.append("RIFF".data(using: .ascii)!); U32(36 + n * 2); d.append("WAVEfmt ".data(using: .ascii)!)
        U32(16); U16(1); U16(1); U32(RATE); U32(RATE * 2); U16(2); U16(16)
        d.append("data".data(using: .ascii)!); U32(n * 2)
        for i in 0..<n {
            let v = max(-1, min(1, Double(s[i])))
            var x = Int16(v * 30000).littleEndian
            d.append(Data(bytes: &x, count: 2))
        }
        return d
    }

    static func Buf(_ sec: Double) -> [Float] { Array(repeating: 0, count: Int(Double(RATE) * sec)) }

    // 铃铛一样的音色：基音 + 两个不协和泛音，指数衰减
    static func Bell(_ b: inout [Float], _ t0: Double, _ f: Double, _ amp: Double, _ decay: Double) {
        let st = Int(t0 * Double(RATE))
        var i = max(0, st)
        while i < b.count {
            let t = Double(i - st) / Double(RATE)
            var e = exp(-t * decay) * amp
            if t < 0.002 { e *= t / 0.002 }
            if e < 0.0005 && t > 0.05 { break }
            b[i] += Float(e * (sin(2 * Double.pi * f * t)
                + 0.45 * sin(2 * Double.pi * f * 2.76 * t) * exp(-t * decay * 1.6)
                + 0.2 * sin(2 * Double.pi * f * 5.4 * t) * exp(-t * decay * 2.8)))
            i += 1
        }
    }

    // 滑音：从 f0 滑到 f1，wave = sine / square / tri
    static func Tone(_ b: inout [Float], _ t0: Double, _ dur: Double, _ f0: Double, _ f1: Double, _ amp: Double, _ wave: String, _ vib: Double) {
        let st = Int(t0 * Double(RATE)), n = Int(dur * Double(RATE))
        var ph = 0.0
        var i = 0
        while i < n && st + i < b.count {
            let t = Double(i) / Double(RATE), u = Double(i) / Double(n)
            var f = f0 + (f1 - f0) * u
            if vib > 0 { f *= 1 + 0.04 * sin(2 * Double.pi * vib * t) }
            ph += 2 * Double.pi * f / Double(RATE)
            let v = wave == "square" ? (sin(ph) >= 0 ? 1.0 : -1.0) * 0.5 :
                    wave == "tri" ? 2 / Double.pi * asin(sin(ph)) : sin(ph)
            let env = min(1, t / 0.004) * min(1, Double(n - i) / (Double(RATE) * 0.02))
            b[st + i] += Float(v * amp * env)
            i += 1
        }
    }

    static func Noise(_ b: inout [Float], _ t0: Double, _ dur: Double, _ amp: Double, _ smooth: Double) {
        let st = Int(t0 * Double(RATE)), n = Int(dur * Double(RATE))
        var y = 0.0
        var i = 0
        while i < n && st + i < b.count {
            let x = NextRand() * 2 - 1
            y += smooth * (x - y)
            let env = exp(-6.0 * Double(i) / Double(n))
            b[st + i] += Float(y * amp * env)
            i += 1
        }
    }

    static func Build(_ name: String) -> [Float]? {
        var b: [Float]
        switch name {
        case "ding":        // 叮～
            b = Buf(1.1); Bell(&b, 0, 1318.5, 0.42, 5.5); Bell(&b, 0.08, 1975.5, 0.22, 6.5); return b
        case "bell":        // 叮铃铃：摇铃铛
            b = Buf(1.5)
            for i in 0..<12 {
                let t = Double(i) * 0.085
                Bell(&b, t, i % 2 == 0 ? 2093 : 2489, 0.2, 13)
                Noise(&b, t, 0.03, 0.03, 0.9)
            }
            return b
        case "dingdong":    // 叮——当
            b = Buf(2.2); Bell(&b, 0, 659.25, 0.4, 3.0); Bell(&b, 0.55, 523.25, 0.42, 2.4); return b
        case "step", "step2":        // 小脚步：嗒
            b = Buf(0.045)
            Tone(&b, 0, 0.022, name == "step" ? 2500 : 2900, name == "step" ? 2100 : 2400, 0.1, "square", 0)
            Noise(&b, 0, 0.016, 0.05, 0.7)
            return b
        case "poke":        // 啾！
            b = Buf(0.12); Tone(&b, 0, 0.1, 700, 1600, 0.28, "sine", 0); return b
        case "purr":        // 被摸头：呼噜噜
            b = Buf(0.5)
            for i in 0..<4 { Tone(&b, Double(i) * 0.1, 0.09, 300 - Double(i) * 10, 280 - Double(i) * 10, 0.18, "tri", 0) }
            Tone(&b, 0.38, 0.1, 880, 1175, 0.12, "sine", 0)
            return b
        case "boing":       // 跳：啵嘤
            b = Buf(0.26); Tone(&b, 0, 0.24, 240, 680, 0.25, "sine", 14); return b
        case "thud":        // 摔：噗通
            b = Buf(0.2); Noise(&b, 0, 0.12, 0.5, 0.15); Tone(&b, 0, 0.12, 150, 60, 0.45, "sine", 0); return b
        case "crunch":      // 吃橘子：咔嚓咔嚓
            b = Buf(0.3); Noise(&b, 0, 0.06, 0.35, 0.6); Noise(&b, 0.12, 0.06, 0.3, 0.6); Tone(&b, 0.2, 0.06, 1200, 1500, 0.08, "sine", 0); return b
        case "happy":       // 开心：哆咪嗦
            b = Buf(0.32); Tone(&b, 0, 0.07, 1046.5, 1046.5, 0.36, "square", 0); Tone(&b, 0.08, 0.07, 1318.5, 1318.5, 0.36, "square", 0); Tone(&b, 0.16, 0.14, 1568, 1568, 0.36, "square", 0); return b
        case "sad":         // 委屈：呜呜
            b = Buf(0.55); Tone(&b, 0, 0.2, 660, 600, 0.22, "tri", 6); Tone(&b, 0.24, 0.3, 520, 440, 0.22, "tri", 6); return b
        case "buzz":        // 生气：噗噗
            b = Buf(0.3); Tone(&b, 0, 0.08, 160, 150, 0.3, "square", 0); Tone(&b, 0.14, 0.1, 150, 130, 0.3, "square", 0); return b
        case "wobble":      // 晕：咕噜咕噜
            b = Buf(0.6); Tone(&b, 0, 0.55, 900, 300, 0.22, "sine", 11); return b
        case "pop":         // 冒气泡：啵
            b = Buf(0.07); Tone(&b, 0, 0.05, 1500, 900, 0.22, "sine", 0); return b
        default: return nil
        }
    }
}

extension PetForm {
    func PlaySfx(_ name: String) {
        if muted || quiet { return }
        let big = name == "ding" || name == "bell" || name == "dingdong"
        if !big && now < bigSoundUntil { return }   // 铃声响着的时候，小声音先让一让
        guard let data = Sfx.Get(name), let snd = NSSound(data: data) else { return }
        snd.play()
        curSound = snd
        if big { bigSoundUntil = now + Sfx.Length(name) }
    }

    func StepSound() {
        if !stepSfx || (state != "walk" && state != "pace") { return }
        if now - lastStepSfx < 0.36 { return }
        lastStepSfx = now
        stepParity = 1 - stepParity
        PlaySfx(stepParity == 0 ? "step" : "step2")
    }

    func StateSound(_ s: String) {
        switch s {
        case "eat": PlaySfx("crunch")
        case "jump": PlaySfx("boing")
        case "angry": PlaySfx("buzz")
        case "dizzy": PlaySfx("wobble")
        case "sad": PlaySfx("sad")
        default: break
        }
    }

    // ---------- 工作做完：叮 → 摇铃铛 → 叮当 → 对话框，直到 m 摸摸它 ----------

    // 只要不是离开电脑（5 分钟没动）或在全屏看视频，就算在：盯着屏幕看 AI 回答时不动鼠标也算
    func UserPresent() -> Bool { !away && !quiet }

    func LogEvent(_ text: String) {
        let f = PathJoin(dir, Names.Pet + "的事件记录.txt")
        var lines = FileX.Lines(f)
        lines.append(Fmt(Date(), "MM-dd HH:mm:ss") + "  " + text)
        if lines.count > 80 { lines.removeFirst(lines.count - 80) }
        FileX.WriteLines(f, lines)
    }

    func StartRing(_ app: String) {
        if ringing {
            if !ringApp.Contains(app) { ringApp = ringApp + " 和 " + app }
            bubbleText = "叮！" + ringApp + " 的任务做完啦"; bubbleUntil = now + 1e7
            LogEvent(app + " 也做完了 → 一起摇铃")
            return
        }
        ringing = true; ringApp = app; ringStage = 0; ringStart = now
        ringDeferred = !UserPresent()
        if !ringDeferred { Set("done"); PlaySfx("ding") }
        else { Set("bell") }
        bubbleText = "叮！" + app + " 的任务做完啦"; bubbleUntil = now + 1e7   // 一直写着是哪个 AI 做完了，直到 m 摸摸它
        LogEvent(app + " 工作结束 → " + (ringDeferred ? (away ? "你好像离开了，先不响，等你回来" : "你在全屏，先不响") : (muted ? "叮（声音是关着的，只有动作）" : "叮！开始摇铃铛")))
    }

    func RingTick() {
        if !ringing { return }
        if ringDeferred {
            if !UserPresent() { if state != "bell" && Grounded() { Set("bell") }; return }
            ringDeferred = false; ringStage = 0; ringStart = now
            Set("done"); PlaySfx("ding")
            LogEvent("你回来了 → 叮！开始摇铃铛")
            return
        }
        let t = now - ringStart
        if ringStage == 0 && t >= 1.3 { ringStage = 1; if Grounded() { Set("bell") }; PlaySfx("bell") }
        else if ringStage == 1 && t >= 20 { ringStage = 2; PlaySfx("dingdong") }
        else if ringStage == 2 && t >= 40 {
            ringStage = 3
            let line = PickFresh([
                NICK + "，" + ringApp + " 做完啦～我铃铛都摇累了，快去看看吧！",
                NICK + "！" + ringApp + " 那边好了，摸摸我告诉我你看到了～",
                ringApp + " 早就做完啦，" + NICK + " 快来看看结果！"])
            bubbleText = line; bubbleUntil = now + 1e7   // 一直显示，直到 m 摸摸它
            PlaySfx("pop")
        }
        if ringStage >= 1 && state != "bell" && Grounded() && (state == "idle" || state == "land" || state == "party" || state == "happy") { Set("bell") }
    }

    // m 看到了（摸摸或点它），铃铛就停下
    func Acknowledge() -> Bool {
        if !ringing { return false }
        ringing = false; ringDeferred = false
        bubbleUntil = 0
        LogEvent("你摸了摸" + Names.Pet + "，铃铛停下（摇了 \(Int(now - ringStart)) 秒）")
        Interact()
        Set("love")
        PlaySfx("purr")
        Say(PickFresh(["嘿嘿，你看到啦～", "收到摸摸！就知道你会来～", "好耶，提醒任务完成！", "终于等到你啦～"]), 3)
        return true
    }
}
