import AppKit

// ---------- 绘制（坐标单位 = 参考图里的一个"像素格"，可以用 0.25 的小数） ----------
// 身体 2..13 × 6..13，眼睛 1×2，手 2×2，四只脚 1×2，脚底在 y=15

let GLINT = B("#FFFFFF")
let EYE = B("#1A1A1A"), MOUTH = B("#7A2230"),
    BLUSH = B("#F2A7A0"), SHADOW = B("#2E2E2E"), TEAR = B("#6EC6F5"), GOLD = B("#F5C842"), SPECK = B("#F0A030"),
    PINK = B("#E9768A"), CLOUD = B("#FFFFFF"), CLOUD_EDGE = B("#CFC8BC"), TERM = B("#1E1E22"), TERM_TXT = B("#7FB6FF"),
    CODE = B("#8BD17C"), LAPTOP = B("#3C3C40"), SCREEN_BG = B("#26262A"), SCREEN = B("#4A90E2"),
    HARDHAT = B("#E8B04A"), HARDHAT_D = B("#C98F2C"), NAIL = B("#6E7781"), WOOD = B("#8A5A3B"),
    PHONES = B("#2F4E8A"), PHONES_D = B("#263F70"), BOOK = B("#3F7FD0"), PAPER = B("#F7F7F2"),
    BALL_R = B("#E04848"), BALL_G = B("#4CAF50"), BALL_Y = B("#F2C230"), CHICK = B("#F6D04D"), CHICK_D = B("#E0B232"),
    BEAK = B("#F08A24"), PHONE = B("#2B2B2B"), CAP = B("#3F6FD0"), CAP_D = B("#2E55A8"), ORANGE = B("#FFA531"),
    LEAF = B("#5DBB6B"), LEAF_D = B("#3E8A5E"), BOX = B("#C9A26B"), BOX_D = B("#A9844F"), RAINCLOUD = B("#B8BEC8"),
    ANGER = B("#E04848"), STEAM = B("#C9D1DE"), EDGE = B("#7C8AA5"), DUST = B("#B9B2A8"), BOW = B("#FF8FB1"),
    BOW_D = B("#E8507A"), NIGHTCAP = B("#5B6CC9"), SANTA = B("#D63B3B"), CONF1 = B("#4FC3F7"), DARK = B("#2A3140"),
    MAGPIE = B("#2F5FA8"), MAGPIE_D = B("#1F3F70"), WITCH = B("#7A4FB0"), STRING = B("#9A9384"), LANTERN_HI = B("#FF8A65"),
    ZONGZI = B("#5E9E4A"), POPSICLE = B("#F48FB1"), POPSICLE_HI = B("#FFC1D9"), SCARF = B("#D9463E"), MOONCAKE = B("#D9A24A"), MOONCAKE_D = B("#B98232"), SNOW = B("#FFFFFF")
let WHITE = Brush(.white)
let CONFS = [B("#E9768A"), B("#4FC3F7"), B("#F5C842"), B("#8BD17C"), B("#B39DDB")]

let SPARK = ["010", "111", "010"]
let HEART = ["01010", "11111", "01110", "00100"]
let CROSS4 = ["1001", "0110", "0110", "1001"]
let ZED = ["1111", "0010", "0100", "1111"]
let NOTE_B = ["011", "010", "110", "110"]
let PUFF = ["0110", "1111", "0110"]
let QMARK = ["111", "001", "011", "000", "010"]
let ORANGE_FULL = ["0110", "1111", "1111", "0110"]
let ORANGE_BIT = ["0110", "1110", "1100", "0110"]
let ORANGE_END = ["11", "11"]
let CMDS = ["git", "npm test", "ls", "build", "edit", "grep"]

var CHEEKS = true, SMILE = true

func Seq(_ t: Double, _ step: Double, _ v: [Int]) -> Int { v[Swift.max(0, I(t / step)) % v.count] }
func SeqD(_ t: Double, _ step: Double, _ v: [Double]) -> Double { v[Swift.max(0, I(t / step)) % v.count] }
func Clamp(_ v: Double) -> Int { v > 0.5 ? 1 : v < -0.5 ? -1 : 0 }

extension PetForm {
    func Fill(_ b: Brush, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        guard let g = G else { return }
        g.setFillColor(b.color)
        g.fill(CGRect(x: x, y: y, width: w, height: h))
    }
    func R4(_ v: Double) -> Int { Int((v * 4).rounded(.toNearestOrEven)) }
    func PX(_ x: Double) -> Int { OX + R4(x + UX0) * S }
    func PY(_ y: Double) -> Int { OY + R4(y + UY0) * S }
    func U(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ b: Brush) {
        let cx = R4(x + UX0), cy = R4(y + UY0)
        let cw = R4(w), chh = R4(h)
        if cw <= 0 || chh <= 0 { return }
        Fill(b, Double(OX + cx * S), Double(OY + cy * S), Double(cw * S), Double(chh * S))
    }
    func Bits(_ rows: [String], _ x: Double, _ y: Double, _ px: Double, _ b: Brush) {
        for (j, row) in rows.enumerated() {
            for (i, c) in row.enumerated() where c == "1" { U(x + Double(i) * px, y + Double(j) * px, px, px, b) }
        }
    }
    func PixScale(_ sizeUnits: Double) -> Int { Swift.max(1, Int((sizeUnits * 4 * Double(S) / 12.0).rounded())) }
    func PixText(_ s: String, _ x: Double, _ y: Double, _ sizeUnits: Double, _ b: Brush, _ cjk: Bool) {
        guard let g = G else { return }
        ptext.DrawLine(g, s, PX(x), PY(y) + S, PixScale(sizeUnits), b)
    }

