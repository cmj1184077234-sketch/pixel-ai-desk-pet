import AppKit

// ---------- 整体形象（皮肤）：整只桌宠的样子都由一张像素图决定 ----------
final class Skin {
    var Name = ""
    var Rows: [[Character]] = []
    var Pal: [Character: NSColor] = [:]
    var PalOrder: [Character] = []
    var Outline = "", Feet = ""
    var Eyes = "round", Hands = "round", Legs = "round"   // 眼睛 round/bar/short，手 round/square/none，脚 round/legs/none
    var NoOutline = false, Cheeks = true, Smile = true
    var HandRow = 19
    var Thin = ""                                          // 这些字母画出来的细线（比如胡须）不描边
    var EyeColor = ""                                      // 眼睛颜色，默认黑色
    var CheekIn = 0.0
    var FaceUp = 0
    var EyeIn = 0.0
    var CheekUnder = false                                 // 腮红放在眼睛正下方
    var HandColor = ""                                     // 小手颜色：调色板里的字母或 #RRGGBB
    var FilePath = ""
    var BuiltIn = false
}

let SKIN_W = 28, SKIN_H = 28
let SKIN_X0 = 0.5, SKIN_Y0 = 0.0
let MAX_SKIN_COLORS = 10
// 程序会自己画眼睛、嘴巴、腮红，所以这块“脸”必须是身体
let FACE_R0 = SKIN_H - 12, FACE_R1 = SKIN_H - 8, FACE_C0 = 7, FACE_C1 = 20   // 倒数第 12 到倒数第 8 行
let DEFAULT_SKIN = "叮叮"
let PAD = 6
// 默认形象“叮叮”：一只小铃铛精（AI 干完活就是它在摇铃）
let DEFAULT_SKIN_JSON = "{\"name\": \"叮叮\", \"rows\": [\"............................\", \"............................\", \"............................\", \"........rrr......rrr........\", \".......rrrrrrrrrrrrrr.......\", \".......rrrrrrkkrrrrrr.......\", \"........rrrrrkkrrrrr........\", \".........rrrrrrrrrr.........\", \"...........bbbbbb...........\", \".........bbbbbbbbbb.........\", \".......bhbbbbbbbbbbbb.......\", \"......bhbbbbbbbbbbbbbb......\", \".....bbhbbbbbbbbbbbbbbb.....\", \".....bbhbbbbbbbbbbbbbbb.....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"....bbbbbbbbbbbbbbbbbbbb....\", \"...bbbbbbbbbbbbbbbbbbbbbb...\", \"...bbbbbbbbbbbbbbbbbbbbbb...\", \"..hhhhhhhhhhhhhhhhhhhhhhhh..\", \".dddddddddddddddddddddddddd.\", \".dddddddddddddddddddddddddd.\", \"............cccc............\", \".............cc.............\"], \"palette\": {\"b\": \"#F7CB4F\", \"d\": \"#DFA232\", \"h\": \"#FFF0B5\", \"r\": \"#E5574D\", \"k\": \"#B83B36\", \"c\": \"#C98A2A\"}, \"eyes\": \"short\", \"cheek_pos\": \"under\", \"smile\": \"false\", \"eye_in\": \"1\", \"outline\": \"#7A4A1E\", \"legs\": \"none\"}"

let HAMSTER_ROWS = [
    "............................",
    "....bbbb............bbbb....",
    "...bbppbb..........bbppbb...",
    "...bbppbb..........bbppbb...",
    "...bbbbbbbbbbbbbbbbbbbbbb...",
    "...bbbbbbbbbbbbbbbbbbbbbb...",
    "....bbhhbbbbbbbbbbbbbbbb....",
    "...bbhbbbbbbbbbbbbbbbbbbb...",
    "...bbbbbbbbbbbbbbbbbbbbbb...",
    "..bbbbbbbbbbbbbbbbbbbbbbbb..",
    "..bbbbbbbbbbbbbbbbbbbbbbbb..",
    "..bbbbbbbbbbbbbbbbbbbbbbbb..",
    "..bbbbbbbbbbbbbbbbbbbbbbbb..",
    "..bbbbbbbbwwwwwwwwbbbbbbbb..",
    "..bbbbbbbwwwwwwwwwwbbbbbbb..",
    "...bbbbbwwwwwwwwwwwwbbbbb...",
    "...bbbbbwwwwwwwwwwwwbbbbb...",
    "....bbbbbwwwwwwwwwwbbbbb....",
    "......bbbbwwwwwwwwbbbb......",
    "........bbbbbbbbbbbb........"]

func Darker(_ c: NSColor, _ k: Double) -> NSColor {
    let s = c.usingColorSpace(.sRGB) ?? c
    return RGB(Int(Double(Int(round(s.redComponent * 255))) * k), Int(Double(Int(round(s.greenComponent * 255))) * k), Int(Double(Int(round(s.blueComponent * 255))) * k))
}

func SafeName(_ n0: String) -> String {
    var n = n0
    for c in ["/", ":", "\\", "*", "?", "\"", "<", ">", "|"] { n = n.Replace(c, "_") }
    return n.count > 30 ? n.Sub(0, 30) : n
}

extension PetForm {
    static func MakeHamster() -> Skin {
        let s = Skin()
        s.Name = DEFAULT_SKIN; s.BuiltIn = true
        var rows = HAMSTER_ROWS
        while rows.count < SKIN_H { rows.insert(Repeat(".", SKIN_W), at: 0) }   // 下面贴地，上面补空行
        s.Rows = rows.map { Array($0) }
        s.Pal["b"] = HexColor("#F2B880"); s.Pal["w"] = HexColor("#FFF1DE"); s.Pal["p"] = HexColor("#F7A6A8"); s.Pal["h"] = HexColor("#F9D7B0")
        s.Outline = "#5E3B2C"; s.Feet = "#E99A8A"
        return s
    }

    // 默认形象：叮叮（画不出来时退回简单的仓鼠）
    func MakeDefault() -> Skin {
        var problem = ""
        guard let d = Json.ParseDict(DEFAULT_SKIN_JSON), let s = ParseSkin(d, &problem) else { return PetForm.MakeHamster() }
        s.Name = DEFAULT_SKIN; s.BuiltIn = true
        return s
    }

    func SkinsDir() -> String { let d = PathJoin(cfgDir, "skins"); FileX.MkDir(d); return d }