    func Paint(_ ctx: CGContext) {
        G = ctx
        OX = (Int(cw) - GW * S) / 2; OY = BUBBLE_H
        let t = now - since, n = now
        let blink = now < blinkUntil
        let Sd = Double(S)

        var dx = 0.0, dy = 0.0, lx = 0.0, ly = 0.0, armL = 0.0, armR = 0.0, armLX = 0.0, armRX = 0.0, legA = 0.0, legB = 0.0, legLen = 2.0, sq = 0.0
        var eye = blink ? "blink" : "open", mouth = "", prop = "", over = ""
        var blush = false, shadow = Grounded(), ownHat = false, flat = false, hideArmL = false, hideArmR = false, sweat = false

        switch state {
        case "idle":
            let c = n % 2.6; dy = (c > 1.6 && c < 2.3) ? -0.25 : 0
            let cp = Scr.Cursor
            lx = Double(Clamp((cp.X - posX) / 250.0)) * 0.5; ly = Double(Clamp((cp.Y - (posY - 22 * Sd)) / 200.0)) * 0.5
        case "think":
            lx = 0.5; ly = -0.5; armR = 1 + SeqD(n, 0.5, [0, 0.25]); over = "dots"
            sweat = now - workStarted > 30 && working
        case "work":
            ly = -0.5; dy = -SeqD(n, 0.2, [0, 0.25]); over = "term"
            armL = SeqD(n, 0.15, [0.5, 0]); armR = 0.5 - armL
        case "work2", "type":
            prop = "laptop"; lx = 0.5; ly = 0.5; hideArmR = true
            armL = SeqD(n, 0.15, [0.5, 0])
        case "build":
            prop = "hammer"; ownHat = true; sweat = true; hideArmR = true
            dy = Seq(n, 0.35, [0, 1]) == 1 ? 0.25 : 0
        case "done":
            dy = -SeqD(min(t, 1.39), 0.14, [0, 1.5, 3, 1.5, 0, 1.5, 3, 1.5, 0, 0])
            eye = "happy"; armL = 2; armR = 2; over = "ok"
        case "party":
            eye = "happy"; ownHat = true; prop = "partyhat"; armL = SeqD(n, 0.3, [2.5, 1]); armR = 3.5 - armL
            dy = -SeqD(n, 0.3, [0, 0.5])
        case "happy":
            dy = -SeqD(n, 0.3, [0, 0.5]); eye = "happy"
            armL = SeqD(n, 0.25, [1.5, 0]); armR = 1.5 - armL; over = "sparkle"
        case "daydream":
            eye = blink ? "blink" : "dot"; lx = 0.5; ly = -0.5; over = "cloud"
            dy = (n % 3) > 1.8 ? -0.25 : 0
        case "surprised":
            dy = t < 0.45 ? -(sin(t / 0.45 * Double.pi) * 8).rounded() / 4 : 0
            eye = "big"; armL = 2; armR = 2; over = "bang"
        case "confused":
            eye = "line"; over = "question"; dx = t < 0.3 ? 0.25 : 0
        case "lookaround":
            lx = t < 1 ? -0.5 : t < 2 ? 0.5 : 0; ly = t < 2 ? -0.25 : 0
        case "sleep":
            eye = "line"; dy = (n % 2.4) > 1.2 ? 0.25 : 0
        case "talk":
            mouth = Seq(n, 0.25, [0, 1]) == 0 ? "o" : ""
            dy = -SeqD(n, 0.5, [0, 0.25])
        case "wink":
            eye = "wink"; armR = 2; over = "twinkle"
            dy = t < 0.4 ? -SeqD(t, 0.13, [0, 0.5, 0.5, 0]) : 0
        case "shy":
            eye = "squeeze"; blush = true; over = "heart1"
            dx = -SeqD(n, 0.6, [0, 0.25]); armL = 0.5; armR = 0.5
        case "love":
            eye = "happy"; over = "hearts"; armL = 1.5; armR = 1.5; dy = -SeqD(n, 0.4, [0, 0.25])
        case "miss":
            eye = "happy"; prop = "phone"; over = "you"; hideArmL = true; dy = -SeqD(n, 0.5, [0, 0.25])
        case "dizzy":
            flat = true; eye = "cross"; over = "stars"; shadow = Grounded()
        case "angry":
            eye = "squeeze"; over = "anger"
            dx = SeqD(n, 0.08, [-0.25, 0.25]); armL = SeqD(n, 0.15, [1.5, 0.5]); armR = 2 - armL
        case "sad":
            eye = "open"; over = "rain"; dy = 0.25; armL = -0.5; armR = -0.5; prop = "tears"
        case "dance":
            let k = I(n / 0.25) % 4
            let ddx = [-1.0, -0.5, 1, 0.5], ddy = [0.0, -1, 0, -1]
            dx = ddx[k]; dy = ddy[k]; eye = "happy"; over = "notes"
            armL = SeqD(n, 0.25, [2.5, 0]); armR = 2.5 - armL
            legA = SeqD(n, 0.25, [0.5, 0]); legB = 0.5 - legA
        case "music":
            prop = "headphones"; ownHat = true; eye = "chill"; over = "notes"
            dx = SeqD(n, 0.5, [-0.25, 0.25]); dy = -SeqD(n, 0.25, [0, 0.25])
        case "read":
            prop = "book"; eye = blink ? "blink" : "open"; ly = 0.5; lx = -0.5; hideArmL = true
        case "juggle":
            prop = "balls"; ly = -0.5; armL = SeqD(n, 0.3, [1.5, 0.5]); armR = 2 - armL
        case "bird":
            prop = "bird"; ly = -0.5; eye = t > 3 ? "happy" : (blink ? "blink" : "open")
        case "wave":
            armR = SeqD(n, 0.2, [3, 2]); armRX = SeqD(n, 0.2, [0, 0.5]); eye = "happy"
        case "stretch":
            if t < 0.35 { armL = 2; armR = 2 }
            else if t < 2.0 { armL = 4.5; armR = 4.5; armLX = 0.5; armRX = -0.5; dy = -0.5; eye = "line"; mouth = "yawn" }
            else if t < 2.3 { armL = 2; armR = 2 }
        case "walk":
            lx = Double(walkDir) * 0.5; legA = SeqD(n, 0.18, [0.5, 0]); legB = 0.5 - legA
            dy = -SeqD(n, 0.18, [0, 0.25]); armL = SeqD(n, 0.18, [0.5, 0]); armR = 0.5 - armL
            if walkGear { prop = "gear"; ownHat = true }
        case "sit":
            dy = 1.5; legLen = 0.5; eye = blink ? "blink" : (t > 3 ? "line" : "open"); lx = (sin(n * 0.6)).rounded() * 0.5
        case "held":
            eye = "squeeze"
            legA = SeqD(n, 0.12, [-0.5, 0]); legB = -0.5 - legA; legLen = 2.5
            armL = SeqD(n, 0.1, [2, 0.5]); armR = 2.5 - armL; shadow = false
        case "fall":
            eye = "big"; armL = 3; armR = 3; legLen = 2.5; shadow = false
        case "jump":
            eye = "happy"; armL = 2.5; armR = 2.5; legLen = 1.5; shadow = false
        case "land":
            sq = Double(max(0, squash - I(t / 0.12))) * 0.5; eye = sq > 0.5 ? "line" : "open"
        case "catch":
            eye = "big"; ly = -0.5; armL = 3; armR = 3
        case "eat":
            prop = "orange"; eye = "happy"
            mouth = Seq(n, 0.2, [0, 1]) == 0 ? "o" : ""
        case "brush":
            prop = "toothbrush"; eye = "happy"; hideArmL = true; dy = -SeqD(n, 0.3, [0, 0.25])
        case "shower":
            prop = "shower"; eye = "line"; ownHat = true; dx = SeqD(n, 0.5, [-0.25, 0.25])
        case "hungry":
            prop = "belly"; eye = blink ? "blink" : "dot"; hideArmL = true; hideArmR = true; dy = (n % 2) > 1 ? 0.25 : 0
        case "sign":
            prop = "sign"; armL = 3; armR = 3; ownHat = true; eye = Seq(n, 0.6, [0, 1]) == 0 ? "open" : "big"
        case "bell":
            prop = "bell"; hideArmR = true
            eye = Seq(n, 0.6, [0, 1]) == 0 ? "happy" : "open"
            mouth = Seq(n, 0.24, [0, 1]) == 0 ? "o" : ""
            armL = SeqD(n, 0.24, [0.5, 0])
            dy = -SeqD(n, 0.24, [0, 0.25])
        case "sulk":
            prop = "box"; eye = blink ? "blink" : "dot"; lx = (sin(n * 0.7)).rounded() * 0.5; dy = 1.5; legLen = 0; shadow = false
        default: break
        }

        // 地上的影子：一条深色细线，跳起来也留在地上
        if shadow && !flat {
            let sw = max(5, 10 - abs(min(0, dy)) * 0.9)
            U(7.5 - sw / 2, 15, sw, 0.5, SHADOW)
        }
        if !flat { DrawLooks("back", dx, dy, dx, dy, n, ownHat) }

        if flat {
            // 被戳晕：整只扁扁地趴在地上，翻着小脚，一只手无力地挥
            U(1.5, 14.5, 12, 0.5, SHADOW)
            DrawSkin(0, 0, 0, true, 0, 0, 0, 0, false, false, 0, 0, 0, SeqD(n, 0.3, [0, 0.5]))
            Bits(CROSS4, 3.75, 12.25, 0.25, EYE); Bits(CROSS4, 9.75, 12.25, 0.25, EYE)
            DrawOver(over, t, n, 0, 0)
            DrawParticles(n)
            DrawBubble()
            return
        }

        // 整只身体：皮肤像素图 + 小手 + 小脚 + 自动描边
        DrawSkin(dx, dy, sq, false, armL, armR, armLX, armRX, hideArmL, hideArmR, legLen, legA, legB, 0)

        let fx = dx, fy0 = dy + sq
        let fy = fy0 - (skin != nil ? Double(skin!.FaceUp) * 0.5 : 0)   // 高个子的形象，脸和头顶整体往上挪
        if !ownHat && !HeadLookVisible() { DrawHat(Hat(), fx, fy) }

        let ci = skin?.CheekIn ?? 0
        if blush || (CHEEKS && (skin == nil || skin!.Cheeks)) {
            if let sk = skin, sk.CheekUnder {
                // 腮红正好在两只眼睛下面
                let ei = sk.EyeIn
                let cy = sk.Eyes == "short" ? 9.75 : 10.25   // 紧挨着眼睛下面，落在脸蛋上
                U(4 + ei + fx + lx, cy + fy + ly, 1, 1, BLUSH); U(10 - ei + fx + lx, cy + fy + ly, 1, 1, BLUSH)   // 小方块腮红，和眼睛对齐
            } else { U(2.75 + ci + fx, 10.25 + fy, 1, 0.5, BLUSH); U(11.25 - ci + fx, 10.25 + fy, 1, 0.5, BLUSH) }
        }

        // 眼睛：都很简单，靠形状表达情绪
        let EX = [4.0, 10.0]
        for i in 0..<2 {
            let ein = skin != nil ? (i == 0 ? skin!.EyeIn : -skin!.EyeIn) : 0
            let ex = EX[i] + ein + fx + lx, ey = 8 + fy + ly
            var k = eye
            if k == "wink" { k = i == 0 ? "open" : "happy" }
            let eyes = skin?.Eyes ?? "round"
            switch k {
            case "open":
                if eyes == "short" { U(ex, ey, 1, 1.5, SKIN_EYE) }                              // 短一点的竖眼睛
                else if eyes == "bar" { U(ex, ey, 1, 2, SKIN_EYE) }                              // 竖条眼睛
                else { U(ex - 0.125, ey + 0.5, 1.25, 1.25, SKIN_EYE); U(ex + 0.5, ey + 0.5, 0.5, 0.5, GLINT) }   // 圆圆的眼睛 + 小高光
            case "blink": U(ex, ey + 1.5, 1, 0.5, SKIN_EYE)
            case "line": U(ex - 0.25, ey + 1, 1.5, 0.5, SKIN_EYE)                    // - -
            case "dot": U(ex, ey + 0.75, 1, 1, SKIN_EYE)                             // . .
            case "big":
                if eyes == "short" { U(ex - 0.25, ey - 0.25, 1.5, 2, SKIN_EYE) }
                else if eyes == "bar" { U(ex - 0.25, ey - 0.5, 1.5, 2.5, SKIN_EYE) }
                else { U(ex - 0.25, ey, 1.75, 1.75, SKIN_EYE); U(ex + 0.5, ey, 0.5, 0.5, GLINT) }
            case "happy":                                                             // ^ ^
                U(ex - 0.25, ey + 1, 0.5, 0.5, SKIN_EYE); U(ex + 0.25, ey + 0.5, 0.5, 0.5, SKIN_EYE); U(ex + 0.75, ey + 1, 0.5, 0.5, SKIN_EYE)
            case "chill":                                                             // v v
                U(ex - 0.25, ey + 0.5, 0.5, 0.5, SKIN_EYE); U(ex + 0.25, ey + 1, 0.5, 0.5, SKIN_EYE); U(ex + 0.75, ey + 0.5, 0.5, 0.5, SKIN_EYE)
            case "squeeze":                                                           // > <
                if i == 0 { U(ex - 0.25, ey + 0.25, 0.5, 0.5, SKIN_EYE); U(ex + 0.25, ey + 0.75, 0.5, 0.5, SKIN_EYE); U(ex - 0.25, ey + 1.25, 0.5, 0.5, SKIN_EYE) }
                else { U(ex + 0.75, ey + 0.25, 0.5, 0.5, SKIN_EYE); U(ex + 0.25, ey + 0.75, 0.5, 0.5, SKIN_EYE); U(ex + 0.75, ey + 1.25, 0.5, 0.5, SKIN_EYE) }
            case "cross": Bits(CROSS4, ex, ey + 0.25, 0.25, SKIN_EYE)
            default: break
            }
        }

        if mouth == "" && SMILE && (skin == nil || skin!.Smile) && eye != "cross" && eye != "line" {
            // 小小的微笑 ᴗ
            U(6.75 + fx, 10.5 + fy, 0.25, 0.25, SKIN_EYE); U(7 + fx, 10.75 + fy, 0.5, 0.25, SKIN_EYE); U(7.5 + fx, 10.5 + fy, 0.25, 0.25, SKIN_EYE)
        }
        switch mouth {
        case "o": U(7 + fx, 11 + fy, 1, 0.75, MOUTH)
        case "yawn": U(7 + fx, 10.5 + fy, 1, 1.75, MOUTH)
        default: break
        }

        if sweat {
            let a = (n % 1.4) / 1.4 * 3
            if a < 2.5 { U(13.25 + dx, 4.5 + a + dy, 0.5, 0.5, TEAR); U(13 + dx, 5 + a + dy, 1, 0.75, TEAR) }
        }

        DrawLooks("front", fx, fy, dx, dy, n, ownHat)
        DrawProp(prop, t, n, fx, fy0, dx, dy)
        DrawExtras(n, fx, fy0, dx, dy, prop != "" || hideArmL)
        if prop == "" && !hideArmL && state != "dizzy" && state != "sulk" && !HandLookVisible("left_hand") { DrawHeld(HeldItem(), n, dx + armLX, dy - armL) }
        DrawOver(over, t, n, dx, dy)
        DrawParticles(n)
        DrawBubble()
    }

    // ---------- 道具 ----------
    func DrawProp(_ prop: String, _ t: Double, _ n: Double, _ fx: Double, _ fy: Double, _ dx: Double, _ dy: Double) {
        switch prop {
        case "laptop":
            // 深色笔记本挡在右前方，屏幕上是绿色的 </>
            U(7 + dx, 9 + dy, 7, 4.5, LAPTOP); U(7.5 + dx, 9.5 + dy, 6, 3.5, SCREEN_BG)
            U(6 + dx, 13.25 + dy, 8.5, 0.75, LAPTOP)
            Bits(["01000010010", "10000100001", "01001000010"], 8.25 + dx, 10.5 + dy, 0.4, CODE)
            if Seq(n, 0.5, [0, 1]) == 0 { Bits(SPARK, 13.5 + dx, 5, 0.5, GOLD) }
        case "hammer":
            // 黄色安全帽 + 一下一下敲锤子
            U(3.5 + fx, 3.75 + fy, 8, 2.25, HARDHAT); U(2.5 + fx, 5.5 + fy, 10, 0.75, HARDHAT_D)
            U(7 + fx, 3.75 + fy, 1, 2, HARDHAT_D); U(6.5 + fx, 4.5 + fy, 2, 0.5, HARDHAT_D)
            let down = Seq(n, 0.35, [0, 1]) == 1
            U(15.5, 13.75, 2.5, 1.25, NAIL); U(16.25, 13.25, 1, 0.5, GOLD)
            if !down { U(13 + dx, 6.5 + dy, 2, 2, BODY); U(14.25 + dx, 3.5 + dy, 0.5, 4, WOOD); U(13.5 + dx, 2.75 + dy, 2, 1, NAIL) }
            else {
                U(13 + dx, 9 + dy, 2, 2, BODY); U(14.5 + dx, 9.75 + dy, 3, 0.5, WOOD); U(16.75 + dx, 9.25 + dy, 1, 2.5, NAIL)
                Bits(SPARK, 17.5, 11.5, 0.4, GOLD)
            }
        case "partyhat":
            U(6.75 + fx, 1.5 + fy, 1.5, 0.75, GOLD); U(6.25 + fx, 2.25 + fy, 2.5, 1.25, PINK)
            U(5.75 + fx, 3.5 + fy, 3.5, 1.25, GOLD); U(5.25 + fx, 4.75 + fy, 4.5, 1.25, PINK)
            U(7.25 + fx, 0.75 + fy, 0.5, 0.75, CONF1)
        case "headphones":
            U(2.5 + fx, 3.75 + fy, 10, 0.75, PHONES); U(1.75 + fx, 4.25 + fy, 0.75, 2.5, PHONES); U(12.5 + fx, 4.25 + fy, 0.75, 2.5, PHONES)
            U(1.25 + fx, 6.5 + fy, 1.5, 2.75, PHONES_D); U(12.25 + fx, 6.5 + fy, 1.5, 2.75, PHONES_D)
        case "book":
            // 圆眼镜 + 一本蓝色的书
            U(3.25 + fx - 0.5, 7.5 + fy, 2.5, 0.25, WOOD); U(3.25 + fx - 0.5, 10.5 + fy, 2.5, 0.25, WOOD)
            U(2.75 + fx - 0.5, 7.75 + fy, 0.25, 2.75, WOOD); U(5 + fx, 7.75 + fy, 0.25, 2.75, WOOD)
            U(9.25 + fx - 0.5, 7.5 + fy, 2.5, 0.25, WOOD); U(9.25 + fx - 0.5, 10.5 + fy, 2.5, 0.25, WOOD)
            U(8.75 + fx - 0.5, 7.75 + fy, 0.25, 2.75, WOOD); U(11 + fx, 7.75 + fy, 0.25, 2.75, WOOD)
            U(5.25 + fx, 8.5 + fy, 3.5, 0.25, WOOD)
            U(-0.5 + dx, 9 + dy, 3.25, 3.75, BOOK); U(-0.25 + dx, 9.5 + dy, 2.5, 0.25, PAPER); U(-0.25 + dx, 10.25 + dy, 2.5, 0.25, PAPER); U(-0.25 + dx, 11 + dy, 1.75, 0.25, PAPER)
            U(1.5 + dx, 11.25 + dy, 1.5, 1.5, BODY)
            if (n % 5) > 4.6 { U(1 + dx, 8.5 + dy, 2, 4.5, PAPER) }   // 翻页
        case "balls":
            let cols = [BALL_R, BALL_G, BALL_Y]
            for i in 0..<3 {
                let u = ((n / 1.2) + Double(i) / 3.0) % 1.0
                let bx = 1.5 + u * 12, by = 5 - sin(u * Double.pi) * 5
                U(bx, by, 1.25, 1.25, cols[i])
            }
        case "bird":
            let hop = t < 0.6 ? -(1 - t / 0.6) * 3 : (Seq(n, 0.7, [0, 0, 0, 1]) == 1 ? -0.5 : 0)
            let bx = 6.5 + fx, by = 3.5 + fy + hop
            U(bx, by + 0.5, 2.25, 2, CHICK); U(bx + 0.5, by, 1.5, 1, CHICK)
            U(bx + 1.5, by + 0.25, 0.25, 0.25, EYE); U(bx + 2, by + 0.5, 0.75, 0.5, BEAK)
            U(bx - 0.25, by + 1, 0.5, 0.75, CHICK_D)
            if t > 3 { Bits(SPARK, 10.5, 2, 0.4, GOLD) }
        case "phone":
            U(-0.5 + dx, 7.75 + dy, 1.75, 3, PHONE); U(-0.25 + dx, 8.25 + dy, 1.25, 2, SCREEN)
            U(0.75 + dx, 9.25 + dy, 1.5, 1.5, BODY)
        case "gear":
            // 出门散步：蓝色鸭舌帽 + 小背包
            let brim = walkDir > 0 ? 9.5 : 1.5
            U(3.5 + fx, 4.25 + fy, 8, 1.75, CAP); U(brim + fx, 5.25 + fy, 4, 0.75, CAP); U(7 + fx, 4.75 + fy, 1, 0.5, GOLD)
            let bp = walkDir > 0 ? 0.25 : 12.5
            U(bp + dx, 7 + dy, 2.25, 4.5, CAP_D); U(bp + 0.5 + dx, 8 + dy, 1, 0.75, GOLD)
        case "tears":
            let a = (n % 1.0) * 2.5, b = ((n + 0.5) % 1.0) * 2.5
            if a < 2 { U(4.25 + fx, 10 + fy + a, 0.5, 0.75, TEAR) }
            if b < 2 { U(10.25 + fx, 10 + fy + b, 0.5, 0.75, TEAR) }
        case "orange":
            let o = t < 1.2 ? ORANGE_FULL : t < 2.4 ? ORANGE_BIT : ORANGE_END
            let ox = t < 2.4 ? 6.5 : 7.0, oy = 10.5 + fy + (t < 2.4 ? 0 : 0.5)
            Bits(o, ox + fx, oy, 0.5, ORANGE)
            if t < 1.2 { U(7.25 + fx, 10 + fy, 0.5, 0.5, LEAF) }
            U(4.5 + fx, 11 + fy, 1.75, 1.75, BODY_D); U(8.75 + fx, 11 + fy, 1.75, 1.75, BODY_D)
        case "box":
            // 躲进纸箱生闷气，只露出眼睛偷偷看你
            U(1, 10.25, 13, 4.75, BOX); U(1, 10.25, 13, 0.5, BOX_D); U(6.75, 10.75, 1.5, 1, BOX_D)
            U(0.25, 9.75, 1.5, 0.75, BOX_D); U(13.25, 9.75, 1.5, 0.75, BOX_D)
        default:
            DrawProp2(prop, t, n, fx, fy, dx, dy)
        }
    }