    func LoadSkins() {
        skins.removeAll()
        skins.append(MakeDefault())
        var files: [String] = []
        files += FileX.Files(PathJoin(resDir, "skins"), ".json")   // 程序自带的形象
        files += FileX.Files(SkinsDir(), ".json")                  // 聊天 / 照片画出来的形象
        for f in files {
            guard let txt = FileX.Read(f), let d = Json.ParseDict(txt) else { continue }
            var problem = ""
            guard let s = ParseSkin(d, &problem) else { continue }
            s.FilePath = f
            skins.removeAll { $0.Name == s.Name }
            skins.append(s)
        }
        var on = Names.Skin   // config.txt 里的 skin=，第一次用哪个形象
        if let t = FileX.Read(PathJoin(cfgDir, "skin_on.txt")) { on = t.Trim }
        skin = skins[0]
        for s in skins where s.Name == on { skin = s }
        ApplySkinColors()
    }

    func ParseSkin(_ d: Dict, _ problem: inout String) -> Skin? {
        problem = ""
        let s = Skin()
        s.Name = Str(d, "name").Trim
        if s.Name == "" { problem = "没有名字"; return nil }
        if let pal = d["palette"] as? Dict {
            for k in pal.keys.sorted() {
                if k.count != 1 || k == "." { continue }
                if s.Pal.count >= MAX_SKIN_COLORS { break }   // 颜色少才像像素画
                if let c = HexColor(Str(pal, k)) { s.Pal[Character(k)] = c; s.PalOrder.append(Character(k)) }
            }
        }
        if s.Pal["b"] == nil { problem = "palette 里必须有 b（身体主色）"; return nil }
        var rows: [String] = []
        for r in Items(d["rows"]) {
            var row = "\(r)"
            if row.count > SKIN_W { row = row.Sub(0, SKIN_W) }
            row = row.PadRight(SKIN_W, ".")
            if rows.count < SKIN_H { rows.append(row) }
        }
        if rows.isEmpty { problem = "没有画 rows"; return nil }
        // 行数不够的从上面补空行，让脚始终贴在最下面
        let pad = SKIN_H - rows.count
        while rows.count < SKIN_H { rows.insert(Repeat(".", SKIN_W), at: 0) }
        let grid = rows.map { Array($0) }
        let fup0 = max(0, min(12, Int(Str(d, "face_up")) ?? 0))
        for r in (FACE_R0 - fup0)...(FACE_R1 - fup0) {
            for c in FACE_C0...FACE_C1 {
                let ch = grid[r][c]
                if ch == "." || ch == " " || s.Pal[ch] == nil {
                    problem = "你画的第 \(FACE_R0 - fup0 - pad)–\(FACE_R1 - fup0 - pad) 行、第 \(FACE_C0)–\(FACE_C1) 列是脸（程序会在这里画眼睛和嘴），这块必须填满颜色，现在第 \(r - pad) 行第 \(c) 列是空的"
                    return nil
                }
            }
        }
        s.Rows = grid
        s.Outline = Str(d, "outline")
        s.Feet = Str(d, "feet")
        if s.Outline.Lower == "none" { s.NoOutline = true; s.Outline = "" }
        if Str(d, "eyes") == "bar" { s.Eyes = "bar" }
        if Str(d, "eyes") == "short" { s.Eyes = "short" }
        if Str(d, "hands") == "square" { s.Hands = "square" }
        if Str(d, "hands") == "none" { s.Hands = "none" }     // 坐着的小动物：前爪画在图里，不另外加手
        if Str(d, "legs") == "legs" { s.Legs = "legs" }
        if Str(d, "legs") == "none" { s.Legs = "none" }       // 不另外加小脚
        if Str(d, "cheeks").Lower == "false" { s.Cheeks = false }
        if let hr = Int(Str(d, "hand_row")), hr + pad >= 6 && hr + pad <= SKIN_H - 2 { s.HandRow = hr + pad }
        s.EyeColor = Str(d, "eye_color")
        if let fu = Int(Str(d, "face_up")) { s.FaceUp = max(0, min(12, fu)) }
        s.HandColor = Str(d, "hand_color")
        s.Thin = Str(d, "thin")
        s.CheekUnder = Str(d, "cheek_pos") == "under"
        if let ei = Double(Str(d, "eye_in")) { s.EyeIn = max(0, min(2, ei)) }
        if let ci = Double(Str(d, "cheek_in")) { s.CheekIn = max(0, min(2, ci)) }
        if Str(d, "smile").Lower == "false" { s.Smile = false }
        return s
    }

    func MakeSkin(_ input: Dict) -> String {
        var problem = ""
        guard let s = ParseSkin(input, &problem) else { return "画不出来：" + problem }
        if s.Name == DEFAULT_SKIN { s.Name += "（新）" }
        s.FilePath = PathJoin(SkinsDir(), SafeName(s.Name) + ".json")
        FileX.Write(s.FilePath, Json.Serialize(input))
        skins.removeAll { $0.Name == s.Name }
        skins.append(s)
        WearSkin(s)
        if !working { Set("happy") }
        return "已经变成新形象“\(s.Name)”了（\(s.Pal.count) 种颜色）。"
    }

    func SetSkin(_ name0: String) -> String {
        var name = name0
        if name == "" || name == "默认" || name == "default" { name = DEFAULT_SKIN }
        for s in skins where s.Name == name { WearSkin(s); return "换回了“\(s.Name)”" }
        return "没有叫“\(name)”的形象"
    }

    func WearSkin(_ s: Skin) {
        skin = s
        FileX.Write(PathJoin(cfgDir, "skin_on.txt"), s.Name)
        ApplySkinColors()
        view.needsDisplay = true
    }

    // 身体主色可以被造型里的 body_color 覆盖
    func ApplySkinColors() {
        if skin == nil { skin = PetForm.MakeHamster() }
        let sk = skin!
        var over = ""
        for lk in looks where lk.Enabled && lk.BodyColor != "" { over = lk.BodyColor }
        var main = sk.Pal["b"]!
        var recolored = false
        if over != "", let c = HexColor(over) { main = c; recolored = true }
        BODY = Brush(main)
        BODY_D = Brush(Darker(main, 0.85))
        skinBrushes.removeAll()
        for (k, v) in sk.Pal { skinBrushes[k] = Brush(v) }
        skinBrushes["b"] = BODY
        thinBrushes.removeAll()
        for tc in sk.Thin { if let tb = skinBrushes[tc] { thinBrushes.insert(tb) } }
        var line = Darker(main, 0.38)
        if !recolored && sk.Outline != "", let c = HexColor(sk.Outline) { line = c }
        SKIN_LINE = Brush(line)
        var feet = Darker(main, 0.88)
        if !recolored && sk.Feet != "", let c = HexColor(sk.Feet) { feet = c }
        SKIN_FEET = Brush(feet)
        SKIN_EYE = EYE
        SKIN_HAND = BODY
        if sk.HandColor.count == 1, let c = sk.Pal[sk.HandColor.first!] { SKIN_HAND = Brush(c) }
        else if sk.HandColor != "", let c = HexColor(sk.HandColor) { SKIN_HAND = Brush(c) }
        if sk.EyeColor != "", let c = HexColor(sk.EyeColor) { SKIN_EYE = Brush(c) }
    }