    func DrawHeld(_ item: String, _ n: Double, _ dx: Double, _ dy: Double) {
        switch item {
        case "hongbao":
            U(-0.75 + dx, 8 + dy, 2, 2.75, BALL_R); U(-0.25 + dx, 8.75 + dy, 1, 0.75, GOLD)
        case "lantern":
            let sw = SeqD(n, 0.6, [0, 0.25, 0, -0.25])
            U(0.75 + dx, 3.5 + dy, 0.25, 6, WOOD)
            U(-1 + dx + sw, 5 + dy, 0.25, 0.75, WOOD)
            U(-1.75 + dx + sw, 5.75 + dy, 1.75, 0.5, GOLD); U(-2 + dx + sw, 6.25 + dy, 2.25, 2.25, BALL_R)
            U(-1.75 + dx + sw, 8.5 + dy, 1.75, 0.5, GOLD); U(-1.125 + dx + sw, 9 + dy, 0.5, 1, GOLD)
            if Seq(n, 0.4, [0, 1]) == 0 { U(-1.25 + dx + sw, 6.75 + dy, 0.75, 1.25, LANTERN_HI) }
        case "balloon":
            let bob = SeqD(n, 0.8, [0, -0.25])
            U(14.25 + dx, 3 + dy + bob, 0.25, 6, STRING)
            U(13.25 + dx, -0.75 + dy + bob, 2.25, 3, BALL_R); U(13.5 + dx, -1.25 + dy + bob, 1.75, 0.5, BALL_R)
            U(13.75 + dx, -0.5 + dy + bob, 0.5, 0.75, LANTERN_HI); U(14.125 + dx, 2.25 + dy + bob, 0.5, 0.5, BALL_R)
        case "zongzi":
            Bits(["00100", "01110", "11111"], -1 + dx, 8.25 + dy, 0.6, ZONGZI)
            U(-1 + dx, 9.25 + dy, 3, 0.25, PAPER)
        case "mooncake":
            U(-1 + dx, 8.25 + dy, 2.75, 2.75, MOONCAKE); U(-0.5 + dx, 8.75 + dy, 1.75, 1.75, MOONCAKE_D); U(0 + dx, 9.25 + dy, 0.75, 0.75, MOONCAKE)
        case "flag":
            let wave = SeqD(n, 0.3, [0, 0.25])
            U(0.75 + dx, 3.5 + dy, 0.25, 6, WOOD)
            U(-2.75 + dx, 3.5 + dy + wave, 3.5, 2.25, BALL_R); U(-2.25 + dx, 4 + dy + wave, 0.5, 0.5, GOLD)
        case "cake":
            U(-1.5 + dx, 8.5 + dy, 3.25, 2.25, PAPER); U(-1.5 + dx, 8.5 + dy, 3.25, 0.5, PINK); U(-1.5 + dx, 9.75 + dy, 3.25, 0.25, PINK)
            U(0 + dx, 7.25 + dy, 0.25, 1.25, CONF1)
            if Seq(n, 0.2, [0, 1]) == 0 { U(-0.125 + dx, 6.5 + dy, 0.5, 0.75, GOLD) } else { U(0 + dx, 6.75 + dy, 0.25, 0.5, SPECK) }
        case "candy":
            U(-0.5 + dx, 8.75 + dy, 1.5, 1.5, BALL_R); U(-0.25 + dx, 9 + dy, 0.5, 0.5, PAPER)
            U(-1.25 + dx, 9.25 + dy, 0.75, 0.5, BALL_R); U(1 + dx, 9.25 + dy, 0.75, 0.5, BALL_R)
        default: break
        }
    }

    // ---------- 头顶的符号 ----------
    func DrawOver(_ over: String, _ t: Double, _ n: Double, _ dx: Double, _ dy: Double) {
        switch over {
        case "dots":    // 思考：小点一个一个冒出来
            let c = I(n * 2.5) % 4
            for i in 0..<c { U(12 + Double(i) * 1.25 + dx, 2 - Double(i) * 0.5, 0.75, 0.75, EYE) }
        case "term", "ok":    // Claude Code 的终端气泡，一个字一个字敲命令
            U(1, -4.25, 13, 3.25, TERM); U(7, -1, 1, 0.75, TERM)
            var text: String
            var color = TERM_TXT
            if over == "ok" { text = "> ok"; color = CODE }
            else {
                let cmd = CMDS[I(n / 2.4) % CMDS.count]
                let shown = min(cmd.count, I((n % 2.4) / 0.16))
                text = "> " + cmd.Sub(0, shown)
            }
            PixText(text, 1.5, -4.25, 2.25, color, false)
            if over != "ok" && Seq(n, 0.3, [0, 1]) == 0 {
                let w = ptext.Width(text, PixScale(2.25))
                Fill(GOLD, Double(PX(1.5) + w + S), Double(PY(-3.75)), Double(S * 4), Double(S * 9))
            }
        case "bang": U(7.25 + dx, 0.5 + dy, 0.75, 2.5, GOLD); U(7.25 + dx, 3.5 + dy, 0.75, 0.75, GOLD)
        case "question": Bits(QMARK, 12, 0.5 + SeqD(n, 0.4, [0, -0.25]), 0.5, GOLD)
        case "sparkle":
            if Seq(n, 0.3, [0, 1]) == 0 { Bits(SPARK, 13.5, 3, 0.5, GOLD) } else { Bits(SPARK, -0.5, 4, 0.4, GOLD) }
        case "twinkle": if Seq(n, 0.15, [0, 1]) == 0 { Bits(SPARK, 12 + dx, 6.5 + dy, 0.4, GOLD) }
        case "heart1": Bits(HEART, 12.5, 3 + SeqD(n, 0.4, [0, -0.25]), 0.35, PINK)
        case "cloud":
            let cx = 12 + SeqD(n, 1, [0, 0.25, 0.5, 0.75, 0.5, 0.25]), cy = 1.5 - SeqD(n, 1.5, [0, 0.25])
            U(cx + 0.5, cy, 2, 0.5, CLOUD); U(cx, cy + 0.5, 3.25, 1, CLOUD)
        case "anger":
            Bits(["01010", "11011", "00000", "11011", "01010"], 12.5, 2.5, 0.35, ANGER)
            if Seq(n, 0.5, [0, 1]) == 0 { U(0.5, 3.5, 1, 1, STEAM) } else { U(0.25, 2.5, 0.75, 0.75, STEAM) }
        case "rain":
            U(4.5, -1.5, 6, 1.5, RAINCLOUD); U(5.5, -2, 3.5, 0.5, RAINCLOUD)
            for i in 0..<3 {
                let a = ((n * 1.6) + Double(i) * 0.37) % 1.0
                U(5.25 + Double(i) * 1.75, 0.25 + a * 4.5, 0.35, 0.6, TEAR)
            }
        case "stars":
            let path: [[Double]] = [[-4, 0.5], [-2.5, -0.5], [0, -1], [2.5, -0.5], [4, 0.5], [0, 1]]
            for i in 0..<3 {
                let q = path[(I(n / 0.2) + i * 2) % 6]
                Bits(SPARK, 6.9 + q[0] + dx, 8.5 + q[1] + dy, 0.4, GOLD)
            }
        case "you":
            // 想你了：头顶的小云里写着"你"
            U(10.25, 3.75, 0.5, 0.5, CLOUD_EDGE); U(11, 2.75, 0.75, 0.75, CLOUD_EDGE)
            U(11.5, -2.75, 6, 4.75, CLOUD_EDGE); U(11.75, -2.5, 5.5, 4.25, CLOUD)
            PixText("你", 12.85, -2.6, 3, EYE, true)
        default: break
        }
    }