    func H2(_ v: Double) -> Int { Int((v * 2).rounded(.toNearestOrEven)) }

    // ---------- 画整只身体：身体 + 小手 + 小脚，再自动描一圈边 ----------
    func DrawSkin(_ dx: Double, _ dy: Double, _ sq: Double, _ flat: Bool, _ armL: Double, _ armR: Double, _ armLX: Double, _ armRX: Double,
                  _ hideArmL: Bool, _ hideArmR: Bool, _ legLen: Double, _ legA: Double, _ legB: Double, _ wave: Double) {
        if skin == nil { ApplySkinColors() }
        let sk = skin!
        let R = cells.count, C = cells[0].count
        for r in 0..<R { for c in 0..<C { cells[r][c] = nil } }
        let rows = sk.Rows
        let sqr = H2(sq)
        // 找身体在“手”那一行的左右边缘
        let handRow = sk.HandRow
        var left = 2, right = SKIN_W - 3
        for c in 0..<SKIN_W where rows[handRow][c] != "." { left = c; break }
        for c in stride(from: SKIN_W - 1, through: 0, by: -1) where rows[handRow][c] != "." { right = c; break }
        var bottom = SKIN_H - 1
        for r in stride(from: SKIN_H - 1, through: 0, by: -1) { if rows[r].contains(where: { $0 != "." }) { bottom = r; break } }

        if !flat {
            // 脚（在身体后面，只露出下半截）
            if sk.Legs == "legs" && legLen > 0 {
                // 四条细腿，两两交替
                let lc = [5, 17, 9, 21]
                for k in 0..<4 {
                    let len = H2(legLen - (k < 2 ? legA : legB))
                    if len >= 1 { for r in 1...len { Put(bottom + r, lc[k], SKIN_FEET); Put(bottom + r, lc[k] + 1, SKIN_FEET) } }
                }
            } else if legLen >= 1 && sk.Legs != "none" {
                let top = bottom - 1 + H2(legLen - 2)
                // 脚跟着身体最下面一行的宽度走：胖的分得开，瘦的并在一起
                var bl = 0, br = SKIN_W - 1
                for c in 0..<SKIN_W where rows[bottom][c] != "." { bl = c; break }
                for c in stride(from: SKIN_W - 1, through: 0, by: -1) where rows[bottom][c] != "." { br = c; break }
                let mid = Double(bl + br) / 2.0, spread = min(5, Double(br - bl) / 2.0 - 1)
                let fc = [Int((mid - spread - 2).rounded(.toNearestOrEven)), Int((mid + spread - 1).rounded(.toNearestOrEven))]
                let lift = [legA, legB]
                for k in 0..<2 {
                    let t0 = top - H2(max(0, lift[k]))
                    for r in 0..<3 { for c in 0..<4 {
                        if r == 2 && (c == 0 || c == 3) { continue }
                        Put(t0 + r, fc[k] + c, SKIN_FEET)
                    } }
                }
            }
            // 身体
            for r in 0..<SKIN_H { for c in 0..<SKIN_W {
                let ch = rows[r][c]
                if ch == "." { continue }
                guard let b = skinBrushes[ch] else { continue }
                Put(r + sqr, c, b)
            } }
            // 小手
            if sk.Hands == "none" { }
            else if sk.Hands == "square" {
                if !hideArmL { Square(handRow - 1 + sqr - H2(armL), left - 4 + H2(armLX) - sqr) }
                if !hideArmR { Square(handRow - 1 + sqr - H2(armR), right + 1 + H2(armRX) + sqr) }
            } else {
                if !hideArmL { Hand(handRow + sqr - H2(armL), left - 2 + H2(armLX) - sqr) }
                if !hideArmR { Hand(handRow + sqr - H2(armR), right + H2(armRX) + sqr) }
            }
        } else {
            // 被戳晕：压成一半高，趴在地上，一只手无力地挥
            for r in stride(from: 0, to: SKIN_H, by: 2) { for c in 0..<SKIN_W {
                let ch = rows[r][c]
                if ch == "." { continue }
                guard let b = skinBrushes[ch] else { continue }
                Put(SKIN_H / 2 + 1 + r / 2, c, b)   // 压成一半高，贴在地上
            } }
            if sk.Hands == "square" { Square(SKIN_H - 9 - H2(wave), right + 1) } else if sk.Hands != "none" { Hand(SKIN_H - 8 - H2(wave), right) }
        }
        // 描边：空格子旁边有身体，就涂成边线色
        if !sk.NoOutline {
            for r in 0..<R { for c in 0..<C {
                if cells[r][c] != nil { continue }
                if Solid(r - 1, c) || Solid(r + 1, c) || Solid(r, c - 1) || Solid(r, c + 1) { outlineMark[r * C + c] = true }
            } }
            for i in 0..<outlineMark.count where outlineMark[i] { cells[i / C][i % C] = SKIN_LINE; outlineMark[i] = false }
        }
        let ox = SKIN_X0 - Double(PAD) * 0.5 + dx, oy = SKIN_Y0 - Double(PAD) * 0.5 + dy
        for r in 0..<R { for c in 0..<C { if let b = cells[r][c] { U(ox + Double(c) * 0.5, oy + Double(r) * 0.5, 0.5, 0.5, b) } } }
    }

    func Solid(_ r: Int, _ c: Int) -> Bool {
        if r < 0 || c < 0 || r >= cells.count || c >= cells[0].count { return false }
        guard let b = cells[r][c] else { return false }
        return b !== SKIN_LINE && !thinBrushes.contains(b)
    }

    func Put(_ r0: Int, _ c0: Int, _ b: Brush) {
        let r = r0 + PAD, c = c0 + PAD
        if r < 0 || c < 0 || r >= cells.count || c >= cells[0].count { return }
        cells[r][c] = b
    }