    func DrawParticles(_ n: Double) {
        for p in parts {
            if p.Life < 0.3 && I(n * 12) % 2 == 1 && p.Kind != "dust" { continue }
            switch p.Kind {
            case "spark": Bits(SPARK, p.X, p.Y, 0.5, GOLD)
            case "speck": U(p.X, p.Y, 1, 1, SPECK)
            case "heart": Bits(HEART, p.X, p.Y, 0.35, PINK)
            case "z": Bits(ZED, p.X, p.Y, 0.35, EDGE)
            case "note": Bits(NOTE_B, p.X, p.Y, 0.4, GOLD)
            case "puff": Bits(PUFF, p.X, p.Y, 0.35, STEAM)
            case "q": Bits(QMARK, p.X, p.Y, 0.35, GOLD)
            case "dust": U(p.X, p.Y, 0.75, 0.25, DUST)
            case "snow": if p.Y < 15 { U(p.X, p.Y, 0.5, 0.5, SNOW) } else { p.Life = 0 }
            case "crumb": U(p.X, p.Y, 0.25, 0.25, ORANGE)
            case "code": U(p.X, p.Y, 0.5, 0.25, CODE)
            case "conf": U(p.X, p.Y, 0.5, 0.5, CONFS[((I(p.VX * 100 + 300) % CONFS.count) + CONFS.count) % CONFS.count])
            case "orange": Bits(ORANGE_FULL, p.X, p.Y, 0.5, ORANGE); U(p.X + 1, p.Y - 0.5, 0.5, 0.5, LEAF)
            default: break
            }
        }
    }

    func DrawHat(_ hat: String, _ fx: Double, _ fy: Double) {
        switch hat {
        case "night":   // 睡帽：帽檐贴着头顶 y=6
            U(4.5 + fx, 4 + fy, 6, 1, NIGHTCAP); U(5.5 + fx, 3.25 + fy, 4.5, 0.75, NIGHTCAP); U(7 + fx, 2.5 + fy, 3.5, 0.75, NIGHTCAP)
            U(10 + fx, 2.75 + fy, 0.75, 1, NIGHTCAP); U(10.25 + fx, 3.5 + fy, 1.25, 1.25, PAPER)
            U(4 + fx, 5 + fy, 7, 1, PAPER)
        case "santa":
            U(4.5 + fx, 4 + fy, 6, 1, SANTA); U(5.5 + fx, 3.25 + fy, 4.5, 0.75, SANTA); U(7 + fx, 2.5 + fy, 3.5, 0.75, SANTA)
            U(10 + fx, 2.75 + fy, 0.75, 1, SANTA); U(10.25 + fx, 3.5 + fy, 1.25, 1.25, PAPER)
            U(4 + fx, 5 + fy, 7, 1, PAPER)
        case "cny":
            U(3.5 + fx, 3 + fy, 8, 2, SANTA); U(5 + fx, 1.75 + fy, 5, 1.25, SANTA)
            U(2.5 + fx, 5 + fy, 10, 1, GOLD); U(7 + fx, 0.75 + fy, 1, 1, GOLD); U(7.25 + fx, 2.5 + fy, 0.5, 2, GOLD)
        case "party":
            U(6.75 + fx, 1.5 + fy, 1.5, 0.75, GOLD); U(6.25 + fx, 2.25 + fy, 2.5, 1.25, PINK)
            U(5.75 + fx, 3.5 + fy, 3.5, 1.25, GOLD); U(5.25 + fx, 4.75 + fy, 4.5, 1.25, PINK)
            U(7.25 + fx, 0.75 + fy, 0.5, 0.75, CONF1)
        case "heartband":   // 情人节：头顶一颗爱心发箍
            U(2.5 + fx, 5.5 + fy, 10, 0.5, PINK)
            U(7.5 + fx, 3.75 + fy, 0.25, 1.75, PINK)
            Bits(HEART, 6.5 + fx, 2.25 + fy, 0.45, PINK)
        case "magpie":      // 七夕：一只蓝色小喜鹊 + 小爱心
            U(6 + fx, 4.25 + fy, 3, 1.75, MAGPIE); U(8.5 + fx, 3.75 + fy, 1.25, 1.25, MAGPIE); U(5 + fx, 4.5 + fy, 1.25, 0.75, MAGPIE_D)
            U(9.25 + fx, 4 + fy, 0.25, 0.25, PAPER); U(9.75 + fx, 4.25 + fy, 0.5, 0.25, EYE); U(6.5 + fx, 5 + fy, 1.5, 0.5, PAPER)
            Bits(HEART, 10.75 + fx, 2.25 + fy - SeqD(now, 0.5, [0, 0.25]), 0.3, PINK)
        case "bunny":       // 中秋：玉兔耳朵
            U(4.5 + fx, 1.5 + fy, 1.25, 4.5, PAPER); U(9.25 + fx, 1.5 + fy, 1.25, 4.5, PAPER)
            U(4.75 + fx, 2.25 + fy, 0.75, 3, BLUSH); U(9.5 + fx, 2.25 + fy, 0.75, 3, BLUSH)
        case "witch":       // 万圣节：紫色小巫师帽
            U(2.5 + fx, 5.25 + fy, 10, 0.75, WITCH); U(4.5 + fx, 3.75 + fy, 6, 1.5, WITCH)
            U(5.5 + fx, 2.5 + fy, 4, 1.25, WITCH); U(6.75 + fx, 1.5 + fy, 2.5, 1, WITCH); U(8.75 + fx, 1.25 + fy, 1.5, 0.75, WITCH)
            U(4.5 + fx, 4.5 + fy, 6, 0.5, GOLD); U(6.25 + fx, 2.75 + fy, 0.5, 0.5, GOLD)
        case "band":        // 端午：五彩绳头带
            U(2 + fx, 6.5 + fy, 11, 0.5, BALL_R); U(2 + fx, 7 + fy, 11, 0.25, GOLD)
            U(12.5 + fx, 6.75 + fy, 0.5, 1.5, BALL_G); U(13 + fx, 7 + fy, 0.5, 1.25, CONF1)
        case "bow":     // 粉色蝴蝶结，歪戴在右上角
            U(8.75 + fx, 4.25 + fy, 1.5, 1.75, BOW); U(8.5 + fx, 4.75 + fy, 0.5, 0.75, BOW)
            U(11.25 + fx, 4.25 + fy, 1.5, 1.75, BOW); U(12.5 + fx, 4.75 + fy, 0.5, 0.75, BOW)
            U(10.25 + fx, 4.75 + fy, 1, 1.25, BOW_D)
        case "crown":
            U(4.5 + fx, 4.25 + fy, 6, 1.75, GOLD); U(4.5 + fx, 3 + fy, 1, 1.25, GOLD); U(7 + fx, 2.5 + fy, 1, 1.75, GOLD); U(9.5 + fx, 3 + fy, 1, 1.25, GOLD)
            U(5.5 + fx, 4.75 + fy, 0.75, 0.75, PINK); U(7.125 + fx, 4.75 + fy, 0.75, 0.75, CONF1); U(8.75 + fx, 4.75 + fy, 0.75, 0.75, PINK)
        case "flower":
            U(10.5 + fx, 3.25 + fy, 1, 1, PAPER); U(9.5 + fx, 4.25 + fy, 1, 1, PAPER); U(11.5 + fx, 4.25 + fy, 1, 1, PAPER)
            U(10.5 + fx, 5.25 + fy, 1, 0.75, PAPER); U(10.5 + fx, 4.25 + fy, 1, 1, GOLD)
        case "sprout":
            let sw = SeqD(now, 0.9, [0, 0.25])
            U(7.25 + fx, 3.75 + fy, 0.5, 2.25, LEAF_D)
            U(5.75 + fx + sw, 3 + fy, 1.5, 0.75, LEAF); U(6.25 + fx + sw, 2.5 + fy, 0.75, 0.5, LEAF)
            U(7.75 + fx + sw, 2.5 + fy, 1.5, 0.75, LEAF); U(8.25 + fx + sw, 2 + fy, 0.75, 0.5, LEAF)
        default: break
        }
    }