    func Square(_ r: Int, _ c: Int) {
        for i in 0..<4 { for j in 0..<4 { Put(r + i, c + j, SKIN_HAND) } }
    }

    func Hand(_ r: Int, _ c: Int) {
        // 3×3 的小圆手（四个角空着）
        for i in 0..<3 { for j in 0..<3 {
            if (i == 0 || i == 2) && (j == 0 || j == 2) { continue }
            Put(r + i, c + j, SKIN_HAND)
        } }
    }

    // 右键菜单「我的形象」
    func BuildSkinMenu(_ m: NSMenu) {
        let sm = m.Sub("我的形象")
        for s in skins {
            let s2 = s
            sm.Add(s.Name + (s.BuiltIn ? "（默认）" : ""), checked: skin === s) { [weak self] in self?.WearSkin(s2); self?.Set("happy") }
        }
        sm.Sep()
        sm.Add("想要新形象：在聊天里说，或者发照片给" + Names.Pet, enabled: false)
        sm.Add("打开形象文件夹") { [weak self] in if let s = self { OpenPath(s.SkinsDir()) } }
    }
}

// ---------- 生成器用的颜色小工具 ----------
struct Col { var R: Int, G: Int, B: Int
    static let White = Col(R: 255, G: 255, B: 255), Black = Col(R: 0, G: 0, B: 0)
    init(R: Int, G: Int, B: Int) { self.R = R; self.G = G; self.B = B }
    init(_ hex: String) { let c = HexColor(hex) ?? .white; let s = c.usingColorSpace(.sRGB) ?? c; R = Int(round(s.redComponent * 255)); G = Int(round(s.greenComponent * 255)); B = Int(round(s.blueComponent * 255)) }
}
func HexC(_ s: String?, _ fallback: Col) -> Col { if let s = s, s.Trim != "", HexColor(s) != nil { return Col(s) }; return fallback }
func HexC(_ s: String?, _ fallback: String) -> Col { HexC(s, Col(fallback)) }
func ToHexC(_ c: Col) -> String { String(format: "#%02X%02X%02X", c.R, c.G, c.B) }
func MulC(_ c: Col, _ k: Double) -> Col { Col(R: Int(min(255, Double(c.R) * k)), G: Int(min(255, Double(c.G) * k)), B: Int(min(255, Double(c.B) * k))) }
func MixC(_ a: Col, _ b: Col, _ t: Double) -> Col { Col(R: Int(Double(a.R) + Double(b.R - a.R) * t), G: Int(Double(a.G) + Double(b.G - a.G) * t), B: Int(Double(a.B) + Double(b.B - a.B) * t)) }

/// 字符画布：生成器在上面一格一格画
final class Grid {
    let W: Int, H: Int, off: Int
    var c: [[Character]]
    init(_ w: Int, _ h: Int, off: Int = 0) { W = w; H = h; self.off = off; c = Array(repeating: Array(repeating: ".", count: w), count: h + off) }
    func Get(_ x: Int, _ y: Int) -> Character { (x < 0 || x >= W || y < -off || y >= H) ? "." : c[y + off][x] }
    func Set(_ x: Int, _ y: Int, _ ch: Character) { if x >= 0 && x < W && y >= -off && y < H { c[y + off][x] = ch } }
    func HL(_ x0: Int, _ x1: Int, _ y: Int, _ ch: Character) { if x0 <= x1 { for x in x0...x1 { Set(x, y, ch) } } }
    func Rect(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ ch: Character) { if y0 <= y1 && x0 <= x1 { for y in y0...y1 { for x in x0...x1 { Set(x, y, ch) } } } }
    func RectOn(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ ch: Character, _ only: String) { if y0 <= y1 && x0 <= x1 { for y in y0...y1 { for x in x0...x1 where only.contains(Get(x, y)) { Set(x, y, ch) } } } }
    func SetOn(_ x: Int, _ y: Int, _ ch: Character, _ only: String) { if only.contains(Get(x, y)) { Set(x, y, ch) } }
    func Ell(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ ch: Character, _ only: String?) {
        for y in -off..<H { for x in 0..<W {
            let a = (Double(x) + 0.5 - cx) / rx, b = (Double(y) + 0.5 - cy) / ry
            if a * a + b * b <= 1 && (only == nil || only!.contains(Get(x, y))) { Set(x, y, ch) }
        } }
    }
    func Pts(_ p: [Int], _ ch: Character) { var i = 0; while i + 1 < p.count { Set(p[i], p[i + 1], ch); i += 2 } }
    func Sym(_ x: Int, _ y: Int, _ ch: Character) { Set(x, y, ch); Set(27 - x, y, ch) }
    func Left(_ y: Int) -> Int { for x in 0..<W where Get(x, y) != "." { return x }; return 14 }
    func Top() -> Int { for y in 0..<H where Get(13, y) != "." || Get(14, y) != "." { return y }; return 10 }
    func Rows() -> [Any] { c.map { String($0) } }
}