    func TextScale() -> Int { S >= 3 ? 2 : 1 }
    func TextPx() -> Int { S >= 3 ? 24 : 12 }   // 像素字体是 12px 设计的，只用整数倍才清晰

    func DrawBubble() {
        if bubbleText == "" || now > bubbleUntil { return }
        let maxW = Int(cw) - 40
        let sc = TextScale()
        let sz = ptext.Measure(bubbleText, maxW, sc)
        let w = sz.0 + 8 * sc + 8
        var h = sz.1 + 8 * sc + 4
        h = min(h, BUBBLE_H - 10)
        let x = (Int(cw) - w) / 2, y = BUBBLE_H - h - 8
        let k = max(2, sc * 2)
        let edge = EDGE, paper = WHITE
        func F(_ b: Brush, _ a: Int, _ bb: Int, _ c: Int, _ d: Int) { Fill(b, Double(a), Double(bb), Double(c), Double(d)) }
        // 像素风气泡：切掉四个角
        F(edge, x + k, y, w - 2 * k, h)
        F(edge, x, y + k, w, h - 2 * k)
        F(paper, x + k, y + k, w - 2 * k, h - 2 * k)
        F(paper, x + k / 2 + 1, y + k, k / 2, h - 2 * k)
        F(paper, x + w - k, y + k, k / 2, h - 2 * k)
        F(edge, x + w / 2 - k, y + h, k * 2, k)
        F(paper, x + w / 2 - k / 2, y + h - k, k, k)
        F(edge, x + w / 2 - k / 2, y + h + k, k, k)
        if let g = G {
            g.saveGState()
            g.clip(to: CGRect(x: x, y: y, width: w, height: h))
            _ = ptext.Draw(g, bubbleText, x + 4 * sc + 4, y + 4 * sc + 2, sc, DARK, maxW)
            g.restoreGState()
        }
    }
}