func InEll(_ x: Int, _ y: Int, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Bool {
    let a = (Double(x) + 0.5 - cx) / rx, b = (Double(y) + 0.5 - cy) / ry
    return a * a + b * b <= 1
}

// ---------- 像素小人生成器：照片里是人时，AI 只挑发型和颜色，程序按固定风格画出来 ----------
enum PersonGen {
    static let W = 28, HH = 23, OFF = 5
    static let STYLES = ["messy", "short", "long", "bob", "buns", "curly"]

    static func Head(_ g: Grid, _ style: String) {
        let CX = 14.0
        // 1 头发大轮廓（占头的三分之二）
        g.Ell(CX, 4.2, 12.4, 8.6, "h", nil)
        // 2 圆圆的小脸，两边脸蛋鼓一点
        for y in 5..<13 { for x in 0..<W where InEll(x, y, CX, 8.9, 7.4, 4.0) || InEll(x, y, CX - 3, 10, 4, 2.6) || InEll(x, y, CX + 3, 10, 4, 2.6) { g.Set(x, y, "s") } }
        // 3 耳朵
        for e in [[4, 5], [23, 22]] {
            for y in 8...10 { g.Set(e[0], y, "s"); g.Set(e[1], y, "s") }
            g.Set(e[0], 9, "q")
        }
        // 4 刘海：第 4 行整排，第 5 行几个发尖，眼睛上面留一行肤色
        g.HL(5, 22, 4, "h")
        let tips = style == "curly" ? [6, 8, 9, 12, 13, 15, 17, 18, 21] :
                   style == "long" || style == "bob" ? [6, 7, 8, 12, 13, 14, 18, 19, 21] :
                   style == "buns" ? [6, 7, 10, 11, 14, 15, 17, 18, 21] :
                   style == "short" ? [6, 7, 10, 13, 14, 17, 20, 21] :
                   [6, 7, 9, 10, 11, 13, 14, 16, 17, 19, 20, 21]
        for x in tips { g.Set(x, 5, "h") }
        if style == "long" || style == "bob" {
            let end = style == "long" ? 20 : 13
            for y in 7..<end { for x in [2, 3, 4, 23, 24, 25] where !(y >= 8 && y <= 10 && (x == 4 || x == 23)) { g.Set(x, y, "h") } }
            if style == "long" { for y in 20...21 { for x in [3, 4, 23, 24] { g.Set(x, y, "h") } } }
        }
        if style == "buns" { g.Ell(6.5, -3.6, 2.9, 2.5, "h", nil); g.Ell(21.5, -3.6, 2.9, 2.5, "h", nil) }
        // 5 阴影：下半圈和贴着脸侧的头发用暗色
        for y in -OFF..<HH { for x in 0..<W {
            if g.Get(x, y) != "h" { continue }
            if y >= 8 && !InEll(x, y, CX, 4.0, 11.4, 7.4) { g.Set(x, y, "k") }
            if y >= 8 && (x < 7 || x > 20) && ("sq".contains(g.Get(x + 1, y)) || "sq".contains(g.Get(x - 1, y))) { g.Set(x, y, "k") }
        } }
        // 6 发丝
        let strands = [[9, -1, 8, 0, 8, 1, 8, 2], [14, -2, 14, -1, 13, 0, 13, 1], [18, -1, 19, 0, 19, 1, 19, 2],
                       [5, 1, 5, 2, 5, 3], [22, 1, 22, 2, 22, 3], [11, 2, 11, 3], [16, 2, 16, 3]]
        for s in strands { var i = 0; while i < s.count { if g.Get(s[i], s[i + 1]) == "h" { g.Set(s[i], s[i + 1], "k") }; i += 2 } }
        // 7 高光（天使环）
        let hi = [6, -1, 7, -2, 8, -2, 10, -3, 11, -3, 16, -3, 17, -3, 19, -2, 20, -2, 21, -1]
        var i = 0; while i < hi.count { if g.Get(hi[i], hi[i + 1]) == "h" { g.Set(hi[i], hi[i + 1], "l") }; i += 2 }
        // 8 头顶
        if style == "messy" {
            g.Set(14, -5, "h"); g.Set(13, -5, "h"); g.Set(13, -4, "h")
            let sp = [2, 0, 25, 0, 1, 4, 26, 4, 4, -3, 23, -3]
            var j = 0; while j < sp.count { g.Set(sp[j], sp[j + 1], "h"); j += 2 }
        }
        if style == "curly" {
            let cc: [Double] = [4, -1, 8, -3, 14, -3.8, 20, -3, 24, -1, 1.8, 3.5, 26.2, 3.5]
            var j = 0; while j < cc.count { g.Ell(cc[j], cc[j + 1], 2.0, 1.7, "h", "."); j += 2 }
        }
        // 脸侧一点阴影
        for y in 7..<12 { for x in 0..<W {
            if g.Get(x, y) == "s" && (x < 8 || x > 19) && x != 4 && x != 5 && x != 22 && x != 23 &&
                ("hk".contains(g.Get(x - 1, y)) || "hk".contains(g.Get(x + 1, y))) { g.Set(x, y, "q") }
        } }
    }

    static func Body(_ g: Grid, _ strings: Bool, _ skirt: Bool) {
        g.HL(10, 17, 13, "g"); g.HL(9, 18, 14, "g")
        for y in 15..<19 { g.HL(9, 18, y, "b"); g.Set(18, y, "c") }
        g.HL(9, 18, 18, "c")
        for y in 15..<18 { g.Set(7, y, "b"); g.Set(8, y, "b"); g.Set(19, y, "b"); g.Set(20, y, "c") }
        if strings { g.Set(12, 15, "d"); g.Set(12, 16, "d"); g.Set(15, 15, "d"); g.Set(15, 16, "d") }
        if skirt { g.HL(9, 18, 19, "p"); g.HL(8, 19, 20, "p") }
        else { g.HL(9, 18, 19, "p"); g.HL(9, 18, 20, "p"); g.Set(13, 20, "."); g.Set(14, 20, ".") }
        for y in 21...22 { for x in [10, 11, 16, 17] { g.Set(x, y, "s") } }
    }

    // 生成一张皮肤（和 make_skin 的格式一样）
    static func Build(_ name: String, _ style0: String, _ hair: String, _ skin: String, _ top: String, _ collar: String,
                      _ bottom: String, _ bottomColor: String, _ shoes: String, _ strings: Bool) -> Dict {
        let style = STYLES.contains(style0) ? style0 : "messy"
        let g = Grid(W, HH, off: OFF)
        Head(g, style)
        Body(g, strings, bottom == "skirt")
        let h = HexC(hair, "#6A4636"), s = HexC(skin, "#FDE1CF"), b = HexC(top, "#EFE6D6")
        let col = collar.Trim != "" ? HexC(collar, "#6E7D55") : MulC(b, 0.78)
        let p = HexC(bottomColor, "#4E3E35")
        var pal: Dict = [:]
        pal["h"] = ToHexC(h); pal["k"] = ToHexC(MulC(h, 0.64)); pal["l"] = ToHexC(MixC(h, Col.White, 0.32))
        pal["s"] = ToHexC(s); pal["q"] = ToHexC(MulC(s, 0.95))
        pal["b"] = ToHexC(b); pal["c"] = ToHexC(MulC(b, 0.88)); pal["g"] = ToHexC(col)
        pal["d"] = ToHexC(MixC(b, Col.Black, 0.3)); pal["p"] = ToHexC(p)
        var d: Dict = [:]
        d["name"] = name; d["rows"] = g.Rows(); d["palette"] = pal
        d["outline"] = ToHexC(MixC(MulC(h, 0.35), Col(R: 43, G: 29, B: 24), 0.6))
        d["feet"] = ToHexC(HexC(shoes, "#3B2E28"))
        d["eyes"] = "short"; d["eye_color"] = "#2E1E1A"; d["smile"] = "false"; d["cheek_pos"] = "under"
        d["eye_in"] = "1"; d["hand_row"] = "22"; d["face_up"] = "4"; d["hand_color"] = "s"
        return d
    }
}

// ---------- 像素宠物生成器：坐着的小动物，大圆脑袋配小团子身子 ----------
enum PetGen {
    static let W = 28, H = 28
    static let SPECIES = ["cat", "dog", "shiba", "rabbit", "hamster", "bear"]
    static let PATTERNS = ["none", "tabby", "spots", "calico", "tuxedo"]

    static func Build(_ name: String, _ species0: String, _ main: String, _ light: String, _ pattern0: String, _ patternColor: String,
                      _ pattern2: String, _ earColor: String, _ nose: String) -> Dict {
        let species = SPECIES.contains(species0) ? species0 : "cat"
        let pattern = PATTERNS.contains(pattern0) ? pattern0 : "none"
        let g = Grid(W, H)
        // ---- 头：上面小圆、下面大圆，叠成一个饭团脸 ----
        let hw = [0, 4, 6, 7, 8, 9, 9, 10, 10, 11, 11, 11, 10, 8]          // 每一行的半宽：上窄下宽，顺滑过渡
        for y in 1..<hw.count { g.Rect(14 - hw[y], y, 13 + hw[y], y, "b") }
        if species == "cat" || species == "shiba" {
            let inner: Character = species == "shiba" ? "w" : "p"
            g.Rect(6, 0, 7, 0, "b"); g.Rect(6, 1, 8, 1, "b"); g.Rect(6, 2, 9, 2, "b"); g.Rect(6, 3, 10, 3, "b")
            g.Rect(20, 0, 21, 0, "b"); g.Rect(19, 1, 21, 1, "b"); g.Rect(18, 2, 21, 2, "b"); g.Rect(17, 3, 21, 3, "b")
            g.Set(7, 1, inner); g.Rect(7, 2, 8, 2, inner); g.Set(20, 1, inner); g.Rect(19, 2, 20, 2, inner)
        } else if species == "rabbit" { g.Rect(8, 0, 11, 3, "b"); g.Rect(16, 0, 19, 3, "b"); g.Rect(9, 0, 10, 3, "p"); g.Rect(17, 0, 18, 3, "p") }
        else if species == "hamster" || species == "bear" {
            g.Rect(5, 1, 9, 3, "b"); g.Rect(18, 1, 22, 3, "b"); g.Set(5, 1, "."); g.Set(9, 1, "."); g.Set(18, 1, "."); g.Set(22, 1, "."); g.Rect(6, 2, 8, 3, "p"); g.Rect(19, 2, 21, 3, "p")
        }
        if species == "dog" {
            // 头顶一顶有颜色的"帽子"，中间留一道白，垂耳从头顶两侧挂下来
            g.RectOn(0, 1, 27, 5, "e", "b"); g.Rect(13, 2, 14, 5, "b"); g.RectOn(12, 5, 15, 5, "b", "e")
            g.Rect(4, 4, 7, 11, "e"); g.Rect(20, 4, 23, 11, "e"); g.Rect(3, 5, 3, 10, "e"); g.Rect(24, 5, 24, 10, "e")
            g.Rect(5, 12, 6, 12, "e"); g.Rect(21, 12, 22, 12, "e")
        }
        // ---- 身体：小小圆圆的一团，比头窄，短短的 ----
        let bw = [5, 6, 7, 7, 8, 8, 8, 8, 7, 6]                                // 第 14~23 行的半宽
        for k in 0..<bw.count { g.Rect(14 - bw[k], 14 + k, 13 + bw[k], 14 + k, "b") }
        g.RectOn(9, 14, 18, 14, "m", "b")                                     // 下巴底下一道阴影
        for y in 20..<24 { g.Set(13, y, "m"); g.Set(14, y, "m") }              // 两只小前脚
        g.Set(10, 23, "m"); g.Set(17, 23, "m")
        // ---- 脸 ----
        if species == "dog" || species == "shiba" || species == "bear" { g.Rect(11, 10, 16, 12, "w"); g.Set(11, 10, "b"); g.Set(16, 10, "b") }
        g.Rect(13, 10, 14, 10, "n")                                             // 小鼻子
        // 胡须（细线）
        if species == "cat" || species == "rabbit" || species == "hamster" { g.Pts([0, 9, 1, 9, 0, 11, 1, 11, 26, 9, 27, 9, 26, 11, 27, 11], "k") }
        // 胸口浅色
        let white = pattern == "tuxedo"
        if white || light.Trim != "" { g.Ell(14, 16.6, 3.0, 2.3, "w", "bm") }
        if white { g.RectOn(9, 22, 12, 23, "w", "b"); g.RectOn(15, 22, 18, 23, "w", "b"); g.Rect(13, 5, 14, 9, "w"); g.Rect(12, 8, 15, 9, "w") }
        // ---- 花纹 ----
        if pattern == "tabby" {
            g.Pts([10, 2, 10, 3, 13, 2, 13, 3, 14, 2, 14, 3, 17, 2, 17, 3, 3, 9, 4, 9, 23, 9, 24, 9], "d")
            g.Pts([7, 17, 8, 17, 19, 17, 20, 17, 6, 20, 7, 20, 20, 20, 21, 20], "d")
        } else if pattern == "spots" { if species != "dog" { g.Ell(8, 2.6, 3.4, 2.4, "d", "bp") }; g.Ell(18.5, 19, 1.6, 1.5, "d", "b"); g.Ell(9, 21, 1.4, 1.3, "d", "b") }
        else if pattern == "calico" { g.Ell(7.5, 4.5, 3.6, 3.0, "o", "bp"); g.Ell(20.5, 5, 3.2, 2.8, "d", "bp"); g.Ell(8, 20, 2.2, 2.2, "o", "b"); g.Ell(19.5, 17, 1.8, 1.7, "d", "b") }
        // 整体往下挪，身子短了下面不留空
        let SHIFT = 4
        for y in stride(from: H - 1, through: 0, by: -1) { for x in 0..<W { g.c[y][x] = y >= SHIFT ? g.c[y - SHIFT][x] : "." } }
        let b = HexC(main, "#F7F5F2")
        let lum = 0.3 * Double(b.R) + 0.59 * Double(b.G) + 0.11 * Double(b.B)
        let w = HexC(light, lum > 215 ? Col.White : Col("#F6F1EA"))
        let line = lum > 200 ? Col("#8C8486") : MixC(MulC(b, 0.45), Col("#3A3236"), 0.5)
        var pal: Dict = [:]
        pal["b"] = ToHexC(b); pal["m"] = ToHexC(lum > 200 ? Col("#D9D4D2") : MulC(b, 0.8)); pal["w"] = ToHexC(w); pal["k"] = ToHexC(line)
        pal["d"] = ToHexC(HexC(patternColor, MulC(b, 0.66))); pal["o"] = ToHexC(HexC(pattern2, "#E9A05A"))
        pal["e"] = ToHexC(HexC(earColor, MulC(b, 0.7))); pal["p"] = "#F7C6CC"
        pal["n"] = ToHexC(HexC(nose, "#2E2A2C"))
        var dd: Dict = [:]
        dd["name"] = name; dd["rows"] = g.Rows(); dd["palette"] = pal; dd["outline"] = ToHexC(line)
        dd["eyes"] = "short"; dd["eye_color"] = lum < 90 ? "#E8B83A" : "#2E2A2C"; dd["smile"] = "false"; dd["cheek_pos"] = "under"
        dd["eye_in"] = "1"; dd["face_up"] = "4"; dd["hands"] = "none"; dd["legs"] = "none"; dd["thin"] = "k"
        return dd
    }
}

// ---------- 万物生成器：照片里不是人也不是常见宠物时用（食物、植物、物件、小怪兽、玩偶……） ----------
enum ThingGen {
    static let BASES = ["blob", "bean", "square", "triangle", "drop", "cloud", "bell", "pudding", "cup", "octopus"]
    static let TOPS = ["none", "sprout", "bow", "cherry", "antenna", "cat_ears", "round_ears", "horns", "flower", "straw", "curl", "frog_eyes", "crown"]
    static let MARKS = ["none", "band", "top_layer", "bottom_layer", "stripes", "vstripes", "spots", "belly", "pearls"]

    static func Build(_ name: String, _ bas0: String, _ main: String, _ top0: String, _ topColor: String, _ mark0: String, _ markColor: String) -> Dict {
        let bas = BASES.contains(bas0) ? bas0 : "blob"
        let top = TOPS.contains(top0) ? top0 : "none"
        let mark = MARKS.contains(mark0) ? mark0 : "none"
        let g = Grid(28, 28)
        func Row(_ y: Int, _ hw: Int, _ ch: Character) { g.Rect(14 - hw, y, 13 + hw, y, ch) }
        var noFeet = false
        // ---- 底座轮廓 ----
        switch bas {
        case "bean": g.Ell(14, 18.6, 10.6, 9.2, "b", nil)
        case "square":
            g.Rect(3, 10, 24, 26, "b"); Row(9, 9, "b")
            g.Set(3, 10, "."); g.Set(24, 10, "."); g.Set(3, 26, "."); g.Set(24, 26, ".")
        case "triangle":
            for y in 7..<27 { var hw = min(13, 1 + Int(Double(y - 7) * 0.78)); if y >= 25 { hw -= y - 24 }; Row(y, hw, "b") }
        case "drop":
            g.Ell(14, 19.2, 11, 7.8, "b", nil)
            for y in 7..<15 { Row(y, 1 + (y - 7) * 6 / 5, "b") }
        case "cloud":
            g.Ell(6.5, 14.5, 4.5, 4.5, "b", nil); g.Ell(14, 11.5, 6.2, 6.2, "b", nil); g.Ell(21.5, 14.5, 4.5, 4.5, "b", nil)
            g.Rect(2, 16, 25, 24, "b"); g.Rect(1, 18, 26, 23, "b"); Row(25, 11, "b")
        case "bell":
            let hw = [3, 5, 7, 8, 9, 9, 10, 10, 10, 10, 10, 10, 10, 11, 11, 12, 13, 13]
            for i in 0..<hw.count { Row(8 + i, hw[i], "b") }
            g.Rect(1, 24, 26, 25, "d"); g.Rect(12, 26, 15, 26, "u"); g.Rect(13, 27, 14, 27, "u"); noFeet = true
        case "pudding":
            for y in 10..<27 { Row(y, 8 + (y - 10) * 5 / 16, "b") }
            g.Rect(1, 27, 26, 27, "q"); noFeet = true
        case "cup":
            Row(9, 11, "b"); Row(10, 11, "b")
            for y in 11..<27 { Row(y, 10 - (y - 11) / 8, "b") }
            g.Rect(3, 9, 24, 10, "d")
        case "octopus":
            g.Ell(14, 15, 11, 9.2, "b", nil)
            for x0 in stride(from: 3, through: 21, by: 6) { g.Rect(x0, 22, x0 + 3, 25, "b"); g.Rect(x0 + 1, 26, x0 + 3, 26, "b") }
            g.Set(3, 26, "b"); g.Set(2, 27, "b"); g.Set(24, 26, "b"); g.Set(25, 27, "b")
            for x in [7, 8, 13, 14, 19, 20] { g.Set(x, 24, "."); g.Set(x, 25, ".") }
            noFeet = true
        default: g.Ell(14, 18.8, 12.4, 8.2, "b", nil)
        }
        let T = g.Top(), L = g.Left(T + 3)
        // ---- 身上的花纹（不碰脸那一块）----
        switch mark {
        case "band": g.RectOn(9, 21, 18, 27, "m", "b")
        case "top_layer":
            g.RectOn(0, T, 27, T + 3, "m", "b")
            for x in [6, 7, 11, 16, 17, 21] { g.RectOn(x, T + 4, x, T + 4 + (x % 3), "m", "b") }
        case "bottom_layer": g.RectOn(0, 23, 27, 26, "m", "b")
        case "stripes": for y in [T + 2, T + 5, 22, 25] where y < 15 || y > 21 { g.RectOn(0, y, 27, y, "m", "b") }
        case "vstripes": for x in stride(from: 4, to: 27, by: 5) { g.RectOn(x, 0, x, 15, "m", "b"); g.RectOn(x, 21, x, 27, "m", "b") }
        case "spots": g.Ell(Double(L + 3), Double(T + 4), 2, 1.6, "m", "b"); g.Ell(Double(27 - L) - 3.5, Double(T + 3), 1.5, 1.3, "m", "b"); g.Ell(6.5, 23, 1.6, 1.5, "m", "b"); g.Ell(21, 24, 2, 1.7, "m", "b")
        case "belly": g.Ell(14, 24, 6.4, 3.6, "m", "b")
        case "pearls": for p in [[7, 24], [10, 22], [12, 25], [16, 23], [19, 25], [21, 22], [8, 21]] { g.RectOn(p[0], p[1], p[0] + 1, p[1] + 1, "m", "b") }
        default: break
        }
        // 左上角一小块高光，看起来圆润有光泽
        g.RectOn(L + 2, T + 3, L + 2, T + 5, "h", "b"); g.RectOn(L + 3, T + 2, L + 3, T + 2, "h", "b")
        // ---- 头顶的标志物 ----
        switch top {
        case "sprout":
            g.Rect(13, T - 4, 14, T - 1, "g")
            g.Ell(9.5, Double(T) - 5.2, 3.6, 2.0, "t", "."); g.Ell(19, Double(T) - 6.2, 3.8, 2.1, "t", ".")
            for x in 7..<12 { g.Set(x, x < 10 ? T - 5 : T - 4, "g") }
            for x in 17..<22 { g.Set(x, x < 19 ? T - 6 : T - 7, "g") }
        case "bow":
            let bw = [[8, 10], [7, 11], [7, 12], [8, 12], [9, 11]]
            for i in 0..<5 { for x in bw[i][0]...bw[i][1] { g.Sym(x, T - 5 + i, "t") } }
            g.Rect(12, T - 4, 15, T - 1, "t"); g.Rect(13, T - 3, 14, T - 2, "u")
        case "cherry": g.Ell(14, Double(T) - 2.4, 2.3, 2.3, "t", nil); g.Set(13, T - 3, "h"); g.Rect(15, T - 7, 15, T - 4, "g"); g.Set(16, T - 8, "g")
        case "antenna": g.Rect(13, T - 4, 14, T - 1, "u"); g.Rect(12, T - 7, 15, T - 5, "t"); g.Set(12, T - 7, "."); g.Set(15, T - 7, "."); g.Set(12, T - 6, "h")
        case "cat_ears":
            for k in 0..<4 { let a = L + 1 + k / 2, b = L + 5 - (k + 1) / 2; if a <= b { for x in a...b { g.Sym(x, T + 1 - k, "b") } } }
            g.Sym(L + 3, T, "p"); g.Sym(L + 3, T - 1, "p")
        case "round_ears": g.Ell(Double(L) + 3.5, Double(T) + 0.5, 2.7, 2.5, "b", "."); g.Ell(Double(27 - L) - 2.5, Double(T) + 0.5, 2.7, 2.5, "b", "."); g.RectOn(L + 3, T, L + 3, T, "p", "b"); g.RectOn(24 - L, T, 24 - L, T, "p", "b")
        case "horns":
            for k in 0..<4 { g.Sym(L + 4 - k / 2, T + 1 - k, "t"); g.Sym(L + 5 - k / 2, T + 1 - k, "t") }
        case "flower":
            g.Rect(13, T - 2, 14, T - 1, "g")
            g.Ell(14, Double(T) - 6.5, 1.8, 1.6, "t", nil); g.Ell(14, Double(T) - 2.6, 1.8, 1.6, "t", nil); g.Ell(12, Double(T) - 4.6, 1.8, 1.6, "t", nil); g.Ell(16, Double(T) - 4.6, 1.8, 1.6, "t", nil)
            g.Rect(13, T - 5, 14, T - 4, "u")
        case "straw": for k in 0..<7 { g.Set(16 + k / 2, T - k, "t"); g.Set(17 + k / 2, T - k, "t") }; g.SetOn(17, T, "u", "t")
        case "curl": g.Pts([14, T - 1, 14, T - 2, 15, T - 3, 16, T - 3, 17, T - 2, 13, T - 1], "u")
        case "frog_eyes": g.Ell(Double(L + 4), Double(T + 1), 3.4, 3.0, "b", "."); g.Ell(Double(27 - L - 3), Double(T + 1), 3.4, 3.0, "b", ".")
        case "crown":
            g.Rect(9, T - 2, 18, T - 1, "t")
            for x in [9, 13, 14, 18] { g.Set(x, T - 3, "t") }
            g.Set(9, T - 4, "t"); g.Set(18, T - 4, "t"); g.Rect(13, T - 5, 14, T - 4, "t"); g.Set(11, T - 2, "u"); g.Set(16, T - 2, "u")
        default: break
        }
        g.Rect(7, 16, 20, 20, "b")                                                    // 脸这一块留给程序画眼睛和嘴
        g.Pts([7, 16, 20, 16], "b")
        // ---- 颜色 ----
        let b = HexC(main, "#F2C46B")
        let lum = 0.3 * Double(b.R) + 0.59 * Double(b.G) + 0.11 * Double(b.B)
        let defTop = top == "sprout" ? "#86C96F" : top == "bow" || top == "cherry" ? "#E5574D" : top == "antenna" || top == "crown" ? "#F6C744"
            : top == "horns" ? "#F4E6C8" : top == "flower" ? "#F59AB5" : top == "straw" ? "#F29BB0" : ""
        let t = HexC(topColor, defTop == "" ? MulC(b, 0.7) : Col(defTop))
        let line = lum > 215 ? Col("#7D8796") : MixC(MulC(b, 0.42), Col("#3A2E2A"), 0.45)
        var pal: Dict = [:]
        pal["b"] = ToHexC(b); pal["d"] = ToHexC(MulC(b, 0.86)); pal["h"] = ToHexC(MixC(b, Col.White, 0.6))
        pal["m"] = ToHexC(HexC(markColor, mark == "belly" || mark == "bottom_layer" ? MixC(b, Col.White, 0.55) : MulC(b, 0.72)))
        pal["t"] = ToHexC(t); pal["u"] = ToHexC(top == "curl" ? MulC(b, 0.6) : top == "flower" ? Col("#F6C744") : MulC(t, 0.72))
        pal["g"] = "#4F9A45"; pal["p"] = "#F7C6CC"; pal["q"] = "#DCE6EF"
        var used = Set<String>()
        for row in g.c { for ch in row where ch != "." { used.insert(String(ch)) } }
        for k in Array(pal.keys) where !used.contains(k) { pal.removeValue(forKey: k) }
        var dd: Dict = [:]
        dd["name"] = name; dd["rows"] = g.Rows(); dd["palette"] = pal; dd["outline"] = ToHexC(line)
        dd["eyes"] = "short"; dd["eye_color"] = lum < 90 ? "#F4E3B0" : "#2E2A2C"; dd["smile"] = "false"; dd["cheek_pos"] = "under"; dd["eye_in"] = "1"
        if noFeet { dd["legs"] = "none" }
        if bas == "octopus" { dd["hands"] = "none" }
        return dd
    }
}
